library(shiny)
library(leaflet)
library(sp)
library(dplyr)

# global session variables ------------------------------------------

# read in application data
appdat <- readr::read_rds('map_data.rds')

county_sp <- local({
  x <- appdat$county_data
  rownames(x) <- x$polyname
  SpatialPolygonsDataFrame(appdat$county_sp, data = x)
})

pal <- colorNumeric(palette = "YlGnBu", domain = county_sp@data$unemp)

# shiny server code ------------------------------------------

shinyServer(function(input, output, session) {

  # initialize county names
  updateSelectInput(session, 'polyname', choices = c('select county' = '', appdat$county_names))
  
  # leaflet proxy for redraws
  proxy <- leafletProxy("county_map")
  
  # maximum map bounding box
  max_bbox <- bbox(appdat$state_sp)

  # initialize map    
  output$county_map <- renderLeaflet({
    leaflet() %>%
      addProviderTiles("CartoDB.PositronNoLabels",
                       options = providerTileOptions(noWrap = TRUE, minZoom = 3, maxZoom = 10)) %>%
      addPolylines(data = appdat$state_sp, color = "darkgrey", weight = 0.8, stroke = TRUE) %>%
      addPolygons(data = county_sp, weight = 0.3, color = "#b2aeae", fillOpacity = 0.7, smoothFactor = 0.2,
                  fillColor = ~pal(unemp), label = ~(hover_txt),
                  labelOptions = labelOptions(direction = 'auto'),
                  layerId = ~polyname,
                  highlightOptions = highlightOptions(color = '#ff0000', opacity = 1,
                                                      weight = 2, fillOpacity = 1,
                                                      bringToFront = TRUE, sendToBack = TRUE)) %>%
      addLegend(pal = pal,
                values = county_sp@data$unemp,
                labels = NULL,
                position = "bottomleft",
                title = NULL,
                labFormat = labelFormat(suffix = "%")) %>%
      setMaxBounds(max_bbox[1], max_bbox[2], max_bbox[3], max_bbox[4])
  })
  
  ## zoom in on county on selection
  observe({
    req(input$polyname != '')
    # get the selected polygon and extract the label point
    selected_polygon <- appdat$county_sp[input$polyname]
    polygon_labpt <- selected_polygon@polygons[[1]]@labpt
    # remove any previously highlighted polygon
    proxy %>% removeShape("highlighted")
    # center the view on the polygon 
    proxy %>% setView(lng = polygon_labpt[1], lat = polygon_labpt[2], zoom = 8)
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
})