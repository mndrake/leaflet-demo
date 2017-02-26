library(tidyr)
library(dplyr)
library(tigris)

## state and county spatial and lookup tables ---------------------

# based on: https://www.datascienceriot.com/mapping-us-counties-in-r-with-fips/kris/

# download shape files
county_sp <- counties(cb = TRUE, year = 2014, resolution = '20m')
state_sp <- states(cb = TRUE, year = 2014, resolution = '20m')

# remove non-contiguous US
state_sp <- state_sp[!state_sp$STATEFP %in% c("02", "15", "72", "66", "78", "60", "69",
                                              "64", "68", "70", "74", "81", "84", "86", 
                                              "87", "89", "71", "76", "95", "79"),]
county_sp <- county_sp[!county_sp$STATEFP %in% c("02", "15", "72", "66", "78", "60", "69",
                                                 "64", "68", "70", "74", "81", "84", "86", 
                                                 "87", "89", "71", "76", "95", "79"),]

county_table <- fips_codes %>%
  mutate(GEOID = paste0(state_code, county_code),
         county_name = paste0(county, ', ', state, ' (', GEOID, ')'))
  
county_names <- purrr::set_names(county_table$GEOID, county_table$county_name)

## county level data ----------------------------------------------

pop_unemp <- maps::unemp %>% 
  mutate(GEOID = sprintf('%05d', fips)) %>%
  gather(key = 'key', value = 'value', -GEOID, -fips) %>%
  select(-fips)

pop_density <- pop_unemp %>%
  filter(key == 'pop') %>%
  inner_join(county_sp@data, by = 'GEOID') %>%
  mutate(key = 'density',
         value = log(1 + (coalesce(value / (ALAND + AWATER) * 1000000, 0)))) %>%
  select(GEOID, key, value)

county_data <- bind_rows(pop_unemp, pop_density)
county_stats <- unique(county_data$key)

## combine and save results ---------------------------------------

appdat <- list(
  state_sp = state_sp,
  county_sp = county_sp,
  county_table = county_table,
  county_names = county_names,
  county_stats = county_stats,
  county_data = county_data
)

readr::write_rds(appdat, 'appdat.rds')