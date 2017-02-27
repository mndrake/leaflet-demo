library(shiny)
library(leaflet)
library(sp)
library(tigris)
library(dplyr)
library(htmltools)
#library(DT)

# global session variables ------------------------------------------

# read in application data
if (!file.exists('assets/appdat.rds')) {source('process_data.R')}
appdat <- readr::read_rds('assets/appdat.rds')

# maximum map bounding box
max_bbox <- bbox(appdat$state_sp)

# shiny server code ------------------------------------------

shinyServer(function(input, output, session) {
  
  ## initialization ----

  # initialize ui lookups
  updateSelectInput(session, 'stat', choices = c('select' = '', appdat$county_stats))
  updateSelectInput(session, 'polyname', choices = c('select' = '', appdat$county_names))

  # initialize county map 
  output$county_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles("CartoDB.PositronNoLabels", 
                       options = providerTileOptions(noWrap = TRUE, minZoom = 3, maxZoom = 10)) %>%
      addPolylines(data = appdat$state_sp, color = "darkgrey", weight = 0.8, stroke = TRUE) %>%
      setMaxBounds(max_bbox[1], max_bbox[2], max_bbox[3], max_bbox[4])
  })
  
  # leaflet proxy for redraws
  proxy <- leafletProxy("county_map")
  
  ## reactive values ----
  
  # county-level spatial dataframe
  selected_data <- reactive({
    req(input$stat != '')
    appdat$county_data %>% 
      filter(key == input$stat) %>% 
      select(-key) %>%
      right_join(appdat$county_table, by = 'GEOID') %>%
      mutate(hover_txt = purrr::map(paste0("name: ", DISPLAY_NAME, "<br>", "value: ", sprintf('%.2f', value)), ~HTML(.))) %>%
      select(GEOID, hover_txt, COUNTY_NAME, STATE, LAT, LON, value) %>%
      geo_join(appdat$county_sp, ., 'GEOID', 'GEOID')
  })

  # data tab table
  output$data <- DT::renderDataTable({
    selected_df <- selected_data()
    df <- selected_df@data %>%
      mutate(Action = paste0('<a class="go-map" href="" data-lat="', LAT, '" data-long="', LON,
                             '" data-geoid="', GEOID, '"><i class="fa fa-crosshairs"></i></a>')) %>%
      select(GEOID, STATEFP, COUNTYFP, COUNTY_NAME, STATE, VALUE = value, Action)
    action <- DT::dataTableAjax(session, df)
    DT::datatable(df, options = list(ajax = list(url = action), searching = FALSE), 
                  escape = FALSE, selection = 'none')
  })
  
  # update county-level map
  observe({
    county_df <- selected_data()
    pal <- colorNumeric(palette = "YlGnBu", domain = county_df@data$value)
    proxy %>%
      clearShapes() %>%
      clearControls() %>%
      addPolylines(data = appdat$state_sp, color = "darkgrey", weight = 1.2, stroke = TRUE) %>%
      addPolygons(data = county_df, weight = 0.3, color = "#b2aeae", fillOpacity = 0.6, smoothFactor = 0.2,
                  fillColor = ~pal(value), 
                  label = ~(hover_txt),
                  labelOptions = labelOptions(direction = 'auto'),
                  layerId = ~GEOID,
                  highlightOptions = highlightOptions(color = '#ff0000', opacity = 1,
                                                      weight = 2, fillOpacity = 1,
                                                      bringToFront = TRUE, sendToBack = TRUE)) %>%
      addLegend(pal = pal,
                values = county_df@data$value,
                labels = NULL,
                position = "bottomleft",
                title = NULL)
  })
  

  ## events ----

  ## zoom in on county on selection
  observe({
    req(input$polyname != '')
    # get the selected polygon and extract the label point
    selected_polygon <- appdat$county_sp[appdat$county_sp$GEOID == input$polyname,]
    selected_bbox <- bbox(selected_polygon)
    # remove any previously highlighted polygon
    proxy %>% removeShape("highlighted")
    # center the view on the polygon
    proxy %>% setView(lng = mean(selected_bbox['x',]),
                      lat = mean(selected_bbox['y',]), zoom = 8)
    # add a slightly thicker red polygon on top of the selected one
    proxy %>% addPolylines(stroke = TRUE, weight = 4, color = "red",
                           data = selected_polygon, layerId = "highlighted")
  })

  ## reset map on click
  observeEvent(input$reset_map, {
    updateSelectInput(session, 'polyname', selected = "")
    # remove any previously highlighted polygon
    proxy %>% removeShape("highlighted")
    # center the view on the polygon
    proxy %>% fitBounds(max_bbox[1], max_bbox[2], max_bbox[3], max_bbox[4])
  })
  
  ## select county on click
  observeEvent(input$county_map_shape_click, {
    click <- input$county_map_shape_click
    updateSelectInput(session, 'polyname', selected = click$id)
  })
   
  ## goto selected county from data tab
  observe({
    req(input$goto)
    isolate({selected_geoid <- input$goto$geoid})
    updateNavbarPage(session, 'main', selected = 'map')
    updateSelectInput(session, 'polyname', selected = selected_geoid)
  })

})
  