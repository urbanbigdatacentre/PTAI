###########################################################################
###########################################################################
###                                                                     ###
###                            SECTION 4.6:                             ###
###                    ACCESSIBILITY TO SUPERMARKETS                    ###
###                                                                     ###
###########################################################################
###########################################################################

# Date: 2023:08-04
# Supermarket locations from OSM

# Packages ----------------------------------------------------------------

library(tidyverse)
library(mapview)
library(sf)
library(osmdata)

##---------------------------------------------------------------
##                         Format data                         --
##---------------------------------------------------------------


# Read data ---------------------------------------------------------------

# OA polygons
oa_geoms <- st_read('data/uk_dataservice/infuse_oa_lyr_2011_clipped/infuse_oa_lyr_2011_clipped.shp')
# Read lookup table
lookup <- read_csv('data/uk_gov/Output_Area_Lookup_in_Great_Britain.csv')

# Get OSM supermarket data ------------------------------------------------

# Bounding box
uk <- opq_osm_id(id = 62149, type = "relation") %>%
  opq_string() %>%
  osmdata_sf()
bb <- getbb("United Kingdom", featuretype = "country")

# Date to download
# extract data as represented in the OSM database prior to a specified date
datetime <- '2023-03-08T00:00:00Z'

# Download supermarket data
supermarket_all <- bb %>%
  opq(timeout = 60*30, datetime = datetime) %>%
  add_osm_feature(key = 'shop', value = 'supermarket') %>%
  osmdata_sf()

# Save raw OSM data as RDS
dir.create('data/shops/osm', recursive = TRUE)
saveRDS(supermarket_all, 'data/shops/osm/supermarket_raw.rds')


# Filter data -------------------------------------------------------------

# Read raw OSM data
supermarket_all <- readRDS('data/shops/osm/supermarket_raw.rds')

# Keep points which include names or brand
supermarket_points <- 
  supermarket_all$osm_points %>% 
  filter(!is.na(name)) %>% # | !is.na(brand) [This represents only 1 exta location]
  mutate(
    long = st_coordinates(.)[,1],
    lat = st_coordinates(.)[,2]
  )
# # Map supermarket points
# supermarket_points %>% 
#   filter(lat > 55.6 & lat < 56) %>% 
#   mapview(col.region = "red") 

# Supermarket polygon as centroid
supermarket_poly <- 
  supermarket_all$osm_polygons %>% 
  st_centroid(.) %>% 
  mutate(
    long = st_coordinates(.)[,1],
    lat = st_coordinates(.)[,2]
  )
# Compute surface area
supermarket_poly$area_sqm <- 
  supermarket_all$osm_polygons %>% 
  st_transform(27700) %>% 
  st_area(.) %>% 
  as.numeric
summary(supermarket_poly$area_sqm)

# Filter 'large' shop > 280 sqm.
# Ref: The Sunday Trading Act 1994 (the STA 1994)
# https://commonslibrary.parliament.uk/research-briefings/sn05522/
supermarket_poly <- supermarket_poly %>% 
  filter(area_sqm > 280)

# Map supermarket centroids
supermarket_poly %>% 
  filter(lat > 55.6 & lat < 56) %>% 
  mapview(col.region = "red")

# Bind rows
supermarket_bind <- 
  bind_rows(supermarket_points, supermarket_poly)
# Subset amenity is NA (This refers to small services, e.g. ATMs)
supermarket_bind <- filter(supermarket_bind, is.na(amenity))

# Select relevant columns
supermarket_bind <- select(supermarket_bind, osm_id, name, brand, area_sqm, long, lat)
summary(supermarket_bind)

# Filter objects within the UK
supermarkets_gb <- supermarket_bind %>%
  filter(st_intersects(., uk$osm_multipolygons, sparse = FALSE))

# Show the most frequent brands
brand_freq <- sort(table(supermarkets_gb$brand), decreasing = TRUE)
brand_freq[1:20]

# Filter larger brands
brands <- c('Lidl', 'ALDI', 'Co-op', 'Sainsbury', 'Tesco','Asda','Morrisons')
supermarkets_gb <- supermarkets_gb %>%
  # Keep records which contain the previous words either in brand or name
  filter(
    grepl(paste(brands, collapse = '|'), name, ignore.case = TRUE) |
           grepl(paste(brands, collapse = '|'), brand, ignore.case = TRUE) 
  )

# Spatially join OAs
supermarkets_gb <- supermarkets_gb %>% 
  st_transform(st_crs(oa_geoms)) %>% 
  st_join(., oa_geoms) %>% 
  rename(oa11cd = geo_code)

# Select relevant lookup columns
lookup <- lookup %>% 
  select(OA11CD, LSOA11CD) %>% 
  janitor::clean_names()
# Left join lookup table
supermarkets_gb <- supermarkets_gb %>% 
  left_join(lookup, by = 'oa11cd')

# Keep Supermarkets within GB only
supermarkets_gb <- supermarkets_gb %>% 
  filter(grepl("^(E|S|W)", lsoa11cd))

# Count by country
supermarkets_gb %>% 
  st_drop_geometry() %>% 
  mutate(country = str_sub(lsoa11cd, 1, 1)) %>% 
  count(country)

# Save data
supermarkets_gb <- st_set_geometry(supermarkets_gb, NULL)
write_csv(supermarkets_gb, 'data/shops/supermarkets_osm.csv')

