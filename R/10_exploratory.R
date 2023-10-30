# Exploratory

# Date: 2023-10-26

library(tidyverse)
library(sf)

# Read data ---------------------------------------------------------------

# Get file paths
file_paths <- list.files('output/', recursive = TRUE, full.names = TRUE, pattern = 'access')
# Read files
access_list <- lapply(file_paths, data.table::fread)

# read TTW areas
ttwa <- st_read('data/uk_gov/ttwa2011_pop.gpkg')
# Read centroids
centroids <- st_read('data/centroids/gb_lsoa_centroid2011.gpkg')



# Spatially join TTWA to centroids ----------------------------------------

# Identify cities
ttwa <- ttwa %>%
  arrange(-total_population) %>% 
  mutate(
    pop_ranking = 1:nrow(.),
    city_large = if_else(pop_ranking < 25, 'city', 'other')
  )

# Select relevant variables
ttwa <- ttwa %>% 
  select(ttwa11nm, city_large, pop_ranking)

# TTWA lookup
ttwa_lookup <- centroids %>% 
  select(geo_code) %>% 
  st_join(ttwa) %>% 
  st_drop_geometry()


# Format accessibility measures -------------------------------------------

# Keep realtive cum accessibility measures only
access_relative <- access_list %>% 
  map(select, -contains('nearest'), -matches('[0-9]$'))

# Keep time of the day AM only
filter_tod <- function(df) {
  if ('time_of_day' %in% names(df)) {
    df <- df %>% filter(time_of_day == 'am')
    return(df)
  }
  return(df)
}
access_relative <- access_relative %>% 
  map(filter_tod) %>% 
  map(select, geo_code, mode, starts_with('access'))

# Measures into single DF
access_relative <- access_relative %>% 
  map(~rename_with(.x, \(colname) gsub('_pct', '', colname))) %>% 
  map(
    pivot_longer, 
    starts_with('access'), 
    values_to = 'accessibility', 
    names_sep = "_(?=[^_]*$)", 
    names_to = c("service", "time_cut")
  ) %>% 
  bind_rows()

# Format variables
access_relative <- access_relative %>% 
  mutate(
    nation = str_sub(geo_code, 0, 1),
    time_cut = as.integer(time_cut),
    service = gsub('access_', '', service)
  )


# Visualisations ----------------------------------------------------------

mode_labs <- c('Bicycle', 'Public transport', 'Walk')

# Aggregate accessibility by mode and type of service
summary1 <- access_relative %>% 
  group_by(mode, service, time_cut) %>% 
  summarise(
    access_mean = mean(accessibility),
    access_sd = sd(accessibility),
    access_median = median(accessibility),
    access_q1 = quantile(accessibility, 0.25),
    access_q3 = quantile(accessibility, 0.75)
  )

# LinePlot: accessibility by time cut
line_plot_comaprison <- summary1 %>% 
  filter(time_cut <= 60) %>% 
  mutate(
    service = gsub('_(?=[a-z])', '\n', service, perl = TRUE),
    service = gsub('_', ' ', service, perl = TRUE),
    service = str_to_sentence(service)
  ) %>% 
  ggplot(aes(x = time_cut, group = mode)) +
  geom_line(aes(y = access_mean, col = mode), linewidth = 1) +
  scale_color_viridis_d(option = 'plasma', begin = 0.15, end = 0.85) +
  scale_y_continuous(labels = scales::unit_format(unit = '', accuracy = 0.1)) +
  facet_wrap(~service, scales = 'free_y') +
  labs(
    x = 'Time (minutes)', 
    y = 'Average relative accessibility (%)',
    col = 'Mode'
  ) +
  theme_minimal() +
  theme(legend.position = 'bottom')

# Save map
ggsave('plots/line_plot_comaprison.jpg',plot = line_plot_comaprison, dpi = 400, height = 7, width = 10)


# Places where access by bicycle is higher than PT ------------------------

library(sf)
library(mapview)

# Read files
lsoa_geoms <- st_read('data/uk_dataservice/infuse_lsoa_lyr_2011_clipped/infuse_lsoa_lyr_2011_clipped.shp')
lookup <- read_csv('data/uk_gov/Output_Area_Lookup_in_Great_Britain.csv')

# Simplify lookup
lookup <- lookup %>% 
  janitor::clean_names() %>% 
  select(lsoa11cd, lad17nm, rgn11nm) %>% 
  distinct()

# Compute difference
access_comparison <- access_absolute %>% 
  pivot_wider(names_from = 'mode', values_from = 'accessibility') %>% 
  rowwise() %>% 
  mutate(pt_bike_diff = bicycle / pt) %>% 
  ungroup() 

# Join LSOA/DZ classifications
access_comparison <- access_comparison %>% 
  left_join(lookup, by = c('geo_code' = 'lsoa11cd')) %>% 
  left_join(ttwa_lookup, by = 'geo_code')

# Subset area of interest
access_comparison_sf <- access_comparison %>%
  #filter(ttwa11nm == 'Glasgow') %>%
  filter(rgn11nm == 'London') %>%
  filter(service == 'employment_all' & time_cut %in% c(30, 45)) %>%
  mutate(
    bike = if_else(bicycle > pt, 'bike', 'pt')
  ) %>%
  left_join(lsoa_geoms, by = 'geo_code') %>%
  st_as_sf()

# Map comparison
pt_bike_map <- access_comparison_sf %>%
  mutate(time_cut = factor(time_cut, labels = c('In 30 min', 'In 45 min'))) %>%
  ggplot() +
  geom_sf(aes(fill = bike), col = NA) +
  facet_wrap(~time_cut) +
  labs(
    title = 'Where can you reach more jobs by bicycle than by public transport?',
    subtitle = 'Map showing London at the morning peak.',
    fill = 'More jobs by:'
  ) +
  scale_fill_viridis_d(option = 'plasma', begin = 0.25, end = 0.75) +
  theme_void() +
  theme(legend.position = 'bottom')

# Save map
ggsave('plots/pt_vs_bike_map.jpg', pt_bike_map, dpi = 400, height = 5, width = 9)


# Nearest facility  -------------------------------------------------------

# Keep only cum accs
access_nearest <- access_list %>% 
  map(select, -contains('access'))
# Keep time of the day AM only
access_nearest <- access_nearest %>% 
  map(filter_tod) %>% 
  map(select, geo_code, mode, starts_with('nearest'))

# Keep measures not about employment
not_employment <- grep('employment', file_paths, invert = TRUE)
access_nearest <- access_nearest[not_employment]

# Measures into single DF
access_nearest <- access_nearest %>% 
  map(
    pivot_longer, 
    starts_with('nearest'), 
    values_to = 'tt_minutes', 
    names_to = 'service'
  ) %>% 
  bind_rows() %>% 
  mutate(service = gsub('nearest_', '', service))

# Boxplot nearest service
nearest_boxplot <- access_nearest %>% 
  mutate(
    service = gsub('_(?=[a-z])', '\n', service, perl = TRUE),
    service = gsub('_', ' ', service, perl = TRUE),
    service = str_to_sentence(service),
    service = fct_reorder(service, tt_minutes, .desc = TRUE)
  ) %>% 
  ggplot(aes(tt_minutes, service, fill = mode)) +
  geom_boxplot(alpha = 0.8, outlier.alpha = 0.3, outlier.size = 0.5) +
  scale_fill_viridis_d(option = 'plasma', begin = 0.25, end = 0.75) +
  coord_cartesian(xlim = c(0, 120)) +
  labs(
    title = 'Nearest facility by mode', 
    subtitle = 'Plot limited to 120 minutes',
    x = 'Travel time (minutes)', 
    y = 'Service',
    fill = ''
  ) +
  theme_minimal()

# Save boxplot
ggsave(
  filename = 'plots/nearest_boxplot.jpg', 
  plot = nearest_boxplot, 
  dpi = 400, 
  height = 8, 
  width = 6
)


# Summary of NA by mode
# this assumes that the nearest service is > 150 min
access_nearest %>% 
  filter(is.na(tt_minutes)) %>% 
  count(mode, service) %>% 
  pivot_wider(names_from = 'mode', values_from = 'n')

