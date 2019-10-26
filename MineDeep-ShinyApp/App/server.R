library(shiny)
library(qgraph)
library(visNetwork)
library(magrittr)
library(igraph)
library(rgdal)
library(leaflet)
library(RMySQL)
library(plyr)
library(DT)
library(stringi)
library(plotly)
library(ggplot2)
library(wordcloud)
library(stringr)
library(botrnot)
library(bubbles)
library(shinyjs)

####################################### Map Data ######################################################
load("data/countries_shape.RData")
####################################### DB Con ########################################################
load("data/pass.RData")
DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host_address, port=3306)
################################# Local Data ##########################################################
load("data/workspace_data.RData")
load("data/twitter_token.RData")
################################### Lists #############################################################
load("data/graph.RData")
load("data/key_players.RData")
load("data/top_retweets.RData")
##################################### SQL Data ########################################################
BDS_id <- '46678624'
rs = dbSendQuery(DW, paste0("select *
                             from DW_BDS.fact_users
                             where user_id=",BDS_id))
bds_data <- fetch(rs, n=-1)
#-------------------Best tweeters------------------------------------------
rs = dbSendQuery(DW, "select user_id, screen_name, tweets_average, cluster_number
                 from DW_BDS.fact_users
                 order by tweets_average desc
                 limit 10000")
tweeters = fetch(rs, n=-1)
#-------------------Fix processed text to utf8-----------------------------
most_retweeted$processed_text <- stri_encode(most_retweeted$processed_text, "", "UTF-8")
# ------------------most followed------------------------------------------
rs = dbSendQuery(DW, "select user_id, screen_name, followers_count, cluster_number
                      from DW_BDS.fact_users 
                      where followers_count>200000
                      order by followers_count desc;")
most_followed = fetch(rs, n=-1)
# ------------------VIPS---------------------------------------------------
rs = dbSendQuery(DW, 'SELECT user_id, screen_name,
                      CASE
                      WHEN description LIKE "%news%" THEN "News"
                      WHEN description LIKE "%journalist%" THEN "Journalist"
                      WHEN description LIKE "%anchor%" THEN "Anchor"
                      WHEN description LIKE "%research%" THEN "Researcher"
                      WHEN description LIKE "%author%" THEN "Author"
                      WHEN description LIKE "%reporter%" THEN "Reporter"
                      END as vip_type, cluster_number
                      from DW_BDS.fact_users 
                      where description LIKE "%news%" 
                      or
                      description LIKE "%journalist%"
                      or
                      description LIKE "%anchor%"
                      or
                      description LIKE "%research%"
                      or
                      description LIKE "%author%"
                      or
                      description LIKE "%reporter%"
                      and  
                      followers_count>10000
                      order by tweets_average desc;')
vips = fetch(rs, n=-1)




###############################################################################################
##################################### Server ##################################################
###############################################################################################
server <- shinyServer(function(input, output,session) {


##################################### World-wide Analysis #####################################
#-------------------------- KPI ---------------------------------------------------------------
  shinyjs::hide("text")
  shinyjs::hide("goButton")
  output$kpi_summary <- renderInfoBox({
    rs = dbSendQuery(DW, "select
                     (select count(*) from DW_BDS.fact_tweets where created_at>'2018-03-24')/
                     (select count(*)  from DW_BDS.fact_tweets where created_at <'2018-03-24' and created_at>='2018-03-17');"
    )
    kpi <- fetch(rs, n=-1)
    if(kpi-1>0){
      kpi_icon=icon("arrow-up")
    }
    else{
      kpi_icon = icon("arrow-down")
    }
    infoBox(
      title = HTML('<b> Tweets weekly <br/> rate </b>'),
      value = sprintf("%.1f%%", (kpi-1)*100),
      icon = kpi_icon,
      color = "purple",
      fill = T,
      width = 400
    )
  })
  
#-------------------------- User count box ----------------------------------------------------
  output$users_count <- renderInfoBox({
    rs <- dbSendQuery(DW,"select count(*)
                      from DW_BDS.fact_users;")
    users_count <- fetch(rs, n=-1)               
    infoBox(
      title = HTML('<b> Users </b>'),
      value = HTML(paste0('<br/>', users_count)),
      color = "green",
      fill = T,
      width = 300
    )
  })
  
#-------------------------- tweets count box --------------------------------------------------
  output$tweets_count <- renderInfoBox({
    rs <- dbSendQuery(DW,"select count(*)
                      from DW_BDS.fact_tweets;"
    )
    tweets_count <- fetch(rs, n=-1) 
    infoBox(
      title = HTML('<b> Tweets </b>'),
      value = HTML(paste0('<br/>', tweets_count)),
      color = "blue",
      fill = T,
      width = 300
    )
  })
  
#-------------------------- Clusters network --------------------------------------------------    
  output$network2 <- renderVisNetwork({
    data <- toVisNetworkData(g)
    visNetwork(nodes = data$nodes, edges = data$edges, height=300, width='100%')%>%
      visEdges(arrows =list(to = list(enabled = TRUE, scaleFactor = 1)),
               color = list(color = "lightblue", highlight = "red")) %>%
      visOptions(highlightNearest = TRUE)%>%
      visEvents(select = "function(nodes) {
                Shiny.onInputChange('current_node_id', nodes.nodes);
                ;}")%>%
      visPhysics(solver = "forceAtlas2Based",
                 forceAtlas2Based = list(gravitationalConstant = -500), stabilization = T, timestep = 0.2)
    
})
  
#-------------------------- World Map ---------------------------------------------------------
  output$map <- renderLeaflet({
    if(length(input$current_node_id)==0){
      cluster_to_show <- ' '
    }
    else{
      cluster_to_show <- paste0(' and cluster_number=', input$current_node_id)
    }
    if(input$map_id==1){
      rs = dbSendQuery(DW, paste0("SELECT country, country_code, count(*) as users_count 
                            FROM DW_BDS.fact_users
                            where country_code is not null ", cluster_to_show,
                            " group by country, country_code;"))
      locations_data = fetch(rs, n=-1)
      locations_data$country[locations_data$country=='Aland Islands'] <- "Åland"
      locations_data$country[locations_data$country=='Antigua and Barbuda'] <- "Antigua and Barb."
      locations_data$country[locations_data$country=='Bosnia and Herzegovina'] <- "Bosnia and Herz."
      locations_data$country[locations_data$country=='Cape Verde'] <- "Cabo Verde"
      locations_data$country[locations_data$country=='Central African Republic'] <- "Central African Rep."
      locations_data$country[locations_data$country=='Curacao'] <- "Curaçao"
      locations_data$country[locations_data$country=='Democratic Republic of the Congo'] <- "Dem. Rep. Congo"
      locations_data$country[locations_data$country=='Dominican Republic'] <- "Dominican Rep."
      locations_data$country[locations_data$country=='Equatorial Guinea'] <- "Eq. Guinea"
      locations_data$country[locations_data$country=='Falkland Islands'] <- "Falkland Is."
      locations_data$country[locations_data$country=='Marshall Islands'] <- "Marshall Is."
      locations_data$country[locations_data$country=='Palestinian Territory'] <- "Palestine"
      locations_data$country[locations_data$country=='Pitcairn'] <- "Pitcairn Is."
      locations_data$country[locations_data$country=='Solomon Islands'] <- "Solomon Is."
      locations_data$country[locations_data$country=='South Sudan'] <- "S. Sudan"
      locations_data$country[locations_data$country=='United States'] <- "United States of America"
      locations_data[,"NAME"] <- locations_data$country
      merged <- join(countries@data,locations_data, by="NAME")
      countries@data <- merged
      countries@data$users_count[is.na(countries@data$users_count)] <- 0
      
      quants <- c(0.1111111, 0.2222222, 0.3333333, 0.4444444, 0.5555556, 0.6666667, 0.7777778, 0.8888889, 1.0000000)
      quants_filtered <- c(0) 
      for(quant in quants){
        quant_val <- quantile(countries$users_count, quant)
        if(quant_val != 0){
          quants_filtered <- c(quants_filtered, quant) 
        }
      }
      
      pal <- colorQuantile(
        palette = "Reds",
        domain = unique(countries$users_count),
        probs = quants_filtered)
      
      m1 <- leaflet(countries, options = leafletOptions(minZoom = 1.8)) %>%
        addPolygons(stroke = FALSE, smoothFactor = 0.2, fillOpacity = 1,
                    color = ~pal(users_count), popup = ~paste("<h3 style='color:blue'>",countries$NAME,"</h3>","<b>","Users count: ",
                                                              "</b>", countries$users_count, sep= " "))%>%
        addLegend(position = "bottomright", pal = pal, values = ~users_count, title = 'Users count:',
                  labFormat = function(type, cuts, p) {
                    n = length(cuts)
                    paste0(as.integer(cuts[-n]), " &ndash; ", as.integer(cuts[-1]))
                  }
                  )
      m1
    }
    else if(input$map_id==2){
      rs = dbSendQuery(DW, paste0("SELECT longitude, latitude, count(*) as users_count, city_name
                             FROM DW_BDS.fact_users
                             where longitude is not null ", cluster_to_show,
                             " group by longitude, latitude, city_name;"))
      cities_data = fetch(rs, n=-1)
      
      
      m2 <- leaflet(cities_data[,1:3]) %>% 
        addTiles('http://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                                              attribution='Map tiles by <a href="http://stamen.com">Stamen Design</a>, <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a> &mdash; Map data &copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>') %>%
        setView(-81.655210, 30.324303, zoom = 2) %>%
        addCircles(lng = ~longitude,lat = ~latitude, weight = 3, radius=(cities_data$users_count)*10, color = 'yellow', 
                   popup = ~paste("<h3 style='color:blue'>",cities_data$city_name,"</h3>","<b>","Users count: ",
                                  "</b>", cities_data$users_count, sep= " "),
                   stroke = F, fillOpacity = 0.5)
      m2
    }
  })
#-------------------------- Users table  ---------------------------------------------------------  
  output$users_table <- DT::renderDataTable({
    if(length(input$current_node_id)==0){
      cluster_to_show <- ''
    }
    else{
      cluster_to_show <- paste0(' where u.cluster_number=', input$current_node_id)
    }
    get_tweets_statement <- paste0('select u.user_id, u.screen_name, u.followers_count,
                                   u.friends_count, u.status_count, user_being_liked, u.tweets_average, u.country, u.cluster_number
                                   from DW_BDS.fact_users as u', cluster_to_show, ';'
    )
    rs = dbSendQuery(DW, get_tweets_statement)
    cluster_users = fetch(rs, n=-1)
    cluster_users$screen_name <-  stri_encode(cluster_users$screen_name, "", "UTF-8")
    DT::datatable(cluster_users[,1:ncol(cluster_users)-1], 
                  options = list(paging=T, scrollY=115, scrollX="300px", sDom  = '<"top">frt<"bottom">ip'), 
                  height = 295,
                  colnames = c('User id', 'Screen name', 'Followers', 'Following', 'Tweets', 'Likes', 'Tweets average', 'Country'))
  })
  

############################## Users Analysis ###################################################
  
# ----------------------- User Network ----------------------------------------------------------
  output$user_network <- renderVisNetwork({
    id <- values$id
    if(is.null(id)){
      id <- BDS_id
    }
    temp_graph <- make_ego_graph(g1,1,id,'in')
    V(temp_graph[[1]])$size[V(temp_graph[[1]])$name==id] <- 40
    V(temp_graph[[1]])$size[V(temp_graph[[1]])$name!=id] <- 20
    V(temp_graph[[1]])$color[V(temp_graph[[1]])$name==id] <- 'tomato'
    visIgraph(temp_graph[[1]])%>%
      visEdges(arrows =list(to = list(enabled = TRUE, scaleFactor = 1)),
               color = list(color = "lightblue", highlight = "red")) %>%
      visNodes(size=10)%>%
      visIgraphLayout("layout_with_fr")
    
  })
  
# ----------------------- User Daily use -------------------------------------------------------
  output$user_days_use <- renderPlotly({
    id <- values$id
    if(is.null(id)){
      id <- BDS_id
      text <- NULL
    }
    else{
      text <- c('tweets for day')
    }
    rs = dbSendQuery(DW, paste0("select created_at
                                from DW_BDS.fact_tweets
                                where user_id=", id))
    user_tweets = fetch(rs, n=-1)
    filt <- as.vector(values$filter)
    if(is.null(id)){
      filt <- NULL
    }else if(is.null(filt)){
      filt <- NULL
    }
    Sys.setlocale("LC_TIME", "C")
    user_days_use <- user_tweets[filt,]
    user_days_use$created_at <- weekdays(as.Date(user_days_use))
    user_days_use <- count(user_days_use, 'created_at')
    colnames(user_days_use) <- c('dayN', 'count')
    
    if(nrow(user_days_use)==0){
      text <- NULL
    }
    user_days_use$dayN <- factor(user_days_use$dayN, levels= c("Sunday", "Monday", 
                                                               "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))
    user_days_use[order(user_days_use$dayN), ]
    x <- user_days_use$dayN
    y <- user_days_use$count
    
    p <- plot_ly(x = x, y = y, type = 'bar', text = text,
                 marker = list(color = 'rgb(158,202,225)',
                               line = list(color = 'rgb(8,48,107)',
                                           width = 1.5,
                                           height=180)),
                 height=330) %>%
      layout(title = 'Week days use',
             xaxis = list(title = ""),
             yaxis = list(title = ""))
    p
  })
  
# ----------------------- User Time series -----------------------------------------------------  
  output$tweets_time_serie <- renderPlotly({
    id <- values$id
    if(is.null(id)){
      id <- BDS_id
    }

    rs = dbSendQuery(DW, paste0("select date(created_at) as created_at, tweet_type
                                from DW_BDS.fact_tweets
                                where user_id=", id))
    tweets <- fetch(rs, n=-1)
    filt <- as.vector(values$filter)
    if(is.null(id)){
      filt <- NULL
    }else if(length(filt)==0){
      filt <- NULL
    }
    tweets_dates <- tweets[filt,]
    tweets_dates <- count(tweets_dates, c('created_at', 'tweet_type'))
    tweets_dates$created_at <- as.Date(tweets_dates$created_at)
    colnames(tweets_dates) <- c('created_at', 'tweet_type', 'tweets_count')
    regular_tweets <- tweets_dates[tweets_dates$tweet_type=='tweet',]
    reply_tweets <- tweets_dates[tweets_dates$tweet_type=='reply',]
    retweet_tweets <- tweets_dates[tweets_dates$tweet_type=='retweet',]
    min_date <- as.Date('2018-03-01')
    max_date <- as.Date('2018-03-31')
    full_dates <- seq(min_date, max_date, by = "1 day")
    full_dates <- data.frame(created_at = full_dates)
    regular_tweets_complete <- merge(full_dates, regular_tweets, by = "created_at", 
                                     all.x = TRUE)
    replies_complete <- merge(full_dates, reply_tweets, by = "created_at", 
                              all.x = TRUE)
    retweets_complete <- merge(full_dates, retweet_tweets, by = "created_at", 
                               all.x = TRUE)
    regular_tweets_complete$tweets_count[is.na(regular_tweets_complete$tweets_count)] <- 0 
    replies_complete$tweets_count[is.na(replies_complete$tweets_count)] <- 0 
    retweets_complete$tweets_count[is.na(retweets_complete$tweets_count)] <- 0 
  
    p <- plot_ly(x=regular_tweets_complete$created_at, y=regular_tweets_complete$tweets_count, type = 'scatter', mode = 'lines', name = 'Tweets', fill = 'tozeroy',
                 height = 350) %>%
      add_trace(x=replies_complete$created_at, y=replies_complete$tweets_count, name = 'Replies', fill = 'tozeroy') %>%
      add_trace(x=retweets_complete$created_at, y=retweets_complete$tweets_count, name = 'Retweets', fill = 'tozeroy')%>%
      layout(title = 'Daily use',
             yaxis = list(title = 'Tweets'))%>%
      layout(legend = list(orientation = 'h'))
    p
    
  })
  
# ----------------------- User Tweets Table ----------------------------------------------------
  output$mytable <- DT::renderDataTable({
    id <- values$id
    if(is.null(id)){
      id <- BDS_id
    }
    get_tweets_statement <- paste0('select created_at, full_text, tweet_type
                                   from DW_BDS.fact_tweets
                                   where user_id=', id
    )
    rs = dbSendQuery(DW, get_tweets_statement)
    tweets <- fetch(rs, n=-1)
    tweets$full_text <- stri_encode(tweets$full_text, "", "UTF-8")
    table <- DT::datatable(tweets,
                           options = list(paging=F,
                                          scrollY="300px",
                                          columnDefs = list(list(visible=FALSE, targets=c(0)))),
                           colnames = c('Date - Time', 'Tweet Text', 'Tweet Type'))
    table
  })
# ----------------------- Users lists Table ---------------------------------------------------
  output$users_lists <- DT::renderDataTable({
    if(input$select_users_list==1){ 
        players$betweenes <- ceiling(players$betweenes)
        if(length(input$current_node_id)==0){
          cond <- 1:nrow(players)
        }
        else{
          cond <- players$cluster_number==input$current_node_id
        }
        table <- DT::datatable(players[cond,], 
                               options = list(paging=T, 
                                              scrollX="100%",
                                              sDom  = '<"top">frt<"bottom">ip',
                                              scrollY="250px",
                                              columnDefs = list(list(visible=FALSE, targets=c(0,1,3)),
                                                                list(className = 'dt-center', targets = c(2,4)))),
                               colnames = c('ID', 'Screen name', 'cluster', 'Ranking score'),
                               rownames = T,
                               height = 300,
                               selection = list(mode='single'))
    }else if(input$select_users_list==2){
      if(length(input$current_node_id)==0){
        cond <- 1:nrow(tweeters)
      }
      else{
        cond <- tweeters$cluster_number==input$current_node_id
      }
      table <- DT::datatable(tweeters[cond,],
                             options = list(paging=T,
                                            scrollX="100%",
                                            scrollY="250px",
                                            sDom  = '<"top">frt<"bottom">ip',
                                            columnDefs = list(list(visible=FALSE, targets=c(0,1,4)),
                                                              list(className = 'dt-center', targets = c(2,3)))),
                             colnames = c('ID', 'Screen name', 'Daily Tweets count', 'cluster'),
                             rownames = T,
                             height = 300,
                             selection = list(mode='single'))
    }else if(input$select_users_list==3){
      if(length(input$current_node_id)==0){
        cond <- 1:nrow(most_followed)
      }
      else{
        cond <- most_followed$cluster_number==input$current_node_id
      }
      table <- DT::datatable(most_followed[cond,],
                             options = list(paging=T,
                                            scrollX="100%",
                                            scrollY="250px",
                                            sDom  = '<"top">frt<"bottom">ip',
                                            columnDefs = list(list(visible=FALSE, targets=c(0,1,4)),
                                                              list(className = 'dt-center', targets = c(2,3)))),
                             colnames = c('ID', 'Screen_name', 'Followers count', 'Cluster number'),
                             rownames = T,
                             height = 300,
                             selection = list(mode='single'))
    }else if(input$select_users_list==4){
      if(length(input$current_node_id)==0){
        cond <- 1:nrow(vips)
      }
      else{
        cond <- vips$cluster_number==input$current_node_id
      }
      table <- DT::datatable(vips[cond,],
                             options = list(paging=T,
                                            scrollX="100%",
                                            scrollY="250px",
                                            sDom  = '<"top">frt<"bottom">ip',
                                            columnDefs = list(list(visible=FALSE, targets=c(0,1,4)),
                                                              list(className = 'dt-center', targets = c(2,3)))),
                             colnames = c('ID', 'Screen_name', 'VIP type', 'cluster'),
                             rownames = T,
                             height = 300,
                             selection = list(mode='single'))
    }else if(input$select_users_list==5){
      rs = dbSendQuery(DW, "select user_id, screen_name, cluster_number
                            from DW_BDS.fact_users 
                      ") # where user_type is not null
      all_users = fetch(rs, n=-1)
      if(length(input$current_node_id)==0){
        cond <- 1:nrow(all_users)
      }
      else{
        cond <- all_users$cluster_number==input$current_node_id
      }
      table <- DT::datatable(all_users[cond,],
                             options = list(paging=T,
                                            scrollX="100%",
                                            scrollY="250px",
                                            sDom  = '<"top">frt<"bottom">ip',
                                            columnDefs = list(list(visible=FALSE, targets=c(0,3)),
                                                              list(className = 'dt-center', targets = c(1,2)))),
                             colnames = c('User ID', 'Screen name', 'cluster'),
                             rownames = T,
                             height = 300,
                             selection = list(mode='single'))
    }else if(input$select_users_list==6){
      if(is.null(values$filter_users)){
        searched <- '@@@@%&*$%##fd'
      }else{
        searched <- values$filter_users
      }
      rs = dbSendQuery(DW, paste0("SELECT user_id, screen_name, count(*) as cnt, cluster_number
                                   FROM DW_BDS.fact_tweets
                                   where processed_text LIKE '%", searched, "%'
                                   group by user_id, screen_name, cluster_number
                                   order by cnt desc;")) # where user_type is not null
      filtered_users = fetch(rs, n=-1)
      if(length(input$current_node_id)==0){
        cond <- 1:nrow(filtered_users)
      }
      else{
        cond <- filtered_users$cluster_number==input$current_node_id
      }
      table <- DT::datatable(filtered_users[cond,],
                             options = list(paging=T,
                                            scrollX="100%",
                                            scrollY="250px",
                                            sDom  = '<"top">frt<"bottom">ip',
                                            columnDefs = list(list(visible=FALSE, targets=c(0,1,4)),
                                                              list(className = 'dt-center', targets = c(2,3)))),
                             colnames = c('ID', 'Screen name', 'Match count', 'cluster'),
                             rownames = T,
                             height = 300,
                             selection = list(mode='single'))
    }
    table
  })
  

  
#-------------------------Reactive-------------------------------------------------------------
  values <- reactiveValues()
  
  filter_tweets <- observeEvent({input$goButton},
    {
      values$filter_users <- input$text
    }
  )
  
  
  filter_tweets <- observeEvent(
    {
     c(input$mytable_search,
     input$mytable_rows_all)
    },
    {
    values$filter <- input$mytable_rows_all
    }
  )
  
  observe({
      if(input$select_users_list==6){
        shinyjs::show("text")
        shinyjs::show("goButton")
      }else{
        shinyjs::hide("text")
        shinyjs::hide("goButton")
      }
  })
  
  get_user_data <- observeEvent(input$users_lists_rows_selected, {
    row <- input$users_lists_rows_selected
    if (input$select_users_list==1) {
      if(length(input$current_node_id)==0){
        temp_players <- players
      }
      else{
        temp_players <- players[players$cluster_number==input$current_node_id,]
        rownames(temp_players) <- 1:nrow(temp_players)
      }
      id <- temp_players[row, 'user_id']
    }else if(input$select_users_list==2){
      if(length(input$current_node_id)==0){
        temp_tweeters <- tweeters
      }
      else{
        temp_tweeters <- tweeters[tweeters$cluster_number==input$current_node_id,]
        rownames(temp_tweeters) <- 1:nrow(temp_tweeters)
      }
      id <- temp_tweeters[row, 'user_id']
    }else if(input$select_users_list==3){
      if(length(input$current_node_id)==0){
        temp_most_followed <- most_followed
      }
      else{
        temp_most_followed <- most_followed[most_followed$cluster_number==input$current_node_id,]
        rownames(temp_most_followed) <- 1:nrow(temp_most_followed)
      }
      id <- temp_most_followed[row, 'user_id']
    }else if(input$select_users_list==4){
      if(length(input$current_node_id)==0){
        temp_vips <- vips
      }
      else{
        temp_vips <- vips[vips$cluster_number==input$current_node_id,]
        rownames(temp_vips) <- 1:nrow(temp_vips)
      }
      id <- temp_vips[row, 'user_id']
    }else if(input$select_users_list==5){
      if(length(input$current_node_id)==0){
        rs <-  dbSendQuery(DW, paste0("SELECT user_id, cluster_number FROM DW_BDS.fact_users LIMIT ",
                                      row-1, ",1")) # where user_type is not null
        user  <- fetch(rs, n=-1)
      }
      else{
        rs <-  dbSendQuery(DW, paste0("SELECT user_id FROM DW_BDS.fact_users 
                                       where cluster_number=", input$current_node_id, 
                                       " LIMIT ", row-1, ",1")) # where user_type is not null
        user  <- fetch(rs, n=-1)
      }
      id <- user$user_id
    }else if(input$select_users_list==6){
      searched <- values$filter_users
      rs <-  dbSendQuery(DW, paste0("SELECT user_id, screen_name, count(*) as cnt
                                     FROM DW_BDS.fact_tweets
                                     where processed_text LIKE '%", searched, "%'
                                     group by user_id, screen_name
                                     order by cnt desc 
                                     LIMIT ", row-1, ",1")) # where user_type is not null
      user  <- fetch(rs, n=-1)
      if(length(input$current_node_id)==0){
        rs <-  dbSendQuery(DW, paste0("SELECT user_id, screen_name, count(*) as cnt
                                     FROM DW_BDS.fact_tweets
                                     where processed_text LIKE '%", searched, "%'
                                     group by user_id, screen_name
                                     order by cnt desc 
                                     LIMIT ", row-1, ",1")) # where user_type is not null
        user  <- fetch(rs, n=-1)
      }
      else{
        rs <-  dbSendQuery(DW, paste0("SELECT user_id, screen_name, count(*) as cnt
                                     FROM DW_BDS.fact_tweets
                                     where (processed_text LIKE '%", searched, "%'
                                           and cluster_number=", input$current_node_id,
                                     ") group by user_id, screen_name
                                     order by cnt desc 
                                     LIMIT ", row-1, ",1")) # where user_type is not null
        user  <- fetch(rs, n=-1)
      }
      id <- user$user_id
    }
    values$id <- id
    rs = dbSendQuery(DW, paste0("select *
                               from DW_BDS.fact_users
                               where user_id=", id))
    user_data <- fetch(rs, n=-1)
    values$data <- user_data
    # user_data
  },ignoreNULL = T)
    
# ----------------------- User Word cloud -----------------------------------------------------
  output$usercloud <- renderPlot({
    id <- values$id
    if(is.null(id)){
      id <- BDS_id
    }
    rs = dbSendQuery(DW, paste0("select processed_text
                                from DW_BDS.fact_tweets as tweets
                                where user_id=", id))
    tweets = fetch(rs, n=-1)
    if(nrow(tweets)>0){
      tweets$processed_text <-  stri_encode(tweets$processed_text, "", "UTF-8")
      hashtags=str_extract_all(tweets$processed_text, "#\\w+|\\w+")
      hashtags=unlist(hashtags)
      hashtags_freq = table(hashtags)
      par(mar = rep(0, 4))
      wordcloud(names(hashtags_freq), hashtags_freq, scale=c(4,0.5), max.words = 100,random.order=FALSE,rot.per=.15,colors=brewer.pal(8, "Dark2"))
    }else{
      wordcloud(c('User has no tweets'),1, scale=c(2,0.5), min.freq = 1, max.words = 100,random.order=FALSE,rot.per=0,colors=brewer.pal(8, "Dark2"))
    }
  })
# ----------------------- Value boxes -----------------------------------------------------
  # -------------Membership time-------------
  output$seniority <- renderValueBox({
    if(is.null(values$data$seniority)){
      user_data <- bds_data$seniority
    }else{
      user_data <- values$data$seniority
    }
    valueBox(
      subtitle =  HTML('<b> Membership (Years) </b>'),
      value =sprintf("%.1f", user_data)
    )
  })
  
  # -------------Tweets count---------------------
  output$user_tweets_count <- renderValueBox({
    if(is.null(values$data$tweets_count)){
      user_data <- bds_data$tweets_count
    }else{
      user_data <- values$data$tweets_count
    }
    valueBox(
      subtitle =HTML('<b> Tweets </b>') ,
      value = user_data
    )
  })
  
  # -------------Count being retweeted-------------
  output$user_being_retweeted <- renderValueBox({
    if(is.null(values$data$user_being_retweeted)){
      user_data <- bds_data$user_being_retweeted
    }else{
      user_data <- values$data$user_being_retweeted
    }
    valueBox(
      subtitle = HTML('<b> Being retweeted </b>'),
      value = user_data
    )
  })
  
  # -------------Count being liked----------------
  output$user_being_liked <- renderValueBox({
    if(is.null(values$data$user_being_liked)){
      user_data <- bds_data$user_being_liked
    }else{
      user_data <- values$data$user_being_liked
    }
    valueBox(
      subtitle = HTML('<b> Being liked </b>'),
      value =  user_data
    )
  })
  
  # -------------User Type-------------
  output$user_type <- renderValueBox({
    if(is.null(values$data$user_type)){
      user_data <- bds_data$user_type
    }else{
      if(is.na(values$data$user_type)){
        user_data <- HTML(paste0('Unprocessed <br/> yet'))
      }else{
        user_data <- values$data$user_type
      }
    }
    sub <- HTML('<b> User type </b>')
    if(is.null(values$data$user_type)){
      user_data <- bds_data$user_type
    }
    if(user_data=='pro - advanced active'){
      user_data <- HTML('pro - advanced <br/> active')
    }else if(user_data=='pro - active' | user_data=='pro - unactive' | user_data=='other'){
      sub <- HTML('<b> <br/> User type </b>')
    }
    valueBox(
      subtitle = sub,
      value = tags$p(style = "font-size: 20px;", user_data)
    )
  })
  
  # -------------Media precent use-------------
  output$media_precent <- renderValueBox({
    if(is.null(values$data$media_precent)){
      user_data <- bds_data$media_precent
    }else{
      user_data <- values$data$media_precent
    }
    valueBox(
      subtitle = HTML('<b> Media %</b>'),
      value = sprintf("%.1f%%", (user_data)*100),
      width = 300
    )
  })
  
  # -------------User description text-------------
  output$user_bio <- renderInfoBox({
    if(is.null(values$id)){
      id <- bds_data$user_id
      screen_name <- bds_data$screen_name
      bio <- bds_data$description
    }else{
      id <- values$data$user_id
      screen_name <- values$data$screen_name
      bio <- values$data$description
    }
    infoBox(
      title = paste0(screen_name, " - ", id),
      value = tags$p(style = "font-size: 10px;", bio),
      color = "green",
      icon = icon('user'),
      fill = T,
      width = 300
    )
  })
  
##################################### Bot Analysis ################################################

# ----------------------------------- Mentions wordcloud ------------------------------------------
  output$bot_cloud <- renderPlot({
    id <- get_bot_data()$user_id
    rs = dbSendQuery(DW, paste0("select processed_text
                                from DW_BDS.fact_tweets as tweets
                                where user_id=", id))
    tweets = fetch(rs, n=-1)
    if(nrow(tweets)>0){
      tweets$processed_text <-  stri_encode(tweets$processed_text, "", "UTF-8")
      hashtags=str_extract_all(tweets$processed_text, "@\\w+")
      hashtags=unlist(hashtags)
      hashtags_freq = table(hashtags)
      par(mar = rep(0, 4))
      wordcloud(names(hashtags_freq), hashtags_freq, scale=c(2,0.5), max.words = 100,random.order=FALSE,rot.per=.15,colors=brewer.pal(8, "Dark2"))
    }else{
      wordcloud(c("User didn't mention other users"),1, scale=c(2,0.5), min.freq = 1, max.words = 100,random.order=FALSE,rot.per=0,colors=brewer.pal(8, "Dark2"))
    }
  })

# ----------------------------------- Tweets table -------------------------------------------------    
  output$bot_tweets <- DT::renderDataTable({
    tweets <- get_bot_tweets()
    tweets$processed_text <- NULL
    tweets$full_text <- stri_encode(tweets$full_text, "", "UTF-8")
    table <- DT::datatable(tweets,
                           options = list(paging=F,
                                          scrollY="375px",
                                          columnDefs = list(list(visible=FALSE, targets=c(0)))),
                           colnames = c('Date - Time', 'Tweet Text', 'Tweet Type'))
    table
  })
# ----------------------------------- Bot paterns plot ----------------------------------------------
  output$bot_paterns <- renderPlotly({
    tweets_dates <- get_bot_dates()
    sum_dates <- unique.data.frame(tweets_dates[, c('date', 'tweet_count')])
    sum_dates$cumsum <- cumsum(sum_dates$tweet_count)
    events <- tweets_dates[, c('Tday', 'Thour')] 
    ay <- list(
      dtick = 50,
      tickfont = list(color = "red"),
      overlaying = "y",
      side = "right",
      title = "Daily tweets count"
    )
    plot_ly(x=format(as.Date(events$Tday), "%d-%m"), y=events$Thour,name = 'Tweets', type='scatter', marker = list(size = 5),
            height = 350)%>%
      add_lines(x = format(as.Date(sum_dates$date), "%d-%m"), y =sum_dates$tweet_count, name = "Daily tweets count", yaxis = "y2") %>%
      layout(title='Tweets Pattern',
             legend = list(
                           xanchor= "center",
                           y= -0.6,
                           x= 1),margin = list(l = 80, r = 80, b = 150),
             xaxis = list(tickangle=45, title="Days of March 2018"), yaxis = list(title="Tweets Hours"), yaxis2 =ay)
  })

# ----------------------------------- Bot frequency plot -----------------------------------------
  output$bot_freq <- renderPlotly({
    tweets_dates = get_bot_dates()
    tweets_dates$t_back <- c(0,tweets_dates$created_at[1:nrow(tweets_dates)-1])
    tweets_dates$intervals <- c(0,difftime(tweets_dates$created_at[2:nrow(tweets_dates)] ,tweets_dates$t_back[2:nrow(tweets_dates)], units = 'mins'))
    tweets_dates$intervals[as.Date(tweets_dates$t_back, format="%Y-%m-%d")!=as.Date(tweets_dates$created_at)] <- 0 
    tweets_dates <- tweets_dates[,c('created_at', 'intervals')]
    tweets_dates$index <- 1:nrow(tweets_dates)
    cond <- tweets_dates$intervals<100
    temp <- tweets_dates[cond,]
    temp$index <- 1:nrow(temp)
    plot_ly(x=temp$index, y=temp$intervals,name = 'Tweets',  mode='lines', type='scatter',
            height = 250)%>%
      layout(title='Tweets Frequency (Mins)',
             xaxis = list(title="Tweet index"), 
             yaxis = list(title="Time interval"))
  })

# ----------------------------------- Bot intervals histogram plot --------------------------------
  output$bot_hist <- renderPlotly({
    tweets_dates = get_bot_dates()
    tweets_dates$t_back <- c(0,tweets_dates$created_at[1:nrow(tweets_dates)-1])
    tweets_dates$intervals <- c(0,difftime(tweets_dates$created_at[2:nrow(tweets_dates)] ,tweets_dates$t_back[2:nrow(tweets_dates)], units = 'mins'))
    tweets_dates$intervals[as.Date(tweets_dates$t_back, format="%Y-%m-%d")!=as.Date(tweets_dates$created_at)] <- 0 
    tweets_dates <- tweets_dates[,c('created_at', 'intervals')]
    detach("package:RMySQL", unload=TRUE)
    library(sqldf)
    bar <- sqldf('select intervals, count(created_at) as cnt
              from tweets_dates
              group by intervals')
    library(RMySQL)
    bar_t <- bar[bar$cnt>1 & bar$intervals>0,]
    bar_t$intervals <- factor(bar_t$intervals)   
    plot_ly(x=bar_t$intervals, y=bar_t$cnt,name = 'Tweets', type='bar',
            height = 280, width = 500,
            marker=list(color=ifelse(bar_t$cnt>4,'rgba(222,45,38,0.8)','blue')))%>%
      layout(title='Tweets intervals count (Mins)',
             yaxis = list(title="Interval count"))
  })

# ----------------------------------- Bot list table ----------------------------------------------
  output$bots_list <- DT::renderDataTable({
    if(length(input$current_node_id)==0){
      cond <- 1:nrow(tweeters)
    }
    else{
      cond <- tweeters$cluster_number==input$current_node_id
    }
    table <- DT::datatable(tweeters[tweeters$tweets_average>=24 & cond,],
                           options = list(paging=T,
                                          scrollX="100%",
                                          scrollY="250px",
                                          sDom  = '<"top">frt<"bottom">ip',
                                          columnDefs = list(list(visible=FALSE, targets=c(0, 1, 4)),
                                                            list(className = 'dt-center', targets = c(2,3)))),
                           colnames = c('ID', 'Screen name', 'Daily Tweets count', 'cluster'),
                           rownames = T,
                           height = 400,
                           selection = list(mode='single', selected=c(1)))
    table
  })

# ----------------------- Value boxes -------------------------------------------------------------
  
  # -------------Membership time (Days)-------------
  output$bot_seniority <- renderValueBox({
    valueBox(
      subtitle = HTML('<b>  <br/> Membership (Days) </b>'), 
      value = round(get_bot_data()$seniority*365)
    )
  })
  
  # -------------Replies precent of tweets----------
  output$reply_precent <- renderValueBox({
    valueBox(
      subtitle = HTML('<b> Replies <br/> precent </b>'),
      value = sprintf("%.1f%%", (get_bot_data()$replies_precent)*100)
    )
  })
  
  # -------------Retweets precent of tweets-------------
  output$retweets_pct <- renderValueBox({
    valueBox(
      subtitle = HTML('<b> <br/> Retweets precent </b>'),
      value = sprintf("%.1f%%", (get_bot_data()$retweets_precent)*100)
    )
  })
  
  # --------Duplicated tweets precent of tweets----------
  output$duplicates_tweets_pct <- renderValueBox({
    tweets <- get_bot_tweets()
    duplicated <- 1- (length(unique(tweets$processed_text))/nrow(tweets))
    valueBox(
      subtitle = HTML('<b> <br/> Tweets duplicated </b>'),
      value =  sprintf("%.1f%%", duplicated*100)
    )
  })
  
  # -------------average time interval between tweets (mins)-------------
  output$avg_freq <- renderValueBox({
    tweets_dates = get_bot_dates()
    tweets_dates$t_back <- c(0,tweets_dates$created_at[1:nrow(tweets_dates)-1])
    tweets_dates$intervals <- c(0,difftime(tweets_dates$created_at[2:nrow(tweets_dates)] ,tweets_dates$t_back[2:nrow(tweets_dates)], units = 'mins'))
    tweets_dates <- tweets_dates[tweets_dates$intervals<100, ]
    valueBox(
      subtitle = HTML('<b> Tweets frequency (Min.) </b>'),
      value = sprintf("%.1f", mean(tweets_dates$intervals))
    )
  })
  
  # -------------Retweets precent of tweets-------------
  output$avg_mention <- renderValueBox({
    tweets <- get_bot_tweets()
    text <- paste0(tweets$processed_text)
    mentions <- str_extract_all(tweets$processed_text, "@\\w+")
    mentions <- unlist(mentions)
    valueBox(
      subtitle = HTML('<b> Average Mentions in tweet</b>'),
      value = sprintf("%.1f", (length(mentions)/nrow(tweets)))
    )
  })
  
#-------------------------Reactive-------------------------------------------------------------
  get_bot_data <- eventReactive(input$bots_list_rows_selected, {
    row <- input$bots_list_rows_selected
    if(length(input$current_node_id)==0){
      temp_tweeters <- tweeters
    }
    else{
      temp_tweeters <- tweeters[tweeters$tweets_average>=24 & tweeters$cluster_number==input$current_node_id,]
      rownames(temp_tweeters) <- 1:nrow(temp_tweeters)
    }
    id <-  temp_tweeters[row, 'user_id']
    rs = dbSendQuery(DW, paste0("select *
                               from DW_BDS.fact_users
                               where user_id=",id))
    user_data <- fetch(rs, n=-1)
    user_data
  })
  
  get_bot_dates <- eventReactive(input$bots_list_rows_selected, {
    row <- input$bots_list_rows_selected
    if(length(input$current_node_id)==0){
      temp_tweeters <- tweeters
    }
    else{
      temp_tweeters <- tweeters[tweeters$tweets_average>=24 & tweeters$cluster_number==input$current_node_id,]
      rownames(temp_tweeters) <- 1:nrow(temp_tweeters)
    }
    id = temp_tweeters[row, 'user_id']
    sentence <- paste0("select * from
                        (select date(tweets.created_at) as Tday, time(tweets.created_at) as Thour, user_id, created_at
                        from fact_tweets as tweets
                        where user_id=", id, ")
                         AS DT 
                         join (select count(tweets.tweet_id) as tweet_count, date(created_at) as date
                         from fact_tweets as tweets
                         where user_id=", id,"
                         group by  date(tweets.created_at), user_id)
                         as CT on DT.Tday= CT.date")
    rs = dbSendQuery(DW, sentence)
    tweets_dates = fetch(rs, n=-1)
    tweets_dates
  })
  
  get_bot_tweets <- eventReactive(input$bots_list_rows_selected, {
    row <- input$bots_list_rows_selected
    if(length(input$current_node_id)==0){
      temp_tweeters <- tweeters
    }
    else{
      temp_tweeters <- tweeters[tweeters$tweets_average>=24 & tweeters$cluster_number==input$current_node_id,]
      rownames(temp_tweeters) <- 1:nrow(temp_tweeters)
    }
    id = temp_tweeters[row, 'user_id']
    get_tweets_statement <- paste0('select created_at, full_text, processed_text, tweet_type
                                   from DW_BDS.fact_tweets
                                   where user_id=', id
    )
    rs = dbSendQuery(DW, get_tweets_statement)
    tweets <- fetch(rs, n=-1)
    tweets
  })
  
#-------------------------Bot or not-------------------------------------------------------------
  # -------------Decision value box-------------
  output$bot_or_not <- renderValueBox({
    prob <- botornot(get_bot_data()$screen_name)$prob_bot
    if(prob>0.5){
      prob_print <- sprintf("%.1f%%", prob*100)
      decision <- HTML(paste0('User is <br/> a Bot <br/> with <br/> ', prob_print))
    }else{
      prob_print <- sprintf("%.1f%%", (100-(prob*100)))
      decision <- HTML(paste0('User is <br/> not a  <br/> Bot with <br/> ', prob_print))
    }
    valueBox( 
      subtitle = HTML('<br/> Bot or Not©') ,
      value = decision,
      color = "blue",
      width = 300
    )
  })
  
  # -------------Decision image---------------
  output$myImage <- renderImage({
    # A temp file to save the output.
    # This file will be removed later by renderImage
    prob <- botornot(get_bot_data()$screen_name)$prob_bot
    if(prob>0.5){
      filename <- 'bot.png'
    }else{
      filename <- 'human.png'
    }
    # Return a list containing the filename and alt text
    list(src = filename)
    }, deleteFile = FALSE)
  
########################################Retweet Analysis##########################################

#------------------------- Bubble plot of retweet being spread -----------------------------------
  output$bubbles <- renderBubbles({
    retweets <- get_retweet_data()
    retweets$intervals <- difftime(max(retweets$created_at), retweets$created_at, units = 'hours')
    
    bubbles_data <- retweets[1:100,]
    bubbles_data$index <- nrow(bubbles_data):1
    bubbles_data$index[2:100] <- bubbles_data$index[2:100]**3
    bubbles_data$index[1] <- bubbles_data$index[1]**3.1
    colors <- as.data.frame(unique(bubbles_data$cluster_number))
    colors$color_index <- 1:nrow(colors)
    colnames(colors) <- c('cluster_number', 'color_index') 
    bubbles_data <- join(bubbles_data, colors, by='cluster_number')
    bubbles(value = bubbles_data$index, label = bubbles_data$cluster_number, textColor = 'black', 
            color = rainbow(length(unique(bubbles_data$cluster_number)), alpha=NULL)[bubbles_data$color_index]
    )

  })

#------------------------- Most retweeted tweets ------------------------------------------------
  output$retweets_list <- DT::renderDataTable({
    table <- DT::datatable(most_retweeted,
                           options = list(paging=T,
                                          scrollY="270px",
                                          scrollX="100%",
                                          sDom  = '<"top">frt<"bottom">ip',
                                          columnDefs = list(list(visible=FALSE, targets=c(0,3)),
                                                            list(visible=TRUE, className = 'dt-center', targets = c(1,2)))),
                           colnames = c('Tweet id', 'Retweets count', 'text'),
                           rownames = T,
                           height = 400,
                           width = 400,
                           selection = list(mode='single', selected=c(1)))
    table
  })

#-------------------------Most being retweeted users---------------------------------------------
  output$top_being_retweeted <- DT::renderDataTable({
    rs = dbSendQuery(DW, 'select screen_name, user_being_retweeted
                        from DW_BDS.fact_users
                        where user_being_retweeted>=100
                        order by user_being_retweeted desc;')
    top_being_retweeted = fetch(rs, n=-1)
    table <- DT::datatable(top_being_retweeted,
                           options = list(paging=T,
                                          scrollX="100%",
                                          scrollY="250px",
                                          columnDefs = list(list(visible=FALSE, targets=c(0)),
                                                            list(className = 'dt-center', targets = c(1,2))),
                                          searchable = FALSE,
                                          sDom  = '<"top">rt<"bottom">ip'),
                           colnames = c('User', 'Being retweeted count'),
                           rownames = T,
                           height = 400,
                           selection = list(mode='disable'))
    table
  })
  
#------------------------- Tweet spread speed cureve ---------------------------------------------
  output$retweet_curve <- renderPlotly({
    retweeted_time <- get_retweet_data()
    retweeted_time$index <- 1:nrow(retweeted_time)
    
    L <- plot_ly(x = as.POSIXct(retweeted_time$created_at), y = retweeted_time$index, text = retweeted_time$screen_name, 
                 type = 'scatter', mode = 'lines', color = I('PINK'), height = 280)%>%
            layout(title='Retweet speed distribution curve',
                   yaxis = list(title = 'Cumulative count of retweets'),
                   xaxis = list(title = 'Retweets index'))
    L
  })

#------------------------- Tweet time interval between retweets box plot --------------------------
  output$retweets_box <- renderPlotly({
    retweets <- get_retweet_data()
    retweets$intervals <- c(0,difftime(retweets$created_at[2:nrow(retweets)], retweets$created_at[1:(nrow(retweets)-1)], units = 'secs'))
    
    
    plot_ly(y=~retweets$intervals[as.Date(retweets$created_at)==min(as.Date(retweets$created_at))], type='box', 
            name='First day', height = 280)%>%
      layout(title='First day time interval',
             yaxis = list(title = 'Time interval between retweets (Sec)'))
  })
  
  
#------------------------- Original tweet text -----------------------------------------------------
  output$retweeted_text <- renderInfoBox({
    id <- get_retweet_data()$retweeted_user_id[2]
    infoBox(
      title = paste0('Tweet text | user ID - ', id),
      value = HTML(get_retweet_data()$full_text[1]),
      icon = icon('comment'),
      width = 300
    )
  })
  
# ----------------------- Value boxes -------------------------------------------------------------
  
  # -------------Average interval time between retweets---------------
  output$retweet_freq <- renderValueBox({
    retweets <- get_retweet_data()
    retweets$intervals <- c(0,difftime(retweets$created_at[2:nrow(retweets)], retweets$created_at[1:(nrow(retweets)-1)], units = 'secs'))
    avg <- mean(retweets$intervals[as.Date(retweets$created_at)==min(as.Date(retweets$created_at))])
    valueBox(
      subtitle = HTML('<b> First day distribution frequency (Sec)</b>'),
      value = sprintf("%.1f",avg)
    )
  })
  
  # -------------Tweet count of retweets---------------
  output$retweets_count <- renderValueBox({
    retweets <- get_retweet_data()
    rts <- retweets$retweets_count[nrow(retweets)]
    valueBox(
      subtitle = HTML('<b> <br/> Original tweet retweets count</b>'),
      value = rts,
      width = 300
    )
  })
  
  # -------------Last tweet date-time---------------
  output$dist_end <- renderValueBox({
    retweets <- get_retweet_data()
    end <- unlist(strsplit(max(retweets$created_at), ' '))
    end_time <- end[2]
    end_date <- end[1]
    valueBox(
      subtitle = HTML('<b> Last retweet </b>'),
      value = tags$p(style = "font-size: 28px;", HTML(paste0(end_date, '<br/>', end_time))),
      width = 300
    )
  })
  
  # -------------start tweet date-time---------------
  output$dist_start <- renderValueBox({
    retweets <- get_retweet_data()
    start <- unlist(strsplit(min(retweets$created_at), ' '))
    start_time <- start[2]
    start_date <- start[1]
    valueBox(
      subtitle = HTML('<b> First retweet </b>'),
      value = tags$p(style = "font-size: 28px;", HTML(paste0(start_date, '<br/>', start_time))),
      width = 300
    )
  })
  
  # -------------All known retweets data---------------
  output$tweet_retweets <- DT::renderDataTable({
    retweets <- get_retweet_data()[,c('cluster_number', 'screen_name', 'created_at')]
    table <- DT::datatable(retweets,
                           options = list(paging=F,
                                          scrollY="270px",
                                          columnDefs = list(list(visible=FALSE, targets=c(0)),
                                                            list(visible=TRUE, className = 'dt-center', targets = c(1,2,3)))),
                           colnames = c('Cluster Number', 'Screen name', 'Date-Time'),
                           rownames = T,
                           height = 400,
                           selection = list(mode='disable'))
    table
  })
  
#-------------------------Reactive-------------------------------------------------------------
  get_retweet_data <- eventReactive(input$retweets_list_rows_selected, {
    row <- input$retweets_list_rows_selected
    id <-  most_retweeted[row, 'retweeted_id']
    rs = dbSendQuery(DW, paste0("select user_id, cluster_number, created_at, full_text, screen_name, retweets_count, retweeted_user_id
                      from DW_BDS.fact_tweets
                      where tweet_id=",id ,
                            " or
                            retweeted_id=", id))
    retweets <- fetch(rs, n=-1)
    retweets <- retweets[order(retweets$created_at),]
    retweets
  })
  
########################### End session #######################################################
  session$onSessionEnded(function() {
    dbDisconnect(DW)
  })
  
}) 


