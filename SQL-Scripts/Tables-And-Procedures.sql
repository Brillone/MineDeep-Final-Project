-- --------Drop tables----------
-- drop database BDSProject;
-- drop table BDSProject.mentions;
-- drop table BDSProject.followers;
-- drop table BDSProject.tweets;
-- drop table BDSProject.users;
-- -- -- ------------------------------

-- -----------------------------------Tables-------------------------------------------------
create database BDSProject;
SET NAMES utf8mb4;
ALTER DATABASE BDSProject CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
-- --------Users table----------
CREATE TABLE BDSProject.users (
    user_id varchar(24) PRIMARY KEY, -- varchar
    user_name varchar(60) NOT NULL,
    screen_name varchar(60) not null,
    user_created_at DATETIME not null,
    description varchar(200),
    is_protected bit,
    user_lang varchar(6),
    user_location varchar(150),
    time_zone varchar(150),
    status_count int DEFAULT 0,
    favourites_count int DEFAULT 0,
    followers_count int DEFAULT 0,
    friends_count int DEFAULT 0,
    listed_count int DEFAULT 0,
    bfs_level int not null DEFAULT 0,
    user_type varchar(22) CHECK (user_type='pro - unactive' or
                                 user_type='pro - active' or
                                 user_type='pro - advanced active' or
                                 user_type='other' or
                                 user_type is null),
    checked_followers bit not null default 0, # all the followers token
    date_inserted datetime
);
-- -------------------------------
										 
-- --------Tweets table----------
CREATE TABLE BDSProject.tweets (
    tweet_id varchar(24) primary key not null,
    created_at datetime not null,
    user_id varchar(24) not null,
    full_text varchar(1000),
    processed_text varchar(1000),
    lang varchar(6),
    num_of_likes int not null default 0,
    retweets_count int not null default 0,
    retweeted_id varchar(24), -- original tweet id, can be null if not a retweet
    retweeted_user_id varchar(24), -- original tweet user id, can be null if not a retweet
    replied_tweet_id varchar(24), -- original tweet id, can be null if not a retweet
    replied_user_id varchar(24), -- original tweet user id, can be null if not a retweet
    tweet_type varchar(15), -- retweet, reply, tweet,
    has_media bit,
    foreign key (user_id) references users(user_id)
);
-- --------------------------------

-- --------Followers table--------
CREATE TABLE BDSProject.followers (
    user_id varchar(24) NOT NULL DEFAULT 0,
    follower_id varchar(24) NOT NULL DEFAULT 0,
    CONSTRAINT PK_followers PRIMARY KEY (user_id,follower_id),
    foreign key (user_id) references users(user_id),
    foreign key (follower_id) references users(user_id)
);
-- -------------------------------

-- --------Mentions table--------
CREATE TABLE BDSProject.mentions (
	tweet_id varchar(24) NOT NULL,
	user_id varchar(24) NOT NULL,
    CONSTRAINT PK_mentions PRIMARY KEY (tweet_id,user_id),
	foreign key (tweet_id) references tweets(tweet_id)
);
-- -------------------------------

-- --------Locations table--------
CREATE TABLE BDSProject.locations (
    user_location varchar(200) primary key not null,
    city_name varchar(200),
    province varchar(200),
    country varchar(200) not null,
    country_code varchar(10) not null,
	latitude float, 
    longitude float
);
-- --------------------------------
-- --------Locations table--------
CREATE TABLE BDSProject.clusters (
    user_id varchar(24) primary key not null,
    cluster_number int
);
-- --------------------------------





-- -----------------------------------Stored Procedures-------------------------------------------------

-- -------------------Read Procedures---------------------

-- ----------get_users_to_process----------
delimiter //
CREATE PROCEDURE BDSProject.get_users_to_process()
BEGIN
	SELECT user_id
	FROM BDSProject.users
	where user_type is null and is_protected=0 and bfs_level>1;	
END//
delimiter ;
-- ----------------------------------------

-- ----------get_users_to_crawl----------
delimiter //
CREATE PROCEDURE BDSProject.get_users_to_crawl()
BEGIN
	SELECT user_id
	FROM BDSProject.users
	where checked_followers=0 and
		  user_type='pro - advanced active' and
          bfs_level>1 and
          bfs_level=(SELECT min(bfs_level)
					 FROM BDSProject.users
					 where checked_followers=0 and bfs_level>=1 and user_type='pro - advanced active');	
END//
delimiter ;
-- ----------------------------------------

-- ----------get_supporters----------
delimiter //
CREATE PROCEDURE BDSProject.get_supporters()
BEGIN
	SELECT user_id
	FROM BDSProject.users
	where user_type='pro - active' or user_type='pro - advanced active';	
END//
delimiter ;
-- ----------------------------------------

-- ----------get_already_checked----------
delimiter //
CREATE PROCEDURE BDSProject.get_already_processed()
BEGIN
	SELECT user_id
	FROM BDSProject.users
	where user_type is not null;	
END//
delimiter ;
-- ----------------------------------------

-- ----------get_already_checked----------
delimiter //
CREATE PROCEDURE BDSProject.get_all_users()
BEGIN
	SELECT user_id
	FROM BDSProject.users;	
END//
delimiter ;
-- ----------------------------------------

-- ----------get_crawl_level----------
delimiter //
CREATE PROCEDURE BDSProject.get_crawl_level()
BEGIN
	SELECT min(bfs_level)
	FROM BDSProject.users
	where checked_followers=0 and bfs_level>=1 and user_type='pro - advanced active';	
END//
delimiter ;
-- ----------------------------------------

-- ----------get_to_process_level----------
delimiter //
CREATE PROCEDURE BDSProject.get_process_level()
BEGIN
	SELECT min(bfs_level)
	FROM BDSProject.users
	where user_type is null and is_protected=0;	
END//
delimiter ;
users-- ----------------------------------------

-- -------------------Write Procedures---------------------

-- ----------insert_user----------
delimiter //                            
CREATE PROCEDURE BDSProject.insert_user(
	IN in_user_id varchar(24),
	IN in_user_name varchar(60),
	IN in_screen_name varchar(60),
	IN in_user_created_at DATETIME,
	IN in_description varchar(200),
	IN in_is_protected bit,
	IN in_user_lang varchar(6),
	IN in_user_location varchar(150),
	IN in_time_zone varchar(150),
	IN in_status_count int, 
	IN in_favourites_count int,
	IN in_followers_count int,
	IN in_friends_count int ,
	IN in_listed_count int ,
	IN in_bfs_level int,
	IN in_user_type varchar(22),
	IN in_checked_followers bit,
	IN in_date_inserted DATETIME
    )
BEGIN 
	INSERT INTO BDSProject.users (
		user_id,
		user_name,
		screen_name,
		user_created_at,
		description,
		is_protected,
		user_lang,
		user_location,
		time_zone,
		status_count, 
		favourites_count,
		followers_count,
		friends_count,
		listed_count,
		bfs_level,
		checked_followers,
		date_inserted
        ) 
    VALUES (
		in_user_id,
		in_user_name,
		in_screen_name,
		in_user_created_at,
		in_description,
		in_is_protected,
		in_user_lang,
		in_user_location,
		in_time_zone,
		in_status_count, 
		in_favourites_count,
		in_followers_count,
		in_friends_count,
		in_listed_count,
		in_bfs_level,
		in_checked_followers,
		in_date_inserted
        ); 
END//
delimiter ;

-- ----------Insert tweet----------
delimiter //                            
CREATE PROCEDURE BDSProject.insert_tweet (
	IN in_tweet_id varchar(24),
    IN in_created_at datetime,
    IN in_user_id varchar(24),
    IN in_full_text varchar(1000),
    IN in_processed_text varchar(1000),
    IN in_lang varchar(6),
    IN in_num_of_likes int,
    IN in_retweets_count int,
    IN in_retweeted_id varchar(24),
    IN in_retweeted_user_id varchar(24),
    IN in_replied_tweet_id varchar(24), 
    IN in_replied_user_id varchar(24),
    IN in_tweet_type varchar(15),
    IN in_has_media bit
	)
BEGIN 
	INSERT INTO BDSProject.tweets (
	tweet_id,
    created_at,
    user_id,
    full_text,
    processed_text,
    lang,
    num_of_likes,
    retweets_count,
    retweeted_id,
    retweeted_user_id,
    replied_tweet_id, 
    replied_user_id,
    tweet_type,
    has_media
    )
    VALUES (
		in_tweet_id,
		in_created_at,
		in_user_id,
		in_full_text,
		in_processed_text,
		in_lang,
		in_num_of_likes,
		in_retweets_count,
		in_retweeted_id,
		in_retweeted_user_id,
		in_replied_tweet_id, 
		in_replied_user_id,
		in_tweet_type,
		in_has_media
		);
END//
delimiter ;

-- ----------Insert followers----------
delimiter //                            
CREATE PROCEDURE BDSProject.insert_follower (
	IN in_user_id varchar(24),
    IN in_follower_id varchar(24)
	)
BEGIN 
	INSERT INTO BDSProject.followers (
	user_id,
    follower_id
    )
    VALUES (
		in_user_id,
		in_follower_id
		);
END//
delimiter ;

-- ----------Insert mentions----------
delimiter //                            
CREATE PROCEDURE BDSProject.insert_mention (
	IN in_tweet_id varchar(24),
    IN in_user_id varchar(24)
	)
BEGIN 
	INSERT INTO BDSProject.mentions (
	tweet_id,
    user_id
    )
    VALUES (
		in_tweet_id,
		in_user_id
		);
END//
delimiter ;

-- ----------Update user type----------
delimiter //                            
CREATE PROCEDURE BDSProject.update_user_type (
	IN in_user_id varchar(24),
    IN in_user_type varchar(22)
	)
BEGIN 
	UPDATE BDSProject.users
	SET user_type=in_user_type #נראה לי פה צריך להכניס סטרינג שונה כל פעם בסוג המתשמש
	WHERE user_id=in_user_id;# תוהה האם לזה התכוונת???
END//
delimiter ;

-- ----------Update checked followers----------
delimiter //                            
CREATE PROCEDURE BDSProject.update_checked_followers (
	IN in_user_id varchar(24)
	)
BEGIN 
	UPDATE BDSProject.users
	SET checked_followers=1
	WHERE user_id=in_user_id;
END//
delimiter ;



INSERT INTO BDSProject.locations (
	user_location,
    city_name,
    province,
    country,
    country_code,
	latitude, 
    longitude
    )
    VALUES (
		in_user_location,
		in_city_name,
		in_province,
		in_country,
		in_country_code,
		in_latitude, 
		in_longitude
		);