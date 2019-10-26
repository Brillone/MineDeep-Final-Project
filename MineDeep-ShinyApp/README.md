# MineDeep_ShinyApp

This repo focus on the Shiny app as described later.

## What is the MineDeep project?

This project is a pilot of a network analysis tool. This tool main goal is
building a simple tool helping social media sites researchers analyze big
networks without having programming knowledge nor data mining knowledge.  

The project includes two main parts:
1. A twitter network crawler
2. Shiny app analyzing  the network


#### Note:
The other part of the network crawler is currently private and maybe will be
published later.

## 2. Network analysis Shiny app
The Shiny app pull data from a temporary DWH of the oltp database maintained
by the network crawler. The app includes World-Wide Analysis, Users Analysis,
Bots Analysis and Retweets Analysis. Further, the app demonstrate the founded
cliques by the info-map graph network clustering algorithm, a clustering network
algorithm of big networks. Besides of finding the network cliques, we have
managed to show the network leaders using betweeness centrality scoring, showing
how important the actors in the network.

## Repo directories
1. MineDeep - The app itself. The app contain the server file (the backend
file), the ui file (The user interface file), 2 css files of the shinydashboard
for the purpose of using some of it graphics, the data folder for app local
storage and the WWW folder storing inside images for design.
2. SQL_SCRIPTS - The script of building the oltp database and the DWH. The DWH
script is more relevant to this repo as the app use pull data directly from it.
3. screenshots - This directory has some screenshots of the app, showing a
number use cases of the using the app.

### Local database
There are some R local type file. The purpose of them is save processing time
while using the app. For example: countries_shape are countries polygons saved
in variable to create the users world map or another example is the key_players
file saving the users betweenness score instead of wasting time calculating it
every time we load the app. A different use is saving secret data e.g: DB
connection params or the twitter api token (used in the bot or not function).

#### Notes:
The "twitter_token.RData" and "pass.RData" file are missing due to secrecy.
You should add your on files with your own passwords and token.
The "twitter_token.RData" contain the twitter_token variable created by the
"create_token()" function of rtweet library.\n
The "pass.RData" contain the next variables: \n
"user" - the user name of the DB connection. \n
"password" - the password of the DB connection.\n
"dbname" - the database name.\n
"host_address" - the host address of the database (local: "127.0.0.1")


## Conclusion
This app showing abilities and research possibilities of a social media network
analysis tool. The app was built as a pilot project and can be used for Further
development.
