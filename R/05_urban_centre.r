
### URBAN CENTRES 

# Date: 2023-10-20

##----------------------------------------------------------------
##                        1. Format data                        --
##----------------------------------------------------------------

# Load packages
library(tidyverse)
library(sf)
library(mapview)

# References
# Article: https://doi.org/10.1177%2F0042098019860776
# GitHub repository: https://github.com/MengLeZhang/decentralisationPaper2


# Read data ---------------------------------------------------------------

# LSOA-TTWA-centres lookup - Meng Le Zhang github (nearest main/sub-centre)
df_ttwa_read <- 
  read_csv("https://raw.githubusercontent.com/MengLeZhang/decentralisationPaper2/master/Saved%20generated%20data/Distance%20from%20nearest%20centre%20for%20zones%20and%20TTWA%20lkp.csv")
# Full list of locations. Imputed centres based on osmdata for England and Scotland.
inputed_centres <- 
  read_csv('https://raw.githubusercontent.com/MengLeZhang/decentralisationPaper2/master/Saved%20generated%20data/Imputed%20centres%20based%20on%20osmdata%20for%20England%20and%20Scotland.csv')

# LSOA/DZ polygons
lsoa_gb <- st_read('data/uk_dataservice/infuse_lsoa_lyr_2011/infuse_lsoa_lyr_2011.shp')


# Identify main/secondary BUA ---------------------------------------------

# Full list of centres as SF according to imputed coordinates
inputed_centres <- inputed_centres  %>%
  st_as_sf(coords = c('imputed_easting', 'imputed_northing'), crs = 27700) 
# Assign LSOA/DZ code to imputed locations
inputed_centres <- inputed_centres %>%
  st_join(., select(lsoa_gb, geo_code))

# There are 4 that could not be spatially joined
inputed_centres %>% 
  filter(is.na(geo_code)) %>% 
  mapview()
# Assign nearest when code is missing
inputed_centres <- inputed_centres %>% 
  filter(is.na(geo_code)) %>% 
  select(-geo_code) %>% 
  st_join(., select(lsoa_gb, geo_code), join = st_nearest_feature) %>% 
  bind_rows(filter(inputed_centres, !is.na(geo_code)))


# Filter ttwa to 2011 zones
df_ttwa_lookup <- df_ttwa_read %>% 
  filter(zone_type == "lsoa11" | zone_type == "dz11") %>% 
  rename(lsoa_code = zone)
summary(df_ttwa_lookup)

# Create list of unique names of main and secondary BUA
main_bua <- unique(df_ttwa_lookup$main_bua)
nearest_bua <- unique(df_ttwa_lookup$nearest_bua)

# Identify main BUA form full list of imputed locations
main_bua <- inputed_centres %>% 
  filter(name %in% main_bua)
# Identify secondary BUA
secondary_bua <- inputed_centres %>% 
  filter(name %in% nearest_bua)

# Visualize centres 
mapview(secondary_bua, col.region = 'yellow') +
  mapview(main_bua, col.region = 'red')


# Select relevant variables
main_bua <- select(main_bua, name, pop11, geo_code)
secondary_bua <- select(secondary_bua, name, pop11, geo_code)


# Save locations
st_write(main_bua, 'data/urban_centres/main_bua.gpkg')
st_write(secondary_bua, 'data/urban_centres/sub_bua.gpkg')

# Clean env.
rm(list = ls())







