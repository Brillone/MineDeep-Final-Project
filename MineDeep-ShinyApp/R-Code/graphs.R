library(RMySQL)
library(igraph)
############################################ graph #####################################################################
load("/home/zoro/MineDeep-master/MineDeep_ShinyApp/MineDeep/data/pass.RData")
ydb = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host_address, port=3306)
rs = dbSendQuery(ydb, "select f.follower_id, f.user_id
                 from (SELECT follower_id, count(*) as out_degree
                 FROM BDSProject.followers
                 group by follower_id
                 having out_degree>1) as fs join
                 BDSProject.followers as f on f.follower_id=fs.follower_id;")
graph_data = fetch(rs, n=-1)

g <- graph_from_data_frame(graph_data, directed=T)
rm(graph_data)
g <- simplify(g)
eb <- cluster_infomap(g)
max(eb$membership)

df <- data.frame(user_id=V(g)$name,cluster_number=eb$membership)
dbWriteTable(ydb, name="clusters", value=df, field.types=list(user_id="varchar(24)", cluster_number="int"), row.names=FALSE,append=T)

rs = dbSendQuery(ydb, "select f.follower_id, f.user_id
                 from (SELECT follower_id, count(*) as out_degree
                 FROM BDSProject.followers
                 group by follower_id
                 having out_degree<=1) as fs join
                 BDSProject.followers as f on f.follower_id=fs.follower_id;")
un_clustered <- fetch(rs, n=-1)
joined <- merge(un_clustered, df, by.x='user_id', by.y='user_id')
joined <- joined[,2:3]
colnames(joined) <- c('user_id', 'cluster_number')


rs = dbSendQuery(ydb,"select m.user_id, c1.cluster_number
                 from BDSProject.followers as f join 	
                 (select  u.user_id, c.cluster_number
                 from BDSProject.users as u left join BDSProject.clusters as c on u.user_id=c.user_id
                 where c.user_id is null) as m on f.follower_id=m.user_id join 
                 BDSProject.clusters as c1 on c1.user_id=f.user_id")
un_clustered <- fetch(rs, n=-1)
dbWriteTable(ydb, name="clusters", value=un_clustered, field.types=list(user_id="varchar(24)", cluster_number="int"), row.names=FALSE,append=T)



##################################################### clusters graph #############################################################
rs = dbSendQuery(ydb, "select *
                 from BDSProject.followers;")
followers = fetch(rs, n=-1)
detach("package:RMySQL", unload=TRUE)
library(sqldf)
merge1 <- merge(followers, df,by.x='user_id', by.y='user_id')
merge2 <- merge(merge1, df,by.x='follower_id', by.y='user_id')
clusters_relations <- merge2[,c("cluster_number.x", "cluster_number.y")]
colnames(clusters_relations) <- c("user_cluster", "follower_cluster")
clusters_us_to_fol <- sqldf("select user_cluster, follower_cluster, count() as count
                            from clusters_relations
                            group by user_cluster, follower_cluster
                            ")
clusters_us_to_fol <- clusters_us_to_fol[clusters_us_to_fol$user_cluster!=clusters_us_to_fol$follower_cluster,]
clusters_us_to_fol1 <- clusters_us_to_fol[clusters_us_to_fol$count>50,]
#########################################################################################################
rm(clusters_relations, df, followers, merge1, merge2)
#########################################################################################################
#################################visNetwork visualize####################################################
library(visNetwork)
g_clusters <- graph_from_edgelist(as.matrix(clusters_us_to_fol1[,1:2])) #We first greate a network from the first two columns, which has the list of vertices
g_clusters <- simplify(g_clusters)
E(g_clusters)$weight=as.numeric(clusters_us_to_fol1[,3]) 
g1 <- toVisNetworkData(g_clusters)
visNetwork(g1$nodes, g1$edges, height = "1000px",width="100%")%>%
  visPhysics(stabilization = FALSE)%>%
  visEdges(smooth = FALSE)%>%
  visIgraphLayout()
################################## another version #######################################################################
library(igraph)
library(visNetwork)
library(qgraph)
library(RMySQL)

s = dbSendQuery(ydb,"select *
                from BDSProject.clusters")
clustering <- fetch(s, n=-1)
rs = dbSendQuery(ydb, "select *
                 from BDSProject.followers;")
followers = fetch(rs, n=-1)

detach("package:RMySQL", unload=TRUE)
library(sqldf)
merge1 <- merge(followers, clustering,by.x='user_id', by.y='user_id')
merge2 <- merge(merge1, clustering,by.x='follower_id', by.y='user_id')
clusters_count <- sqldf('select cluster_number, count(*) as size
                        from clustering
                        group by cluster_number;')

clusters_relations <- merge2[,c("cluster_number.x", "cluster_number.y")]
colnames(clusters_relations) <- c("user_cluster", "follower_cluster")
clusters_us_to_fol <- sqldf("select user_cluster, follower_cluster, count() as count_relation
                            from clusters_relations
                            group by user_cluster, follower_cluster
                            ")
clusters_us_to_fol <- clusters_us_to_fol[clusters_us_to_fol$user_cluster!=clusters_us_to_fol$follower_cluster,]
clusters_us_to_fol1 <- clusters_us_to_fol[clusters_us_to_fol$count_relation>4000,]
###############################################################################################
rm(clusters_relations, clustering, followers, merge1, merge2)
###############################################################################################
g <- graph_from_data_frame(clusters_us_to_fol1[,1:2], directed=F)
E(g)$weight=as.numeric(clusters_us_to_fol1[,3]) 
#V(g)$color <- bipartite.mapping(g)$type + 1L
V(g)$title <- V(g)$name
set.seed(1)
coords <- qgraph.layout.fruchtermanreingold(
  as_edgelist(g, names = F), 
  weights=E(g)$value,
  vcount=vcount(g), 
  area=vcount(g)^2, 
  repulse.rad=vcount(g)^3
)
visIgraph(g)%>%
  visEdges(width = "value", title="value", color = list(highlight="#ff0000", opacity = .8)) %>%
  visIgraphLayout("layout_with_fr") 

##################################floating graph#############################################################
library(visNetwork)
g <- toVisNetworkData(g)
visNetwork(g$nodes, g$edges)%>%
  visInteraction(dragNodes = FALSE, 
                 dragView = FALSE, 
                 zoomView = FALSE) %>%
  visLayout(randomSeed = 123)
##########################################app version###################################################################
library(magrittr)
library(igraph)
library(visNetwork)
library(qgraph)
load("~/MineDeep-master/MineDeep/MineDeep_App/graphs_data.RData")
clusters_count$node_size <- NA
clusters_count$node_size[clusters_count$size < 1000 ] <- 25
clusters_count$node_size[clusters_count$size>=1000 & clusters_count$size < 5000 ] <- 50
clusters_count$node_size[clusters_count$size>=5000 & clusters_count$size < 10000 ] <- 100
clusters_count$node_size[clusters_count$size>=10000 & clusters_count$size < 100000 ] <- 160
clusters_count$node_size[clusters_count$size>=100000] <- 320

clusters_us_to_fol1 <- clusters_us_to_fol[clusters_us_to_fol$count>100,]
g <- graph_from_data_frame(clusters_us_to_fol1[,1:2], directed=T)

l1 <- as.vector(unique(clusters_us_to_fol[,1])) 
l2 <- as.vector(unique(clusters_us_to_fol[,2])) 
comb <- c(l1,l2)
comb <- unique(comb)
to_add <- setdiff(comb, as.vector(V(g)$name, 'numeric'))

g <- add.vertices(g, length(to_add), name=to_add)

E(g)$weight=as.numeric(clusters_us_to_fol1[,3]) 
E(g)$width <- 1+E(g)$weight/500
V(g)$font.size <- 100
V(g)$size <- clusters_count[match(as.numeric(V(g)$name), clusters_count$cluster_number),]$node_size
V(g)$title <- paste0("<p>","Cluster: ", V(g)$name, "<br>Users count: ", clusters_count[match(as.numeric(V(g)$name), clusters_count$cluster_number),]$size,"</p>")
g_temp <- graph.neighborhood(g, order = 1, 3)
data <- toVisNetworkData(g)

z <- visNetwork(nodes = data$nodes, edges = data$edges, height=1200, width=1200)%>%
  visEdges(arrows =list(to = list(enabled = TRUE, scaleFactor = 1)),
           color = list(color = "lightblue", highlight = "red")) %>%
  visOptions(highlightNearest = TRUE)%>%
  visPhysics(solver = "forceAtlas2Based",
             forceAtlas2Based = list(gravitationalConstant = -500), stabilization = T, timestep = 0.2)
############################################ego graph##########################################################
library(RMySQL)
library(magrittr)
library(igraph)
library(visNetwork)
library(qgraph)

rs = dbSendQuery(ydb, "select user_id, follower_id from DW_BDS.fact_followers")
graph_data = fetch(rs, n=-1)

g <- graph_from_data_frame(graph_data, directed=T)
V(g)$title <- V(g)$name

id='813286'
temp_graph <- make_ego_graph(g,1,id,'in')
V(temp_graph[[1]])$size[V(temp_graph[[1]])$name==id] <- 50
V(temp_graph[[1]])$size[V(temp_graph[[1]])$name!=id] <- 20


visIgraph(temp_graph[[1]])%>%
  visEdges(arrows =list(to = list(enabled = TRUE, scaleFactor = 1)),
           color = list(color = "lightblue", highlight = "red")) %>%
  visNodes(size=10)%>%
  visIgraphLayout("layout_with_fr") 

############################################# key players ###################################################

library(RMySQL)
library(magrittr)
library(igraph)
library(visNetwork)
library(qgraph)

DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host_address, port=3306)
rs = dbSendQuery(DW, "select user_id, follower_id from DW_BDS.fact_followers")
graph_data = fetch(rs, n=-1)

g1 <- graph_from_data_frame(graph_data, directed=T)
V(g1)$title <- V(g1)$name

bt <- betweenness(g1)
betweenes_df <- as.data.frame(bt)
betweenes_df$user_id <- rownames(betweenes_df)
betweenes_df <- betweenes_df[,c('user_id', 'bt')]
rownames(betweenes_df) <- 1:nrow(betweenes_df)
colnames(betweenes_df) <- c('user_id', 'betweenes')

get_users <- paste0('select user_id, screen_name
                                    from DW_BDS.fact_users'
)
rs = dbSendQuery(DW, get_users)
users_data = fetch(rs, n=-1)
players <- merge(users_data, betweenes_df, by='user_id')
players <- players[order(players$betweenes, decreasing = T),]
rownames(players) <- 1:nrow(players)
players <- players[players$betweenes>0,]
rm(betweenes_df,DW,rs,users_data,get_users)


################################################## bubble retweets spread ##############################################
library(RMySQL)
library(magrittr)
library(igraph)
library(visNetwork)
library(qgraph)
library(bubbles)

id <- 977592827348742146
DW = dbConnect(MySQL(), user=user, password=password, dbname=dbname, host=host)
rs = dbSendQuery(DW, paste0("select user_id, cluster_number, created_at, full_text, screen_name
                      from DW_BDS.fact_tweets
                      where tweet_id=",id ,
                             " or
                            retweeted_id=", id))

most_retweeted = fetch(rs, n=-1)

most_retweeted$intervals <- difftime(max(most_retweeted$created_at), most_retweeted$created_at, , units = 'hours')
most_retweeted[1:100,]
graph_data <- most_retweeted[1:100,]
graph_data$index <- nrow(graph_data):1
graph_data$index[2:100] <- graph_data$index[2:100]**3
graph_data$index[1] <- graph_data$index[1]**3.1
colors <- as.data.frame(unique(graph_data$cluster_number))
colors$color_index <- 1:nrow(colors)
colnames(colors) <- c('cluster_number', 'color_index') 
graph_data <- join(graph_data, colors, by='cluster_number')

bubbles(value = graph_data$index, label = graph_data$cluster_number, textColor = 'black',
        color = rainbow(length(unique(graph_data$cluster_number)), alpha=NULL)[graph_data$color_index]
)

