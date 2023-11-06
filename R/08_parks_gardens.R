# Park and green areas


library(tidyverse)
library(sf)
library(mapview)


# Read data ---------------------------------------------------------------

# Read green space data
greenspace_site <- st_read('data/greenspace/opgrsp_gpkg_gb/Data/opgrsp_gb.gpkg', layer = 'greenspace_site')
access_point <- st_read('data/greenspace/opgrsp_gpkg_gb/Data/opgrsp_gb.gpkg', layer = 'access_point')

# Read LSOA boundaries
lsoa_geoms <- st_read('data/uk_dataservice/infuse_lsoa_lyr_2011/infuse_lsoa_lyr_2011.shp')


# Process polygons --------------------------------------------------------

# Transform LSOA's CRS
lsoa_geoms <- st_transform(lsoa_geoms, crs = st_crs(greenspace_site))

# Keep public green areas only
greenspace_site <- greenspace_site %>% 
  filter(function. == 'Public Park Or Garden')

# Intersect the green space areas with the LSOA geoms
greenspace_site_intersection <- st_intersection(greenspace_site, lsoa_geoms)

# Compute surface area of fragments
greenspace_site_intersection <- greenspace_site_intersection %>%
  mutate(area_ha = as.numeric(st_area(.)) / 10e3)

# Distribution size of parks
summary(greenspace_site_intersection$area_ha)


# Aggregate surface by LSOA
greenspace_surface <- greenspace_site_intersection %>% 
  st_drop_geometry() %>% 
  group_by(geo_code) %>% 
  summarise(area_ha = sum(area_ha))


# Process points of access ------------------------------------------------

# Keep access points corresponding to parks or gardens only
access_point_parks <- access_point %>% 
  filter(ref_to_greenspace_site %in% greenspace_site$id)


# Check polygons without access points
greenspace_site_inter <- st_join(greenspace_site, access_point)

# Get vertex points for polygons without access points
# This assumes that access is possible through anywhere in the perimeter

# Compute the boundary for polygons without access points
boundaries <- greenspace_site_inter %>% 
  filter(is.na(id.y)) %>% 
  st_boundary(.)
# Segmentize the boundary to add more points between vertices
# max_dist is the maximum distance between points (in the units of the CRS)
segmentized_boundaries <- 
  st_segmentize(boundaries, 50)
# Cast the segmentized boundary to POINT geometry
boundary_points <- st_cast(segmentized_boundaries, "POINT")


# Bind original access points and boundary points
all_access_points <- bind_rows(access_point_parks, boundary_points)

# Join LSOA IDs to access points
# consider a 10 m tolerance for points falling within a limit of boundaries
all_access_points <- all_access_points %>% 
  st_buffer(10) %>% 
  st_join(lsoa_geoms)

# Aggregate points of access by LSOA
accesspoints_count <- all_access_points %>% 
  st_drop_geometry() %>% 
  count(geo_code, name = 'park_accesspoints')

# Original access points count by LSOA
access_count_original <- access_point_parks %>% 
  st_join(lsoa_geoms) %>%
  st_drop_geometry() %>% 
  count(geo_code, name = 'original_accesspoints')

# Join access points and polygon area summary -----------------------------

# Join points and polygon summaries
greenspace_aggregated <- greenspace_surface %>% 
  full_join(accesspoints_count, by = 'geo_code') %>% 
  full_join(access_aggregated_oringal, by = 'geo_code')


# Inspect results ---------------------------------------------------------

# Summary
summary(greenspace_aggregated)

# LSOAs overlapping some green areas but with no access points
lsoa_without_accesspoint <- greenspace_aggregated %>% 
  filter(is.na(park_accesspoints)) %>% 
  pull(geo_code)

# subset green area under this circumstances
green_without <-
  greenspace_site_intersection %>% 
  filter(geo_code %in% lsoa_without_accesspoint)
# Subset example in Scoland
lsoas_scotland <- lsoa_geoms %>% 
  filter(grepl("^S", geo_code))

# Interactive map
mapview(green_without, col.region = 'green') +
  mapview(lsoas_scotland, alpha.region = 0) +
  mapview(all_access_points, col.region = 'red')

# Note that it is the case that some LSOA geometries overalap green sites. 
# But, do not have an access point within it.
# Conversely, there are some LSOA geoms that have access to green site, 
# but do not have green surface overlapping it.
 

# Write output ------------------------------------------------------------

# Write green area summary by LSOA
write_csv(greenspace_aggregated, 'data/greenspace/greenspace_summary.csv')

