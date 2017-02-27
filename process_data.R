library(tidyr)
library(dplyr)
library(tigris)
library(purrr)

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

county_table <- local({
  county_table <- county_sp@data
  county_table$LABPT <- map(county_sp@polygons, ~slot(.x, 'labpt'))
  county_table <- county_table %>% 
    rowwise() %>%
    mutate(LAT = LABPT[1],
           LON = LABPT[2]) %>%
    left_join(fips_codes, by = c('STATEFP' = 'state_code', 'COUNTYFP' = 'county_code')) %>%
    mutate(DISPLAY_NAME = paste0(NAME, ', ', state, ' (', GEOID, ')')) %>%
    select(GEOID, DISPLAY_NAME, STATEFP, COUNTYFP, COUNTY_NAME = NAME, STATE = state, 
           STATE_NAME = state_name, ALAND, AWATER, LAT, LON)
})
  
county_names <- purrr::set_names(county_table$GEOID, county_table$DISPLAY_NAME)

## county level data ----------------------------------------------

pop_unemp <- maps::unemp %>% 
  mutate(GEOID = sprintf('%05d', fips)) %>%
  gather(key = 'key', value = 'value', -GEOID, -fips) %>%
  select(-fips)

pop_density <- pop_unemp %>%
  filter(key == 'pop') %>%
  inner_join(county_table, by = 'GEOID') %>%
  rowwise() %>%
  mutate(key = 'density', 
         value = log(1 + (value / (as.numeric(ALAND) + as.numeric(AWATER)) * 1000000))) %>%
  select(GEOID, key, value)

county_data <- bind_rows(pop_unemp, pop_density)
county_stats <- set_names(c('pop', 'unemp', 'density'), c('Population', 'Unemployment', 'Density'))


## combine and save results ---------------------------------------

appdat <- list(
  state_sp = state_sp,
  county_sp = county_sp,
  county_table = county_table,
  county_names = county_names,
  county_stats = county_stats,
  county_data = county_data
)

readr::write_rds(appdat, 'assets/appdat.rds')