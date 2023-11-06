# Table summary destinations

library(tidyverse)

# Read PTAI 22 
summary22 <- read_csv('data/pt_accessibility_22/destinations_summary.csv')
# Read land destinations 23
land_use <- read_csv('data/land_use_lsoa.csv')


# Fromat data -------------------------------------------------------------

# Summarise data 2023
summary_23 <- land_use %>% 
  summarise(across(-id, \(x) sum(x))) %>% 
  tibble::rownames_to_column() %>% 
  pivot_longer(-rowname, names_to = 'destination', values_to = 'total_23') 

# Drop disaggregated employment
summary_23 <- summary_23 %>% 
  filter(!grepl('[0-9]$', destination))

# Use compatible names
destination_cd <- c(
    "employment_all", "gp_practices", "hospitals","primary_schools",
    "secondary_schools",  "main_bua", "sub_bua",  "supermarkets"
)
summary22$destination_cd <- destination_cd

# Join summaries
summary_all <- summary22 %>% 
  # select(-England, -Scotland, -Wales) %>% 
  full_join(summary_23, by = c('destination_cd' = 'destination')) %>% 
  rename(total_22 = `Great Britain`) %>% 
  select(destination, starts_with('total'))

# Format summary
summary_all <- summary_all %>% 
  mutate(
    destination = replace_na(destination, 'Pharmacies'),
    destination = gsub('Education: ', '', destination)
  ) %>% 
  arrange(destination)


# Write summary -----------------------------------------------------------

# Write tables summary
write_csv(summary_all, 'descriptor/tables/destination_summary.csv')

# Summary employment by broad group ---------------------------------------

# Read industrial classification descriptor
industrial_groups <- read_csv('descriptor/tables/industrial_groups.csv')

# Service totals
summary_emp <- land_use %>% 
  summarise(across(-id, \(x) sum(x))) %>% 
  tibble::rownames_to_column() %>% 
  pivot_longer(-rowname, names_to = 'destination', values_to = 'total_23') 

# Join totals
summary_emp <- summary_emp %>% 
  filter(grepl("[0-9]$", destination)) %>% 
  left_join(industrial_groups, by = c('destination' = 'abbreviation')) %>% 
  select(destination, broad_group, total_23)
