# Exploratory

# Date: 2023-10-24

library(tidyverse)

# Read data ---------------------------------------------------------------

# Get file paths
file_paths <- list.files('output/', recursive = TRUE, full.names = TRUE)
# Read files
access_list <- lapply(file_paths, data.table::fread)

# Keep only cum accs
access_absolute <- access_list %>% 
  map(select, -contains('nearest'), -ends_with('pct'))

# Keep time of the day AM only
filter_tod <- function(df) {
  if ('time_of_day' %in% names(df)) {
    df <- df %>% filter(time_of_day == 'am')
    return(df)
  }
  return(df)
}
access_absolute <- access_absolute %>% 
  map(filter_tod) %>% 
  map(select, geo_code, mode, starts_with('access'))

# Measures into single DF
access_absolute <- access_absolute %>% 
  map(
    pivot_longer, 
    starts_with('access'), 
    values_to = 'accessibility', 
    names_sep = "_(?=[^_]*$)", 
    names_to = c("service", "time_cut")
  ) %>% 
  bind_rows()

# Format variables
access_absolute <- access_absolute %>% 
  mutate(
    nation = str_sub(geo_code, 0, 1),
    time_cut = as.integer(time_cut),
    service = gsub('access_', '', service)
  )



# Visualisations ----------------------------------------------------------

# Aggregate accessibility by mode and type of service
summary1 <- access_absolute %>% 
  group_by(mode, service, time_cut) %>% 
  summarise(access_mean = mean(accessibility))

# LinePlot: accessibility by time cut
line_plot_comaprison <- summary1 %>% 
  filter(time_cut <= 60) %>% 
  mutate(
    service = gsub('_', '\n', service),
    service = str_to_sentence(service)
    ) %>% 
  ggplot(aes(time_cut, access_mean, col = mode)) +
  geom_line(linewidth = 1) +
  scale_color_viridis_d(option = 'plasma', begin = 0.15, end = 0.85) +
  facet_wrap(~service, scales = 'free_y') +
  labs(
    x = 'Time (minutes)', 
    y = 'Average accessibility'
  ) +
  theme_minimal() +
  theme(legend.position = 'bottom')

# Save map
ggsave('plots/line_plot_comaprison.jpg', dpi = 400, height = 8, width = 10)


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

# Compute differece
access_comparison <- access_absolute %>% 
  pivot_wider(names_from = 'mode', values_from = 'accessibility') %>% 
  rowwise() %>% 
  mutate(pt_bike_diff = bicycle / pt) %>% 
  ungroup() %>% 
  left_join(lookup, by = c('geo_code' = 'lsoa11cd'))

# Subset area of interest
access_comparison_sf <- access_comparison %>%
  #filter(lad17nm == 'Glasgow City') %>% 
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
    title = 'Where can you reach more jobs by bicycle than by public transport in the morning peak?',
    fill = 'More jobs by:'
    ) +
  scale_fill_viridis_d(option = 'plasma', begin = 0.25, end = 0.75) +
  theme_void() +
  theme(legend.position = 'bottom')

# Save map
ggsave('plots/pt_vs_bike_map.jpg', dpi = 400, height = 5, width = 9)


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
    service = gsub('_', '\n', service),
    service = str_to_sentence(service)
  ) %>% 
  ggplot(aes(tt_minutes, service, fill = mode)) +
  geom_boxplot(outlier.alpha = 0.3, outlier.size = 0.5) +
  scale_fill_viridis_d(option = 'plasma', begin = 0.25, end = 0.75) +
  labs(
    title = 'Nearest facility by mode', 
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
