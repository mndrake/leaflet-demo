library(shiny)
library(DT)
library(leaflet)


navbarPage('Map Demo', id = 'main',
           tabPanel('map', value = 'map',
                    div(class = 'outer',
                        
                        tags$head(includeCSS('assets/style.css'),
                                  includeScript("assets/gomap.js")),
                        
                        leafletOutput('county_map', width = '100%', height = '100%'),
                        
                        absolutePanel(id = 'controls', class = 'panel panel-default', fixed = TRUE,
                                      draggable = TRUE, top = 60, left = 'auto', right = 20, 
                                      bottom = 'auto', width = 330, height = 'auto',
                                      
                                      selectInput('stat', label = 'statistic', choices = NULL, selected = NULL),
                                      selectInput('polyname', label = 'county', choices = NULL, selected = NULL),
                                      actionButton("reset_map", "reset map")
                        )
                    )
           ),
           tabPanel('data', value = 'map',
                        DT::dataTableOutput('data'),
                        conditionalPanel("false", icon("crosshair"))
           )
)
