## HOSPITALS

# Date: 2023-10-20




##----------------------------------------------------------------
##                  1. Format hospitals' data                   --
##----------------------------------------------------------------


# Packages ----------------------------------------------------------------

# Packages
library(tidyverse)
library(sf)
library(mapview)
library(data.table)

# Read post codes
postcodes <- data.table::fread('data/uk_postcodes/postcodes_reduced.csv')
# LSOA/DZ polygons
lsoa_gb <- st_read('data/uk_dataservice/infuse_lsoa_lyr_2011/infuse_lsoa_lyr_2011.shp')

# Key words for specialist hospitals:
# Journey time statistics: 2019
key_specialist <- 
  c(
    'birth', 'maternity', ' eye', 'rheumatic', 'throat', ' nose ', ' ear ',
    'neurology', 'neurosurgery', 'specialist emergency care', 'orthopaedic',
    'heart hospital', 'Children', 'Dental'
  )
# Key for Mental health,  psychiatric, learning disability, or Elderly
key_psy <- c( 'Mental',  'Psychiatr(y|ic)', 'Elder(|ly)', 'learning disabili(ty|ties)', 'Psychogeriatric')
# Day hospital
key_day <- c('Day (hospital|care)')

# Objects to keep 
obj_keep <- c(ls(), "obj_keep")

# Get data from Wales -----------------------------------------------------

# WEB PAGE NO LONGER AVAILABLE.
# base_url <- "https://www.wales.nhs.uk/ourservices/directory/Hospitals/"
# USING DATA EXTRACTED JAN/22
# 
# 

# Hospitals data in England -----------------------------------------------

## Read data
# England
hosp_eng <- read_csv('data/hospitals/england/Hospital_converted.csv')
hosp_eng <- janitor::clean_names(hosp_eng)

## Filter key hospitals
count(hosp_eng, sub_type)
# Exclude psychiatric or mental hospitals using label
hosp_eng <- filter(hosp_eng, sub_type != 'Mental Health Hospital')
# Exclude establishments containing key words related to mental health
hosp_eng <- hosp_eng %>% 
  filter(!grepl(paste(key_psy, collapse = '|'), organisation_name, ignore.case = TRUE))
# Exclude establishments containing key words related specialist units
hosp_eng %>% 
  filter(grepl(paste(key_specialist, collapse = '|'), organisation_name, ignore.case = TRUE)) %>% 
  pull(organisation_name)
hosp_eng <- hosp_eng %>% 
  filter(!grepl(paste(key_specialist, collapse = '|'), organisation_name, ignore.case = TRUE))
# Exclude Local Committee: 0 in England
hosp_eng <- hosp_eng %>% 
  filter(!grepl('Committee', organisation_name, ignore.case = TRUE))
# Exclude Day hospital
hosp_eng <- hosp_eng %>% 
  filter(!grepl(key_day, organisation_name, ignore.case = TRUE))

## Missing coordinates?
hosp_eng %>% 
  filter(is.na(longitude)) %>% 
  as.data.frame()
# Exclude overseas
hosp_eng <- hosp_eng %>% 
  filter(organisation_name != 'Jersey General Hospital')

# Input LSOA based on post code
hosp_eng <- 
  left_join(hosp_eng, select(postcodes, -lat:-long), by = c('postcode' = 'pcds'))
# Not matched
hosp_eng %>%  filter(is.na(lsoa11))

# Spatially join LSOA
hosp_eng <- hosp_eng %>% 
  filter(is.na(lsoa11)) %>% 
  select(-lsoa11) %>% 
  st_as_sf(coords = c('longitude', 'latitude'), crs = 4326, remove = FALSE) %>% 
  st_transform(st_crs(lsoa_gb)) %>% 
  st_join(., select(lsoa_gb, geo_code)) %>% 
  rename(lsoa11 = geo_code) %>%
  st_set_geometry(NULL) %>% 
  bind_rows(hosp_eng[!is.na(hosp_eng$lsoa11),])

# Missing LSOA?
hosp_eng %>% filter(is.na(lsoa11) | lsoa11 == "NA")

glimpse(hosp_eng)


# Hospitals data in Scotland ----------------------------------------------

# Data from Scotland
hosp_sco <-  data.table::fread('data/hospitals/scotland/hospitals.csv')

## Filter key hospitals
# Exclude establishments containing key words related to mental health
hosp_sco <- hosp_sco %>% 
  filter(!grepl(paste(key_psy, collapse = '|'), LocationName, ignore.case = TRUE))
# Exclude establishments containing key words related specialist units
hosp_sco %>% 
  filter(grepl(paste(key_specialist, collapse = '|'), LocationName, ignore.case = TRUE)) %>% 
  pull(LocationName)
hosp_sco <- hosp_sco %>% 
  filter(!grepl(paste(key_specialist, collapse = '|'), LocationName, ignore.case = TRUE))
# Exclude Local Committee: 0 in Scotland
hosp_sco <- hosp_sco %>% 
  filter(!grepl('Committee', LocationName, ignore.case = TRUE))
# Exclude Day hospital
hosp_sco <- hosp_sco %>% 
  filter(!grepl(key_day, LocationName, ignore.case = TRUE))


# Assign DZ if missing 
hosp_sco <- hosp_sco %>% 
  filter(DataZone == "") %>% 
  st_as_sf(coords = c("XCoordinate", "YCoordinate"), crs = 27700, remove = FALSE) %>% 
  st_join(., select(lsoa_gb, geo_code)) %>% 
  st_set_geometry(NULL) %>% 
  bind_rows(hosp_sco[DataZone != ""]) %>% 
  mutate(geo_code = coalesce(geo_code, DataZone)) 

# Extract Lat/Lon coordinates
hosp_sco <- hosp_sco %>%
  st_as_sf(coords = c('XCoordinate', 'YCoordinate'), crs = 27700) %>% 
  st_transform(4326) %>% 
  cbind(st_coordinates(.)) %>% 
  rename(Longitude = X, Latitude = Y) %>% 
  st_set_geometry(NULL)

glimpse(hosp_sco)


# Merge data in GB -------------------------------------------------------

# Read Wales data
wales_data <- read_csv('data/hospitals/wales/hospitals_wales.csv')

## make variables' names compatible
# England:
hosp_engF <- hosp_eng %>%
  select(organisation_id, organisation_name, lsoa11) %>%
  rename(source_id = organisation_id, name = organisation_name, lsoa = lsoa11)
# Scotland:
hosp_scoF <- hosp_sco %>% 
  select(LocationName, geo_code) %>% 
  janitor::clean_names() %>% 
  rename(name = location_name, lsoa = geo_code)
# Wales: (remove CHC Local Committee)
wales_dataF <- wales_data %>% 
  filter(type != 'CHC Local Committee') %>% 
  select(name, lsoa11) %>% 
  rename(lsoa = lsoa11)

# Bind list
hops_gb <- bind_rows(hosp_engF,  hosp_scoF, wales_dataF)

# Inspect data
glimpse(hops_gb)

# Save data
write_csv(hops_gb, 'data/hospitals/hospitals_gb.csv')

# Clean env. 
rm(list = ls())
gc()




