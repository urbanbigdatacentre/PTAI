## SCHOOLS

# Date: 2023-10-20

# Packages ----------------------------------------------------------------

library(tidyverse)
library(sf)
library(mapview)


# Read data ---------------------------------------------------------------

# Read post codes
postcodes <- data.table::fread('data/uk_postcodes/postcodes_reduced.csv')
# UK post codes
postcodes_all <- data.table::fread('data/uk_postcodes/ONSPD_AUG_2021_UK/Data/ONSPD_AUG_2021_UK.csv')
# LSOA/DZ geometries
lsoa_gb <- st_read('data/uk_dataservice/infuse_lsoa_lyr_2011/infuse_lsoa_lyr_2011.shp')


# Format data England -----------------------------------------------------

# Filter criteria follows Journey Time Statistics methodology (2019)

# Read England schools - All database
schools_eng <- read_csv('data/schools/england/extract/edubasealldata20230307.csv')
# Names
schools_eng <- janitor::clean_names(schools_eng)
# Status is 'Open
schools_eng <- filter(schools_eng, establishment_status_name == 'Open')
# Admission policy is not 'Selective
schools_eng <- filter(schools_eng, admissions_policy_name != 'Selective')

# See number of records for each type
as.data.frame(count(schools_eng, type_of_establishment_name))

# Keep type of establishment according to JTS.
type_establishment <-
  c(
    "Community school",
    "Voluntary aided school",
    "Voluntary controlled school",
    "Foundation school",
    "Academy sponsor led",
    "Academy converter",
    "Free schools",
    "University technical college",
    "Studio schools"
  )
schools_eng <- schools_eng |> 
  filter(type_of_establishment_name %in% type_establishment)

# Print number of records by phase
count(schools_eng, phase_of_education_name)

count(schools_eng, official_sixth_form_name)
count(schools_eng, further_education_type_name)

# Classify primary schools, secondary schools, based on JTS:
phase_primary <- c('Primary', 'Middle deemed primary', 'All-through')
phase_secondary <- c('Secondary', 'Middle deemed secondary', 'All-through')
schools_eng <- schools_eng %>% 
  mutate(
    type_primary = ifelse(phase_of_education_name %in% phase_primary, TRUE, FALSE),
    type_secondary = 
      ifelse(
        phase_of_education_name %in% phase_secondary & statutory_low_age < 16 & statutory_high_age >= 16, 
        TRUE, FALSE
      )
  )

# Exclude if it is not primary or secondary
schools_eng <- schools_eng %>% 
  filter(type_primary == TRUE | type_secondary == TRUE)

# Number of schools by type
table(schools_eng$type_primary)
table(schools_eng$type_secondary)

## Location
# check if LSOA is included
schools_eng %>% 
  filter(is.na(lsoa_code) | !grepl("[A-z]", lsoa_code))

# Spatially join LSOA code if missing
schools_eng <- schools_eng %>% 
  filter(!grepl("[A-z]", lsoa_code)) %>% 
  select(-lsoa_code) %>% 
  st_as_sf(coords = c("easting", "northing"), crs = 27700, remove = FALSE) %>% 
  st_join(., select(lsoa_gb, geo_code)) %>% 
  st_set_geometry(NULL) %>% 
  rename(lsoa_code = geo_code) %>% 
  bind_rows(filter(schools_eng, grepl("[A-z]", lsoa_code)))

# Transform CRS
schools_eng <- schools_eng %>% 
  st_as_sf(coords = c("easting", "northing"), crs = 27700) %>% 
  st_transform(4326) %>% 
  mutate(
    long = st_coordinates(.)[,1],
    lat = st_coordinates(.)[,2]
  ) %>% 
  st_set_geometry(NULL)

# Select variables
schools_eng <-  schools_eng %>% 
  mutate(
    source_id = urn,
    name = establishment_name,
    address = paste(street, locality, address3, postcode, town, sep = " | "),
    lsoa11 = lsoa_code) %>% 
  select(source_id:address, type_primary:type_secondary, lsoa11, postcode, long:lat)

# Glimpse 
glimpse(schools_eng)


# Format Wales data -------------------------------------------------------

# Read data
schools_wal <- readODS::read_ods(
  path = 'data/schools/wales/address-list-schools-wales.ods',
  sheet = 'Maintained'
)

# Names
schools_wal <- janitor::clean_names(schools_wal)

# Define NAs
schools_wal <- schools_wal %>% 
  mutate(across(where(is.character), na_if, y = '---'))

# Classify whether they provide primary, secondary or equivalent education
# Considering that middle covers a range from 3 to 19
schools_wal <- schools_wal %>% 
  mutate(
    type_primary = ifelse(sector == 'Primary' | sector == 'Middle', TRUE, FALSE),
    type_secondary = ifelse(sector == 'Secondary' | sector == 'Middle', TRUE, FALSE)
  )

# Exclude if it is not primary or secondary
schools_wal <- schools_wal %>% 
  filter(type_primary == TRUE | type_secondary == TRUE)

# Select variables
schools_wal <-  schools_wal %>% 
  mutate(
    source_id = school_number,
    name = school_name,
    address = paste( address_1,  address_2,  address_3,  address_4, postcode, sep = " | "),
    postcode = str_squish(postcode)) %>% 
  select(source_id:address, type_primary:type_secondary, postcode)

# Input LSOA/DZ and lat/lon based on post code
schools_wal <- left_join(schools_wal, postcodes, by = c("postcode" = "pcds"))

# Some records did not match a post code
filter(schools_wal, is.na(lat))

# Use terminated post codes data where there were not matches,
# assuming post code is outdated from source
schools_wal <- schools_wal %>% 
  filter(is.na(lat)) %>% 
  select(source_id:postcode) %>% 
  left_join(postcodes_all, by = c('postcode' = "pcds")) %>% 
  select(source_id:postcode, lsoa11, lat, long) %>% 
  bind_rows(schools_wal[!is.na(schools_wal$lat),])

# View data
glimpse(schools_wal)


# Format Scotland data ----------------------------------------------------

## Read data
# Public schools
schools_sc <- readxl::read_xlsx(
    path = 'data/schools/scotland/school+contact+list+30+April+2023.xlsx', 
    skip = 5, 
    sheet = 3
)

# Fix col names in data source
schools_sc <- janitor::clean_names(schools_sc)

# Classify primary and secondary establishments
schools_sc <- schools_sc %>% 
  mutate(
    type_primary = ifelse(primary_department == 'Yes', TRUE, FALSE),
    type_secondary = ifelse(secondary_department == 'Yes', TRUE, FALSE)
)

# Subset primary or secondary establishments  
schools_sc <- schools_sc %>% 
  filter(type_primary == TRUE | type_secondary == TRUE)

# Select variables
schools_sc <- schools_sc %>% 
  mutate(
    source_id = seed_code,
    name = school_name,
    address = paste(address_line1, address_line2, address_line3, sep = " | "),
    postcode = str_squish(post_code)
  ) %>% 
  select(source_id:postcode, type_primary:type_secondary)

# Input LSOA/DZ and lat/lon based on post code
schools_sc <- left_join(schools_sc, postcodes, by = c("postcode" = "pcds"))

# Some records did not match a post code
filter(schools_sc, is.na(lat))

# Use terminated post codes data where there were not matches,
# assuming post code is outdated from source
schools_sc <- schools_sc |> 
  filter(is.na(lat)) |> 
  select(source_id:type_secondary) %>% 
  left_join(postcodes_all, by = c('postcode' = "pcds")) |> 
  select(source_id:type_secondary, lsoa11, lat, long) |> 
  bind_rows(schools_sc[!is.na(schools_sc$lat),])

# Some records did not match a post code
schools_sc |> 
  filter(is.na(lat)) 

# Manually input DZ code
schools_sc <- schools_sc |> 
  filter(is.na(lat)) |> 
  mutate(
    lsoa11  = c('S01006515', 'S01008771'),
    lat  = c(57.111464, 55.982983),
    long = c(-2.230955, -3.191991)
  ) |> 
  bind_rows(schools_sc[!is.na(schools_sc$lat),])

## Inspect data
glimpse(schools_sc)

# Bind school data and save result ----------------------------------------

# Bind rows
schools_gb <- bind_rows(schools_eng, schools_wal, schools_sc)
# Glimpse
glimpse(schools_gb)
summary(schools_gb)

# Quick map to visualize the density of schools
schools_gb %>% 
  st_as_sf(coords = c('long', 'lat'), crs = 4326) %>% 
  st_transform(3035) %>% 
  cbind(st_coordinates(.)) %>%
  ggplot() +
  geom_hex(aes(X, Y), bins = c(70, 90)) +
  coord_equal() +
  scale_fill_viridis_c(option = 'plasma') +
  theme_void() 

# Save data
write_csv(schools_gb, 'data/schools/schools_gb.csv')

# Clean env.
rm(list = ls())








