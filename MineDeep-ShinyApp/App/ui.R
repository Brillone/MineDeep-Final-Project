library(shiny)
library(shinythemes)
library(visNetwork)
library(leaflet)
library(plotly)
library(shinydashboard)
library(bubbles)
library(shinyjs)

ui <- shinyUI(navbarPage(title=img(src = "logo.png", height = 120, width = 120,style = "position: relative; top: -45px;"), 
  tabPanel("World-Wide Analysis",
           fluidPage(tags$head(tags$style(
                     type="text/css",
                     "#myImage img {max-width: 100%; width: 100%; height: 62%}"
                     )),
                     includeCSS(path = "AdminLTE.css"),
                     includeCSS(path = "shinydashboard.css"), 
           wellPanel(
             fluidRow(
               column(6,
                      radioButtons("map_id", "Map Type:",  
                                   c("By countries" = 1,
                                     "By cities" = 2))
               ),
               column(6, 
                      column(4,infoBoxOutput("kpi_summary",width=400)),
                      column(4,infoBoxOutput("tweets_count",width=400)),
                      column(4,infoBoxOutput("users_count",width=400)))
             ),
             fluidRow(
               column(6,
                      leafletOutput("map", height = 820 ,  width =800)
               ),
               column(6,
                      fluidRow(
                        visNetworkOutput("network2", height = 500 , width =800)),
                      fluidRow(
                        column(12,
                          box(
                          title = "Cliques users", status = "primary", solidHeader = TRUE,
                          width=310,
                          height=310,
                          #plotlyOutput('pie',height='225'))
                          DT::dataTableOutput("users_table", height = 100))
                        )
                      )
                )
              )
            ))
  ),
 tabPanel("Users Analysis",
   fluidPage(useShinyjs(),
     fluidRow(
       column(3,fluidRow(infoBoxOutput("user_bio", width='100%')),
                fluidRow(box(width='100%',plotOutput('usercloud', height = 350 , width ='100%'))),
                fluidRow(box(width='100%',DT::dataTableOutput("mytable", height = 500 , width ='100%')))),
       column(6,fluidRow(box(width='100%', visNetworkOutput("user_network", height = 475 , width ='100%'), 
                             title = HTML('<center> User influencers neighborhood </center>'))),
                fluidRow(column(6, box(width='100%',plotlyOutput('user_days_use'))),
                         column(6, box(width='100%' ,plotlyOutput('tweets_time_serie', height = 500 , width ='100%'))))),
       column(3, 
                fluidRow(column(8, textInput("text", NULL,value = "Enter text...")),
                         column(4, actionButton("goButton", "Go!"))),
                fluidRow(selectInput("select_users_list", label = h3("Select users list"), 
                                     choices = list("Key players" = 1, 
                                                    "Best Tweeters" = 2, 
                                                    "Most followed" = 3,
                                                    "News, Journalists and Researchers" = 4,
                                                    "All users" = 5,
                                                    "Filtered users" = 6), 
                                     selected = 1)),
                fluidRow(box(width='100%', DT::dataTableOutput("users_lists", height = 400 , width ='100%'))),
                fluidRow(column(6, fluidRow(valueBoxOutput("seniority",  width=12)),
                                   fluidRow(valueBoxOutput("user_tweets_count", width=12)),
                                   fluidRow(valueBoxOutput("user_being_retweeted", width=12))),
                         column(6, fluidRow(valueBoxOutput("user_being_liked", width=12)),
                                   fluidRow(valueBoxOutput("user_type", width=12)),
                                   fluidRow(valueBoxOutput("media_precent", width=12))))

       )
     )
   )
 ),
tabPanel("Bot Analysis",
         fluidPage(
           fluidRow(
             column(3,fluidRow(box(width='100%',plotOutput('bot_cloud', height = 350 , width ='100%'))),
                      fluidRow(box(width='100%', DT::dataTableOutput("bot_tweets", height = 400 , width ='100%')))),
             column(6,
                      fluidRow(box(width='100%',plotlyOutput('bot_paterns'), height = 300)),
                      fluidRow(box(width='100%', height = 300 ,plotlyOutput('bot_freq', width ='100%'))),#),
                      fluidRow(box(width='100%', height = 280 , column(7, plotlyOutput('bot_hist', height = 200 , width ='100%')),
                                                                column(2, imageOutput("myImage",width=150)),
                                                                column(3, valueBoxOutput("bot_or_not",width='100%'))))),
             column(3,
                      fluidRow(box(width='100%', DT::dataTableOutput("bots_list", height = 400 , width ='100%'))),
                      fluidRow(column(6, valueBoxOutput("avg_mention",  width=12),
                                         valueBoxOutput("bot_seniority", width=12), #days
                                         valueBoxOutput("avg_freq", width=12)),
                               column(6, valueBoxOutput("duplicates_tweets_pct", width=12),
                                         valueBoxOutput("retweets_pct", width=12),
                                         valueBoxOutput("reply_precent", width=12))
                      )
           )
         )
        )
),
tabPanel("Retweets Analysis",
         fluidPage(
           column(3, fluidRow(infoBoxOutput("retweeted_text", width="100%")),
                     fluidRow(column(6, valueBoxOutput("dist_start", width="100%"),
                                        valueBoxOutput("retweets_count", width="100%")),
                              column(6, valueBoxOutput("dist_end", width="100%"),
                                        valueBoxOutput("retweet_freq", width="100%"))),
                     fluidRow(box(width='100%', DT::dataTableOutput("tweet_retweets", height = 400 , width ='100%')))
           ),
           column(6, box(title='First 100 retweets cliques distribution',
                         tags$p(style = "font-size: 10px;", 'Every bubble represents a retweet. The number inside the bubble represent the user clique number
                                 of the user retweeted to the orginal tweet. The clique number is also represented by a unique color
                                 for better visualization of the cliques. A bubble which is positioned closure to the center was made
                                 sooner to the original tweet. The size of the bubble also represent when was the retweet made, as
                                 the bigger the size of the bubble the sooner the retweet was made.'),
                         width='100%',
                         div(bubblesOutput('bubbles', height = 500), align = "center")
                       ),
                     fluidRow(box(width='100%', height=300, column(8, plotlyOutput('retweet_curve')),
                                                            column(4, plotlyOutput('retweets_box'))))),
           column(3, fluidRow(box(width='100%', DT::dataTableOutput("retweets_list", height = 400 , width ='100%'))),
                     fluidRow(box(width='100%', DT::dataTableOutput("top_being_retweeted", height = 400 , width ='100%'))))
         )),
theme = shinytheme("flatly"))
)