
library(tidyverse)
library(sf)

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


# Estimate accessibility  -------------------------------------------------

library(AccessUK)

# Define time cuts
timecuts <- seq(15, 120, 15)

# Estimate PT accessibility
access_pt <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_pt/', 
  travel_cost = 'travel_time_p50', 
  weights = land_use, 
  time_cut = timecuts, 
  additional_group = 'time_of_day'
)

# Estimate walk accessibility
access_walk <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_walk/', 
  travel_cost = 'travel_time_p50', 
  weights = land_use, 
  time_cut = timecuts
)
glimpse(access_walk)



