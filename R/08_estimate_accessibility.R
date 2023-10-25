
# Estimate accessibility

# Date: 2023-10-23

library(tidyverse)
library(sf)
library(AccessUK)

# Read files --------------------------------------------------------------

# GPs
gps <- read_csv('data/gp_practice/gp_practice_GB.csv')
# Supermarkets
supermarkets <- read_csv('data/shops/supermarkets_osm.csv')
# Employment
employment <- read_csv('data/employment/employment_gb.csv')
# Schools
schools <- read_csv('data/schools/schools_gb.csv')
# hospitals
hospitals <- read_csv('data/hospitals/hospitals_gb.csv')
# Urban centers
sub_bua <-  st_read('data/urban_centres/sub_bua.gpkg') %>% st_drop_geometry()
main_bua <-  st_read('data/urban_centres/main_bua.gpkg') %>% st_drop_geometry()


# Aggregate data ----------------------------------------------------------

# Count GPs by lsoa
gp_count <- gps %>% 
  count(lsoa11, name = 'gp_practices')
# Count supermarkets by LSOA
supermarket_count <- supermarkets %>% 
  count(lsoa11cd, name = 'supermarkets')
# Count schools
primary_school_count <- schools %>% 
  filter(type_primary == TRUE) %>% 
  count(lsoa11, name = 'primary_schools')
secondary_school_count <- schools %>% 
  filter(type_secondary == TRUE) %>% 
  count(lsoa11, name = 'secondary_schools')
# Hospitals
hospitals_count <- hospitals %>% 
  count(lsoa, name = 'hospitals')
# Urban centres
main_bua_count <- main_bua %>% 
  count(geo_code, name = 'main_bua')
sub_bua_count <- sub_bua %>% 
  count(geo_code, name = 'sub_bua')

# Join land uses 
land_use <- employment %>% 
  left_join(gp_count, by = c('lsoa11cd' = 'lsoa11')) %>% 
  left_join(supermarket_count, by = 'lsoa11cd') %>% 
  left_join(primary_school_count, by = c('lsoa11cd' = 'lsoa11')) %>% 
  left_join(secondary_school_count, by = c('lsoa11cd' = 'lsoa11')) %>% 
  left_join(hospitals_count, by = c('lsoa11cd' = 'lsoa')) %>% 
  left_join(main_bua_count, by = c('lsoa11cd' = 'geo_code')) %>% 
  left_join(sub_bua_count, by = c('lsoa11cd' = 'geo_code')) %>% 
  rename(id = lsoa11cd)

# NAs as 0, assuming there is none of these services
land_use <- land_use %>% 
  mutate(across(-id, \(x) replace_na(x, 0)))

# Estimate accessibility  -------------------------------------------------

# Define time cuts
timecuts <- seq(15, 120, 15)

# List to store results
accessibility <- list()

# Estimate PT accessibility
accessibility$pt <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_pt/', 
  travel_cost = 'travel_time_p50', 
  weights = land_use, 
  time_cut = timecuts, 
  additional_group = 'time_of_day'
)

# Estimate walk accessibility
accessibility$walk <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_walk/', 
  travel_cost = 'travel_time_p50', 
  weights = land_use, 
  time_cut = timecuts
)

# Estimate bike accessibility
accessibility$bicycle <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_bike/', 
  travel_cost = 'travel_time_adj', 
  weights = land_use, 
  time_cut = timecuts
)

# Bind rows
accessibility <- bind_rows(accessibility, .id = 'mode')

# Relative accessibility --------------------------------------------------


# Total number of opportunities for each service
total_services <- sapply(land_use[,-1], sum, na.rm = TRUE)

# Expand total number as weight for each service
total_services_weight <- lapply(total_services, rep, length(timecuts))
total_services_weight <- unlist(total_services_weight)

# Compute relative access using totals
access_rel <- 
  accessibility %>% 
  select(starts_with('access')) %>% 
  # Divide absolute number of services by total number in GB
  map2_df(total_services_weight, ~ .x / .y) %>% 
  # Format percent
  mutate(across(everything(), ~ round(.x * 100, 4)))

# Append 'pct' in col names
access_rel <- access_rel %>%
  rename_at(vars(starts_with("access")), ~paste0(.x, "_pct"))

# Bind absolute accessibility
access_all <- bind_cols(accessibility, access_rel)


# Nearest opportunity -----------------------------------------------------

# Type of services to estimate nearest facility
land_use_nearest <- land_use %>% 
  select(!starts_with('employment'))

# List to store results
nearest_opp <- list()

# By PT
nearest_opp$pt <- AccessUK::estimate_nearest_opportunity(
  travel_matrix = 'data/ttm/ttm_pt/', 
  travel_cost = 'travel_time_p50', 
  weights = land_use_nearest, 
  additional_group = 'time_of_day'
)

# By Walking
nearest_opp$walk <- AccessUK::estimate_nearest_opportunity(
  travel_matrix = 'data/ttm/ttm_walk/', 
  travel_cost = 'travel_time_p50', 
  weights = land_use_nearest
)

# By bicycle
nearest_opp$bicycle <- AccessUK::estimate_nearest_opportunity(
  travel_matrix = 'data/ttm/ttm_bike/', 
  travel_cost = 'travel_time_adj', 
  weights = land_use_nearest
)

# Bind rows
nearest_opp <- bind_rows(nearest_opp, .id = 'mode')


# Format variables and write results --------------------------------------

# Bind nearest with the rest of measures
access_all <- access_all %>% 
  left_join(nearest_opp, by = c('mode', 'from_id', 'time_of_day'))

# Rename ID as 'geo_code' for compatibility with previous version
access_all <- access_all %>% rename(geo_code = from_id)

# Name of services included
service_names <- names(land_use)[-1]

# Split by type of weight/opportunity
access_all_split <- service_names %>% 
  map(function(k)
    access_all %>% 
      select(geo_code, mode, time_of_day, contains(!!k))
  ) %>% 
  setNames(service_names)

# Split by mode
access_all_split <- access_all_split %>% 
  map(~split(.x, .$mode))

# Function to remove columns with all NA values from a data frame
remove_na_columns <- function(df) {
  df[, !apply(is.na(df), 2, all)]
}

# Remove time_of_day column if all NA
access_all_split <- access_all_split %>% 
  map(function(service) {
    service %>%
      map(remove_na_columns)
  })

# Set the option to avoid scientific notation
options(scipen = 999)

# Write as CSV
lapply(service_names, function(service_names) {
  # Create directory for each service
  main_dir <- paste0("output/", service_names)
  dir.create(main_dir, recursive = TRUE)
  
  # Write CSV for each service for each mode
  lapply(names(access_all_split[[service_names]]), function(mode) {
    write_csv(
      x = access_all_split[[service_names]][[mode]],
      file = paste0(main_dir, "/access_", service_names, '_', mode, ".csv")
    )
  })
})
