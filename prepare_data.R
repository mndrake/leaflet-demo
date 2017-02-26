library(leaflet)
library(maps)
library(maptools)
library(sp)
library(dplyr)
library(htmltools)

state_sp <- local({x <- map("state", fill = TRUE, plot = FALSE); map2SpatialPolygons(x, x$names)})
county_sp <- local({x <- map("county", fill = TRUE, plot = FALSE); map2SpatialPolygons(x, x$names)})

county_data <- county.fips %>%
  tidyr::extract(polyname, into = 'county_name', regex = '[a-z ]+,([a-z ]+)', remove = FALSE) %>%
  mutate(county_name = stringr::str_to_title(county_name),
         state_fips = floor(fips / 1000)) %>%
  left_join(state.fips %>% distinct(fips, abb), by = c('state_fips' = 'fips')) %>%
  mutate(county_name = paste0(county_name, ', ', abb, ' (', sprintf('%05d', fips) ,')')) %>%
  left_join(unemp, by = 'fips') %>% 
  mutate(unemp = coalesce(unemp, 0),
         hover_txt = purrr::map(stringr::str_c("name: ", county_name, "<br>", "Unemployment Percent: ", unemp, "%"), ~HTML(.)))

county_names <- purrr::set_names(as.character(county_data$polyname), county_data$county_name)

map.data <- list(
  state_sp = state_sp,
  county_sp = county_sp,
  county_data = county_data,
  county_names = county_names
)

readr::write_rds(map.data, 'map_data.rds')