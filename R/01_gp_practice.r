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
