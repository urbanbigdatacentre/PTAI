# Pharmacies

# Date: 20231025

# This formats and consolidates pharmacies in GB


library(tidyverse)


# Read data ---------------------------------------------------------------

# England
england_p <- read_csv('data/pharmacy/england/consol_pharmacy_list_202324q1.csv')
# Scotland
scotland_p <- read_csv('data/pharmacy/scotland/dispenser_contactdetails_jan2023.csv')
# Wales
wales_p <- readxl::read_xlsx('data/pharmacy/wales/PharmacyChains_June23.xls.xlsx')
# Postcodes
postcodes <- data.table::fread('data/uk_postcodes/postcodes_reduced.csv')


# Format data -------------------------------------------------------------

# Clean names
england_p <- janitor::clean_names(england_p)
glimpse(england_p)

# Select relevant vars
england_p <- england_p %>% 
  select(pharmacy_ods_code_f_code, pharmacy_trading_name, post_code) %>% 
  rename(source_id = pharmacy_ods_code_f_code, name = pharmacy_trading_name)


# Format data scotland ----------------------------------------------------

# Clean names
scotland_p <- janitor::clean_names(scotland_p)
glimpse(scotland_p)

# Select variables
scotland_p <- scotland_p %>% 
  select(disp_code, disp_location_name, disp_location_postcode, datazone2011) %>% 
  rename(
    source_id = disp_code,
    name = disp_location_name,
    post_code = disp_location_postcode,
    lsoa11 = datazone2011
  ) %>% 
  mutate(source_id = as.character(source_id))


# Format data Wales -------------------------------------------------------

# Clean names
wales_p <- janitor::clean_names(wales_p)
glimpse(wales_p)

# Select and rename variables
wales_p <- wales_p %>% 
  select(account, trading_name, post_code) %>% 
  rename(
    source_id = account,
    name = trading_name
  )


# Consolidate data and write output ---------------------------------------


# Select variables in post codes
postcodes <- postcodes %>% 
  select(pcds, lsoa11)

# Join LSOA
pharmacies_all <- bind_rows(england_p, wales_p) %>% 
  left_join(postcodes, by = c('post_code' = 'pcds')) %>% 
  bind_rows(scotland_p)

# Write output
write_csv(pharmacies_all, 'data/pharmacy/pharmacies_gb.csv')



