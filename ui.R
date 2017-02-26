library(shiny)
library(leaflet)


navbarPage('Map Demo',
           tabPanel('map',
                    div(class = 'outer',
                        
                        tags$head(includeCSS('style.css')),
                        
                        leafletOutput('county_map', width = '100%', height = '100%'),
                        
                        absolutePanel(id = 'controls', class = 'panel panel-default', fixed = TRUE,
                                      draggable = TRUE, top = 60, left = 'auto', right = 20, 
                                      bottom = 'auto', width = 330, height = 'auto',
                                      selectInput('polyname', label = 'county', choices = NULL, selected = NULL),
                                      actionButton("reset_map", "reset map")
                        )
                    )
           )
)
