############################################# user tweets distribution ########################################
library(plotly)
library(RMySQL)
library(magrittr)

ydb = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host)
rs = dbSendQuery(ydb, "select date(created_at) as created_at, tweet_type, count(*) as tweets_count
                       from DW_BDS.fact_tweets
                       where user_id=1102672466 
                       group by date(created_at), tweet_type")

tweets_dates = fetch(rs, n=-1)
tweets_dates$created_at <- as.Date(tweets_dates$created_at)
regular_tweets <- tweets_dates[tweets_dates$tweet_type=='tweet',]
reply_tweets <- tweets_dates[tweets_dates$tweet_type=='reply',]
retweet_tweets <- tweets_dates[tweets_dates$tweet_type=='retweet',]
min_date <- as.Date('2018-03-01')
max_date <- as.Date('2018-03-31')
## Make a data frame with a full series of dates from the min date to the max date
## in the incomplete data frame
full_dates <- seq(min_date, max_date, by = "1 day")
full_dates <- data.frame(created_at = full_dates)
## Merge the complete data frame with the incomplete to fill in the dates and add 
## NAs for missing values
regular_tweets_complete <- merge(full_dates, regular_tweets, by = "created_at", 
                          all.x = TRUE)
replies_complete <- merge(full_dates, reply_tweets, by = "created_at", 
                                 all.x = TRUE)
retweets_complete <- merge(full_dates, retweet_tweets, by = "created_at", 
                                 all.x = TRUE)
regular_tweets_complete$tweets_count[is.na(regular_tweets_complete$tweets_count)] <- 0 
replies_complete$tweets_count[is.na(replies_complete$tweets_count)] <- 0 
retweets_complete$tweets_count[is.na(retweets_complete$tweets_count)] <- 0 

p <- plot_ly(x=regular_tweets_complete$created_at, y=regular_tweets_complete$tweets_count, type = 'scatter', mode = 'lines', name = 'Tweets', fill = 'tozeroy') %>%
  add_trace(x=replies_complete$created_at, y=replies_complete$tweets_count, name = 'Replies', fill = 'tozeroy') %>%
  add_trace(x=retweets_complete$created_at, y=retweets_complete$tweets_count, name = 'Retweets', fill = 'tozeroy')%>%
  layout(yaxis = list(title = 'Tweets'))
p


########################################### paterns discovery plot #######################################################3


sentence <- "select * from
(select date(tweets.created_at) as Tday, time(tweets.created_at) as Thour, user_id, created_at
from fact_tweets as tweets
where user_id= '949271933257908226' )
 AS DT 
 join (select count(tweets.tweet_id) as tweet_count, date(created_at) as date
 from fact_tweets as tweets
 where user_id= '949271933257908226'
 group by  date(tweets.created_at), user_id)
 as CT on DT.Tday= CT.date"
rs = dbSendQuery(ydb, sentence)
tweets_dates = fetch(rs, n=-1)

sum_dates <- unique.data.frame(tweets_dates[, c('date', 'tweet_count')])
sum_dates$cumsum <- cumsum(sum_dates$tweet_count)
events <- tweets_dates[, c('Tday', 'Thour')] 


ay <- list(
  dtick = 20,
  tickfont = list(color = "red"),
  overlaying = "y",
  side = "right",
  title = "Daily tweets count"
)
plot_ly(x=format(as.Date(events$Tday), "%d-%m"), y=events$Thour,name = 'Tweets', type='scatter',
        height = 400)%>%
  add_lines(x = format(as.Date(sum_dates$date), "%d-%m"), y =sum_dates$tweet_count, name = "Daily tweets count", yaxis = "y2") %>%
  layout(margin = list(l = 150, r = 150, b = 150),
         xaxis = list(tickangle=45, title="Days of March 2018"), yaxis = list(title="Tweets Hours"), yaxis2 =ay)

###########################################bot or not ###########################################################3
library(rtweet)
appname <- "rtweet_token"

## api key (example below is not a real key)
key <- ""

## api secret (example below is not a real key)
secret <- ""

## create token named "twitter_token"
twitter_token <- create_token(
  app = 'TweetMoviePop',
  consumer_key = '',
  consumer_secret = '')

rt <- search_tweets(
  "#rstats", n = 18000, include_rts = FALSE
)
library(botrnot)
z <- botornot('Dee_Lauria')

############################################### intervals hist ##############################################################3
library(RMySQL)
library(plotly)


sentence <- "select created_at
             from fact_tweets as tweets
             where user_id= 211411397"
rs = dbSendQuery(ydb, sentence)
tweets_dates = fetch(rs, n=-1)
tweets_dates$t_back <- c(0,tweets_dates$created_at[1:nrow(tweets_dates)-1])
tweets_dates$intervals <- c(0,difftime(tweets_dates$created_at[2:nrow(tweets_dates)] ,tweets_dates$t_back[2:nrow(tweets_dates)], units = 'mins'))
tweets_dates$intervals[as.Date(tweets_dates$t_back, format="%Y-%m-%d")!=as.Date(tweets_dates$created_at)] <- 0 
tweets_dates <- tweets_dates[,c('created_at', 'intervals')]


cond <- tweets_dates$intervals<100

temp <- tweets_dates[cond,]

plot_ly(x=temp$created_at, y=temp$intervals,name = 'Tweets',  mode='lines', type='scatter',
        height = 400)

detach("package:RMySQL", unload=TRUE)
library(sqldf)
bar <- sqldf('select intervals, count(created_at) as cnt
              from tweets_dates
              group by intervals')
bar_t <- bar[bar$cnt>1 & bar$intervals>0,]
bar_t$intervals <- factor(bar_t$intervals)   
plot_ly(x=bar_t$intervals, y=bar_t$cnt,name = 'Tweets', type='bar',
        height = 400)

####################################### mentions filtering ##################################################3
library(RMySQL)
DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host)
get_tweets_statement <- paste0('select created_at, full_text, processed_text, tweet_type
                                   from DW_BDS.fact_tweets
                                   where user_id=949271933257908226'
)
rs = dbSendQuery(DW, get_tweets_statement)
tweets <- fetch(rs, n=-1)
text <- paste0(tweets$processed_text)
mentions <- str_extract_all(tweets$processed_text, "@\\w+")
mentions <- unlist(mentions)

1-(length(unique(tweets$processed_text))/nrow(tweets$processed_text))

############################################# interval hist 2 #################################################
library(RMySQL)
library(plotly)

sentence <- "select created_at
             from fact_tweets as tweets
             where user_id= 211411397"
rs = dbSendQuery(ydb, sentence)
tweets_dates = fetch(rs, n=-1)
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
plot_ly(x=bar_t$intervals_factor, y=bar_t$cnt,name = 'Tweets', type='bar',
        height = 280, width = 500,
        marker=list(color=ifelse(bar_t$cnt>4,'rgba(222,45,38,0.8)','blue')))
###############################################retweets interval boxplot#################################################################################
library(RMySQL)
library(plotly)

id <- 977592827348742146
DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host_address, port=3306)
rs = dbSendQuery(DW, paste0("select user_id, cluster_number, created_at, full_text, screen_name, num_of_likes, retweets_count
                      from DW_BDS.fact_tweets
                      where tweet_id=",id ,
                            " or
                            retweeted_id=", id))

most_retweeted = fetch(rs, n=-1)

most_retweeted$intervals <- c(0,difftime(most_retweeted$created_at[2:nrow(most_retweeted)], most_retweeted$created_at[1:(nrow(most_retweeted)-1)], units = 'secs'))

plot_ly(y=~most_retweeted$intervals[as.Date(most_retweeted$created_at)==min(as.Date(most_retweeted$created_at))], type='box', name='First day')%>%
  layout(yaxis = list(title = 'Time interval between retweets (Sec)'))  
