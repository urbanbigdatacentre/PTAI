# Inventory of files

library(fs)
library(tidyverse)

# Get files' info
file_info <- fs::dir_info('output/', recurse = TRUE)

# Select variables
file_info <- file_info %>% 
  select(path, type, size)

# Adjust path
file_info <- file_info %>% 
  mutate(path = gsub('output', '.', path))

# save inventory
write_csv(file_info, 'output/inventory.csv')

