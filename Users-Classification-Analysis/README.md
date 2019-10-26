# users-classification-analysis
This repo focus on the development of users classifier as a part of the MineDeep
platform development. This analysis was later implanted in the network crawler.

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

## The repo structure:
1. data - This folder contains:
a. Training set for the tweets classifier as being created by the tweets
collect tools
b. The hashtags lists of pro and against users
c. problems.pickle - Known problematic tokens.
d. user_data.csv -  Known data on users from twitter.
e. user_meta_data.csv - Data extracted from pulling user activity of 3 months
period, e.g: retweet precent of all tweets.
g. boundaries_analysis.csv - data collected for the user classification
bounderies development.

2. distribution - This folder contains the user data collector for users
distribution analysis as a python script using twitter API and web-scrapping.

3. notebooks - Inside there are 3 notebooks:
a. dist_search - The notebook explore this users population activity on twitter
to find the right thresholds to seperate users by their activity, e.g: seperate
user to unactive user, active users and advanced active users. Those thresholds
are later used as a continue criterion to the BFS crawling.
b. tweets_classifier - This notebook concentrate on the ML classifier
development including training set exploring, models development, models
comparing and finally choose the model for the crawler use classification.
c. user_classifer - We explore in this notebook how to transform our tweets
classifier to a user classifier by estimating user timeline tweets precents
thresholds to classify users.

4. tweets_collect_tool - This folder contains a python scripts for pulling
tweets of users who are part of twitter lists pro and against users. Those
scripts were used to build the training set of the ML tweets classifier.
