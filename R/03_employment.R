###########################################################################
###########################################################################
###                                                                     ###
###                            SECTION 4.1:                             ###
###                     ACCESSIBILITY TO EMPLOYMENT                     ###
###                                                                     ###
###########################################################################
###########################################################################

# Last updated: 2023-08-14


# Packages ----------------------------------------------------------------

library(tidyverse)


##---------------------------------------------------------------
##            1. Inspect and format employment data            --
##---------------------------------------------------------------

# Format employment data  -------------------------------------------------

# All employment (NOMIS) data
employment_gb <- read_csv("data/employment/nomis/585122679950640.csv", skip = 8)

# Employment
employment_gb <- employment_gb %>%
  rename_all(tolower) %>% 
  rename(
    lsoa11cd = mnemonic, 
    employment = total
  ) %>% 
  select(lsoa11cd, employment) %>% 
  filter(!is.na(employment))

# Employment by region
employment_gb %>% 
  mutate(region = substr(lsoa11cd, 0, 1)) %>% 
  group_by(region) %>% 
  summarise(emp = sum(employment)) %>% 
  mutate(percent = emp / sum(employment_gb$employment))



# Employment by sector ----------------------------------------------------

# Employment (NOMIS) data
employment_sector <- 
  read_csv("data/employment/nomis_sector/1991121939484853.csv", skip = 8)

# Format col names
employment_sector <- employment_sector %>% 
  select(!starts_with('..')) %>% 
  janitor::clean_names() %>% 
  select(-area) %>% 
  rename(lsoa11cd = mnemonic)

# Short names by sector
new_names <-  paste0(
  'employment_',
  sub("^[^_]*_([^_]+)_.*$", "\\1", names(employment_sector)[-1]),
  '_', 1:18
)

# Assign new names
names(employment_sector)[-1] <- new_names



# Join all employment and save --------------------------------------------

# Join all employment and employment by sector
employment_gb <- employment_gb %>% 
  left_join(employment_sector, by = 'lsoa11cd') %>% 
  rename(employment_all = employment)


# Write aggregated employment
write_csv(employment_gb, 'data/employment/employment_gb.csv')
