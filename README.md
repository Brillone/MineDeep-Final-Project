# MineDeep

This project is a pilot of a network analysis tool. This tool main goal is
building a simple tool helping social media sites researchers analyze big
networks without having programming knowledge nor data mining knowledge.  

The project includes two main parts:
1. A twitter network crawler
2. Shiny app analyzing  the network

## 1. Network crawler
The network crawler use snow ball algorithm for network crawling,
while the continuing crawling criterion is being classified as "pro - advanced
active" user. The classification is being made using a linear SVM classification
model of the users tweets of the chosen period by the researcher. The crawler
using different agents whom are the twitter apps tokens and twitter users
tokens. those agents are configured by the researcher and works in parallel
using python multi-threading.

## 2. Network analysis shiny apps
The shiny app pull data from a temporary data WH of the oltp database maintained
by the network crawler. The app includes world-wide analysis, users analysis,
bots  analysis and retweets analysis. Further, the app demonstrate the founded
cliques by the info-map graph network clustering algorithm, a clustering network
algorithm of big networks. Besides of finding the network cliques, we have
managed to show the network leaders using betweeness centrality scoring showing
how important the actors in the network.



