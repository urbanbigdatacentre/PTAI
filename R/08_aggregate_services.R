
# Aggregate services at LSOA/DZ

# Date: 2023-10-26

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
# Pharmacies
pharmacies <- read_csv('data/pharmacy/pharmacies_gb.csv')
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
pharmacies_count <- pharmacies %>% 
  count(lsoa11, name = 'pharmacies')
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
  left_join(pharmacies_count, by = c('lsoa11cd' = 'lsoa11')) %>% 
  left_join(main_bua_count, by = c('lsoa11cd' = 'geo_code')) %>% 
  left_join(sub_bua_count, by = c('lsoa11cd' = 'geo_code')) %>% 
  rename(id = lsoa11cd)

# NAs as 0, assuming there is none of these services
land_use <- land_use %>% 
  mutate(across(-id, \(x) replace_na(x, 0)))


# Write output ------------------------------------------------------------

# Write csv
write_csv(land_use, 'data/land_use_lsoa.csv')
