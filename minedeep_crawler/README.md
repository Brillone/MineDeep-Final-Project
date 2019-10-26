# twitter_Crawler

This module focus on the twitter network crawler.

## What is the MineDeep project?

This project is a pilot of bulding network analysis tools. This tool main goal is
building a simple tool helping social media sites researchers analyze big
networks without having programming knowledge nor data mining knowledge.  

The project includes two main parts:
1. A twitter network crawler
2. Shiny app analyzing  the network.


## 1. Network crawler
The network crawler use snow ball algorithm for network crawling,
while continuing crawling using some criterions of user's types.
The classification is being made using a linear SVM classification
model, of the users tweets related to a specific period. The crawler
using different agents: twitter apps tokens and twitter users
tokens. Those agents are configured by the researcher and works in parallel
using python multi-threading.
