############################################################################
############################################################################
###                                                                      ###
###                                                                      ###
###                     ACCESSIBILITY TO GP PRACTICE                     ###
###                                                                      ###
############################################################################
############################################################################

# LAST UPDATED: 2023-08-02

# Packages ----------------------------------------------------------------

library(tidyverse)
library(sf)

##---------------------------------------------------------------
##                      1. Format GP data                      --
##---------------------------------------------------------------

# Read data ---------------------------------------------------------------

# Scotland
isd_scotland <- read_csv('data/gp_practice/isd_scotland/practice_contactdetails_jan2023-open-data.csv')
# England and Wales
nhs_eng <- read_csv('data/gp_practice/nhs_england/epraccur/epraccur.csv', col_names = FALSE)

# UK post codes
postcodes_all <- read_csv('data/uk_postcodes/ONSPD_AUG_2022_UK/Data/ONSPD_AUG_2022_UK.csv')


# Format GP data and assign location by postcode --------------------------

## Post codes
# Subset 'live' post codes in GB
postcodes <- filter(postcodes_all, is.na(doterm) & grepl("^(E|S|W)", oscty))
# Select relevant columns
postcodes <- select(postcodes, pcds, oa11, lsoa11, lat, long)
# Save reduced version of post codes
write_csv(postcodes, 'data/uk_postcodes/postcodes_reduced.csv')


## GP practice
# Subset active GP practices in England and Wales
nhs_eng <- filter(nhs_eng, X13 == "A" & X26 == "4")
# Select variables
nhs_eng <- select(nhs_eng, c(1:2, 10))
nhs_eng <- rename(nhs_eng, practice_code = X1, practice_name = X2, postcode = X10)

# Scotland
isd_scotland <- isd_scotland %>% 
  rename_all(~gsub(' ', "_", tolower(.))) %>% 
  rename(practice_code = practicecode, practice_name = gppracticename) %>% 
  select(practice_code, practice_name, postcode) %>% 
  mutate(practice_code = as.character(practice_code))

# Bind all practices
gp_practices <- bind_rows(nhs_eng, isd_scotland)

# Get location from postcode data
gp_practices <- left_join(gp_practices, postcodes, by = c('postcode' = "pcds"))
# NA matches
sum(is.na(gp_practices$lat))
# Which postcode
gp_practices[is.na(gp_practices$lat),]$postcode

# Use terminated post code data where there were not matches,
# assuming post code is outdated from source
gp_practices <- gp_practices %>%
  filter(is.na(lat)) %>%
  select(practice_code:postcode) %>%
  left_join(postcodes_all, by = c('postcode' = "pcds")) %>%
  select(practice_code:postcode, oa11, lsoa11, lat, long) %>%
  bind_rows(gp_practices[!is.na(gp_practices$lat), ])

# View GP location in map
gp_practices %>% 
  st_as_sf(coords = c('long', 'lat'), crs = 4326) %>% 
  mapview::mapview()

# Save GP practice data
write_csv(gp_practices, 'data/gp_practice/gp_practice_GB.csv')

# Clean env.
rm(list = ls())

##----------------------------------------------------------------
##               2. Compute access to GP practice               --
##----------------------------------------------------------------


# Read data ---------------------------------------------------------------

library(AccessUK)

# GP location
gp_practice <- read_csv('data/gp_practice/gp_practice_GB.csv')
# Read employment
employment <- read_csv('data/employment/employment_gb.csv')

# Aggregate gps by LSOA
gp_count <- gp_practice %>% 
  count(lsoa11, name = 'gp_practices')

# Join data
land_use <- employment %>% 
  select(-area) %>% 
  left_join(gp_count, by = c('geo_code' = 'lsoa11')) %>% 
  rename(id = geo_code)

walk_access <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_walk/', 
  travel_cost = 'travel_time_p50',
  weights = land_use, 
  time_cut = seq(15, 120, 15)
)

bike_access <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_bike/', 
  travel_cost = 'travel_time_p50',
  weights = land_use, 
  time_cut = seq(15, 120, 15)
)

pt_access <- AccessUK::estimate_accessibility(
  travel_matrix = 'data/ttm/ttm_pt/', 
  travel_cost = 'travel_time_p50',
  weights = land_use, 
  time_cut = seq(15, 120, 15), 
  additional_group = 'time_of_day'
)




# # Format and write output -------------------------------------------------
# 
# # Reshape cum access at OA-level
# cum_acces_gp <- cum_acces_gp %>% 
#   pivot_wider(
#     names_from = 'name', 
#     values_from = c('n', 'pct'),
#     names_glue = "{name}_{.value}"
#   )
# # Join nearest GP
# cum_acces_gp <- cum_acces_gp %>% 
#   left_join(nearest_gp, by = 'from_id') %>% 
#   rename(oa11cd = from_id) %>% 
#   ungroup()
# 
# # Join nearest GP at LSOA level
# acces_gp_lsoa <- acces_gp_lsoa %>% 
#   janitor::clean_names() %>% 
#   left_join(nearest_gp_lsoa, by = 'lsoa11cd') %>% 
#   ungroup()
# 
# # get LSOA names
# lsoa_names <- lookup %>% 
#   select(LSOA11CD, LSOA11NM) %>% 
#   distinct() %>% 
#   janitor::clean_names()
# # Join LSOA name
# acces_gp_lsoa <- acces_gp_lsoa %>% 
#   left_join(lsoa_names, by = 'lsoa11cd')
# # Order column names
# acces_gp_lsoa <- acces_gp_lsoa %>% 
#   select(lsoa11cd, lsoa11nm, colnames(cum_acces_gp)[-1])
# 
# 
# # Output folder
# out_dir <- 'output/gp/'
# dir.create(out_dir, recursive = TRUE)
# write_csv(acces_gp_lsoa, paste0(out_dir, 'access_gp_lsoa.csv'))
# write_csv(cum_acces_gp, paste0(out_dir, 'access_gp_oa.csv'))
# 
# 
# ##----------------------------------------------------------------
# ##                  3. Examine and validate                     --
# ##----------------------------------------------------------------
# 
# library(mapview)
# 
# # Read geometries
# oa_geoms <- st_read('data/uk_dataservice/infuse_oa_lyr_2011_clipped/infuse_oa_lyr_2011_clipped.shp')
# lsoa_geoms <- st_read('data/uk_dataservice/infuse_lsoa_lyr_2011_clipped/infuse_lsoa_lyr_2011_clipped.shp')  
# # Access indicators 2022
# gp_access22 <- read_csv('data/pt_accessibility_22/output/accessibility/gp/access_gp_pt.csv')
# 
# 
# # Compare previous edition ------------------------------------------------
# 
# # Make col names compatible
# gp_access22 <- gp_access22 %>% 
#   setNames(colnames(acces_gp_lsoa))
# 
# # Merge indicators
# access_gp_merged <- list(acces_gp_lsoa, gp_access22) %>% 
#   setNames(c('2023', '2022')) %>% 
#   bind_rows(.id = 'edition')
# 
# # Compare basic stats
# access_gp_merged %>% 
#   pivot_longer(-edition:-lsoa11nm ) %>% 
#   group_by(edition, name) %>% 
#   summarise(
#     mean = mean(value, na.rm = TRUE),
#     median = median(value, na.rm = TRUE),
#     nas = sum(is.na(value))
#   ) %>% 
#   pivot_wider(names_from = 'edition', values_from = c('mean',  'median', 'nas'))
# 
# #  Distribution by measure
# access_gp_merged %>% 
#   pivot_longer(-edition:-lsoa11nm ) %>% 
#   ggplot(aes(value, name, fill = edition)) +
#   geom_boxplot() +
#   theme_minimal()
# 
# # nearest map -------------------------------------------------------------
# 
# # Nearest GP at OA
# neares_gp_oa <- cum_acces_gp %>% 
#   left_join(oa_geoms, by = c('oa11cd' = 'geo_code')) %>% 
#   st_as_sf() %>% 
#   ggplot()+
#   geom_sf(aes(fill = nearest_gp), col = NA) +
#   scale_fill_viridis_c() +
#   theme_void()
# # Nearest GP at LSOA
# neares_gp_lsoa <- acces_gp_lsoa %>% 
#   left_join(lsoa_geoms, by = c('lsoa11cd' = 'geo_code')) %>% 
#   st_as_sf() %>% 
#   ggplot()+
#   geom_sf(aes(fill = nearest_gp), col = NA) +
#   scale_fill_viridis_c() +
#   theme_void()
# 
# # Put maps in a grid
# neares_grid <- cowplot::plot_grid(neares_gp_oa, neares_gp_lsoa)
# 
# # Save plot
# ggsave('plots/accessibility/nearest_gp.png', neares_grid, bg = 'white')
# 
# 
# # Cumulative  -------------------------------------------------------------
# 
# 
# # Faceted map for different timecuts
# gp_cum <- acces_gp_lsoa %>% 
#   pivot_longer(access_gp_45_n:access_gp_90_n) %>% 
#   left_join(lsoa_geoms, by = c('lsoa11cd' = 'geo_code')) %>%
#   st_as_sf() %>% 
#   ggplot() +
#   geom_sf(aes(fill = value), col = NA) +
#   facet_wrap(~name) +
#   scale_fill_viridis_c() +
#   theme_void()
# 
# # Save plot
# dir.create('plots/accessibility/', recursive = TRUE)
# ggsave('plots/accessibility/gp_cumulative.png', dpi = 300, bg = 'white')
