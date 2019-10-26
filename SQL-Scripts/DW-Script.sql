create database DW_BDS DEFAULT CHARACTER SET utf8mb4;
SET NAMES utf8mb4;
-- ALTER DATABASE BDSProject CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

###############################Tweets fact##########################################
CREATE TABLE DW_BDS.fact_tweets as
  SELECT t.tweet_id,
		 t.created_at,
		 t.user_id,
		 t.full_text,
		 t.processed_text,
		 t.lang,
		 t.num_of_likes,
		 t.retweets_count,
		 t.retweeted_id,
		 t.retweeted_user_id,
		 t.replied_tweet_id, 
		 t.replied_user_id,
		 t.tweet_type,
		 t.has_media,
		 u.user_name,
		 u.screen_name,
		 u.user_created_at,
		 u.description,
		 u.is_protected,
		 u.user_lang,
		 u.user_location,
		 u.time_zone,
		 u.status_count, 
		 u.favourites_count,
		 u.followers_count,
		 u.friends_count,
		 u.listed_count,
		 u.bfs_level,
         u.user_type,
		 u.checked_followers,
		 u.date_inserted,
         c.cluster_number,
		 l.city_name,
		 l.province,
	 	 l.country,
		 l.country_code,
		 l.latitude, 
		 l.longitude
  FROM BDSProject.tweets as t
	   join
	   BDSProject.users as u on t.user_id=u.user_id
       join 
       BDSProject.clusters as c on u.user_id=c.user_id
       left join 
       BDSProject.locations as l on u.user_location=l.user_location;
CREATE INDEX tweet ON DW_BDS.fact_tweets(tweet_id);
CREATE INDEX user_in_tweets ON DW_BDS.fact_tweets(user_id);
CREATE INDEX retweets_find ON DW_BDS.fact_tweets(retweeted_id);
################################Users fact########################################
CREATE TABLE DW_BDS.fact_users as
	select 
		 u.user_id,
         u.user_name,
		 u.screen_name,
		 u.user_created_at,
		 u.description,
		 u.is_protected,
		 u.user_lang,
		 u.user_location,
		 u.time_zone,
		 u.status_count, 
		 u.favourites_count,
		 u.followers_count,
		 u.friends_count,
		 u.listed_count,
		 u.bfs_level,
         u.user_type,
		 u.checked_followers,
		 u.date_inserted,
         c.cluster_number,
		 l.city_name,
		 l.province,
	 	 l.country,
		 l.country_code,
		 l.latitude, 
		 l.longitude,
         ts.tweets_count,
         ts.tweets_average,
         ts.user_being_retweeted,
         ts.user_being_liked,
         ts.simple_tweet_precent,
         ts.retweets_precent,
         ts.replies_precent,
         ts.tweet_average_likes,
         ts.average_tweet_length,
         ts.media_precent,
         DATEDIFF(CURDATE(), date(user_created_at))/365 as seniority
    from 
		BDSProject.users as u 
		join 
        BDSProject.clusters as c on u.user_id=c.user_id
        left join
        BDSProject.locations as l on u.user_location=l.user_location
        left join (select t.user_id, 
						  count(t.tweet_id) as tweets_count,
						  count(t.tweet_id)/datediff('2018-04-01', date(min(t.created_at))) as tweets_average,
                          sum(if(t.tweet_type='tweet' or t.tweet_type='reply',1 ,0)) as user_being_retweeted,
                          sum(if(t.tweet_type='tweet' or t.tweet_type='reply',t.num_of_likes ,0)) as user_being_liked,
						  SUM(if(t.tweet_type='tweet', 1, 0))/count(t.tweet_id) as simple_tweet_precent,
						  SUM(if(t.tweet_type='retweet', 1, 0))/count(t.tweet_id) as retweets_precent,
						  SUM(if(t.tweet_type='reply', 1, 0))/count(t.tweet_id) as replies_precent,
						  avg(t.num_of_likes) as tweet_average_likes,
						  sum(length(t.full_text))/count(t.tweet_id) as average_tweet_length,
						  SUM(if(t.has_media=1, 1, 0))/count(t.tweet_id) as media_precent
						  from BDSProject.tweets as t
						  group by t.user_id) as ts on u.user_id=ts.user_id
						  
	group by 
		 u.user_id,
         u.user_name,
		 u.screen_name,
		 u.user_created_at,
		 u.description,
		 u.is_protected,
		 u.user_lang,
		 u.user_location,
		 u.time_zone,
		 u.status_count, 
		 u.favourites_count,
		 u.followers_count,
		 u.friends_count,
		 u.listed_count,
		 u.bfs_level,
         u.user_type,
		 u.checked_followers,
		 u.date_inserted,
         c.cluster_number,
		 l.city_name,
		 l.province,
	 	 l.country,
		 l.country_code,
		 l.latitude, 
		 l.longitude;
CREATE INDEX user_index ON DW_BDS.fact_users(user_id);
CREATE INDEX locations_index ON DW_BDS.fact_users(user_location);
CREATE INDEX clusters_index ON DW_BDS.fact_users(cluster_number);
################################Followers Fact########################################
CREATE TABLE DW_BDS.fact_followers as
	select 
		 f.user_id,
         f.follower_id,
         fact_u1.user_name as u_user_name,
		 fact_u1.screen_name as u_screen_name,
		 fact_u1.user_created_at as u_user_created_at,
		 fact_u1.description as u_description,
		 fact_u1.is_protected as u_is_protected,
		 fact_u1.user_lang as u_user_lang,
		 fact_u1.user_location as u_user_location,
		 fact_u1.time_zone as u_time_zone,
		 fact_u1.status_count as u_status_count, 
		 fact_u1.favourites_count as u_favourites_count,
		 fact_u1.followers_count as u_followers_count,
		 fact_u1.friends_count as u_friends_count,
		 fact_u1.listed_count as u_listed_count,
		 fact_u1.bfs_level as u_bfs_level,
         fact_u1.user_type as u_user_type,
		 fact_u1.checked_followers as u_checked_followers,
         fact_u1.cluster_number as u_cluster_number,
		 fact_u1.city_name as u_city_name,
		 fact_u1.province as u_province,
		 fact_u1.country as u_country,
		 fact_u1.country_code as u_country_code,
		 fact_u1.latitude as u_latitude, 
		 fact_u1.longitude as u_longitude,
         fact_u1.tweets_count as u_tweets_count,
         fact_u1.tweets_average as u_tweets_average,
         fact_u1.user_being_retweeted as u_being_retweeted,
         fact_u1.user_being_liked as u_being_liked,
         fact_u1.simple_tweet_precent as u_simple_tweet_precent,
         fact_u1.retweets_precent as u_retweets_precent,
         fact_u1.replies_precent as u_replies_precent,
         fact_u1.tweet_average_likes as u_tweet_average_likes,
         fact_u1.average_tweet_length as u_average_tweet_length,
         fact_u1.media_precent as u_media_precent,
         fact_u1.seniority as u_seniority,
         fact_u2.user_name as f_user_name,
		 fact_u2.screen_name as f_screen_name,
		 fact_u2.user_created_at as f_user_created_at,
		 fact_u2.description as f_description,
		 fact_u2.is_protected as f_is_protected,
		 fact_u2.user_lang as f_user_lang,
		 fact_u2.user_location as f_user_location,
		 fact_u2.time_zone as f_time_zone,
		 fact_u2.status_count as f_status_count, 
		 fact_u2.favourites_count as f_favourites_count,
		 fact_u2.followers_count as f_followers_count,
		 fact_u2.friends_count as f_friends_count,
		 fact_u2.listed_count as f_listed_count,
		 fact_u2.bfs_level as f_bfs_level,
         fact_u2.user_type as f_user_type,
		 fact_u2.checked_followers as f_checked_followers,
         fact_u2.cluster_number as f_cluster_number,
		 fact_u2.city_name as f_city_name,
		 fact_u2.province as f_province,
		 fact_u2.country as f_country,
		 fact_u2.country_code as f_country_code,
		 fact_u2.latitude as f_latitude, 
		 fact_u2.longitude as f_longitude,
         fact_u2.tweets_count as f_tweets_count,
         fact_u2.tweets_average as f_tweets_average,
         fact_u2.user_being_retweeted as f_being_retweeted,
         fact_u2.user_being_liked as f_being_liked,
         fact_u2.simple_tweet_precent as f_simple_tweet_precent,
         fact_u2.retweets_precent as f_retweets_precent,
         fact_u2.replies_precent as f_replies_precent,
         fact_u2.tweet_average_likes as f_tweet_average_likes,
         fact_u2.average_tweet_length as f_average_tweet_length,
         fact_u2.media_precent as f_media_precent,
         fact_u2.seniority as f_seniority
    from 
		BDSProject.followers as f
		join 
        DW_BDS.fact_users as fact_u1 on f.user_id=fact_u1.user_id
        join
        DW_BDS.fact_users as fact_u2 on f.follower_id=fact_u2.user_id;
CREATE INDEX follower_index ON DW_BDS.fact_followers(user_id, follower_id);
CREATE INDEX follower_cluster_index ON DW_BDS.fact_followers(u_cluster_number, f_cluster_number);
#####################################Mentions Fact##################################################3


		