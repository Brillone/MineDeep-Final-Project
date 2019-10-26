################################################## WordCloud ########################################################
library(tm)
library(RMySQL)
library(wordcloud)
library(stringi)
library(stringr)

DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host)
rs = dbSendQuery(DW, "select processed_text
                      from DW_BDS.fact_tweets as tweets
                      where user_id=1102672466;")
tweets = fetch(rs, n=-1)
tweets$processed_text <-  stri_encode(tweets$processed_text, "", "UTF-8")
hashtags=str_extract_all(tweets$processed_text, "#\\w+")
hashtags=unlist(hashtags)
docs<-Corpus(VectorSource(hashtags))
dtm<-TermDocumentMatrix(docs)
m<-as.matrix(dtm)
v<-sort(rowSums(m),decreasing=TRUE)
d<-data.frame(word=names(v),freq=v)
wordcloud(d$word, d$freq,scale=c(5,0.8),max.words=200, random.order=FALSE, colors=brewer.pal(8,"Set1"),min.freq=0)


###################################### better wordcloud #############################################################
rs = dbSendQuery(DW, "select processed_text
                      from DW_BDS.fact_tweets as tweets
                      where user_id=1102672466;")
tweets = fetch(rs, n=-1)
tweets$processed_text <-  stri_encode(tweets$processed_text, "", "UTF-8")
# png("wordcloud_packages.png", width=12,height=8, units='in', res=300)
# wordcloud(tweets$processed_text, scale=c(10,.2))
hashtags=str_extract_all(tweets$processed_text, "#\\w+|\\w+")
hashtags=unlist(hashtags)
hashtags_freq = table(hashtags)
wordcloud(names(hashtags_freq), hashtags_freq, random.order=FALSE, 
          colors="#1B9E77")



############################################## Mentions cloud ##########################################################################
DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host_address, port=3306)
rs = dbSendQuery(DW, "select processed_text
                      from DW_BDS.fact_tweets as tweets
                      where user_id=949271933257908226;")
tweets = fetch(rs, n=-1)
tweets$processed_text <-  stri_encode(tweets$processed_text, "", "UTF-8")
# png("wordcloud_packages.png", width=12,height=8, units='in', res=300)
# wordcloud(tweets$processed_text, scale=c(10,.2))
hashtags=str_extract_all(tweets$processed_text, "@\\w+")
hashtags=unlist(hashtags)
hashtags_freq = table(hashtags)
wordcloud(names(hashtags_freq), hashtags_freq, scale=c(3,0.5), max.words = 100,random.order=FALSE,rot.per=.15,colors=brewer.pal(8, "Dark2"))




