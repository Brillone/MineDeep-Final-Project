import mysql.connector
import datetime
import logging


class DBExtractor:
    def __init__(self, user, password, database):
        """
        This class is connected to the oltp database and query data to maintaine the crawler operations.
        The class get the known supporters list, users already in the system, users to crawl, users to process list,
        users to crawl list, crawl level and process level.
        :param user: server user name
        :param password: server password
        :param database: database to connect
        """
        try:
            self.con = mysql.connector.connect(user=user, password=password, database=database, charset='utf8mb4')

        except mysql.connector.Error as e:
             logging.error('dbextractor connecting problem: ' + str(e))

        logging.info('dbextractor initialized')

    def get_already_processed(self):
        """
        Get users ids of users whom already been processed by the crawler.
        :return: return ids list
        """
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        already_processed = []
        try:
            # use get_already_processed SP to pull data
            cur.callproc('BDSProject.get_already_processed')
            already_processed.extend([i[0] for i in list(next(cur.stored_results()))])

        except mysql.connector.Error as e:
             logging.error('getting already processed users problem: ' + str(e))

        cur.close()

        return already_processed

    def get_supporters(self):
        """
        Get users ids of users whom been processed and classified as supporters of the BDS by the crawler.
        :return: return ids list
        """
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        supporters = []
        try:
            # use get_supporters SP to pull data
            cur.callproc('BDSProject.get_supporters')
            supporters.extend([i[0] for i in list(next(cur.stored_results()))])
        except mysql.connector.Error as e:
             logging.error('getting supporters problem: ' + str(e))

        cur.close()

        return supporters

    def get_users_to_process(self):
        """
        Get users ids of users whom been pulled and not been processed yet and are among the users in the
        processlevel being processed right now.
        :return: return ids list
        """
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        users_to_process = []
        try:
            # get_users_to_process SP to pull data
            cur.callproc('BDSProject.get_users_to_process')
            users_to_process.extend([i[0] for i in list(next(cur.stored_results()))])

        except mysql.connector.Error as e:
             logging.error('getting users to process problem: ' + str(e))

        cur.close()

        return users_to_process

    def get_users_in_sys(self):
        """
        Get users ids of users whom been processed and classified by the crawler and there is no need to process
        them again. This help reduce th double work by the crawler.
        :return: return ids list
        """
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        users_to_process = []
        try:
            # get_all_users SP to pull data
            cur.callproc('BDSProject.get_all_users')
            users_to_process.extend([i[0] for i in list(next(cur.stored_results()))])

        except mysql.connector.Error as e:
             logging.error('getting users to process problem: ' + str(e))

        cur.close()

        return users_to_process

    def get_users_to_crawl(self):
        self.con.ping(reconnect=True)

        cur = self.con.cursor()

        users_to_crawl = []
        try:
            cur.callproc('BDSProject.get_users_to_crawl')
            users_to_crawl.extend([i[0] for i in list(next(cur.stored_results()))])

        except mysql.connector.Error as e:
             logging.error('getting users to crawl problem: ' + str(e))

        cur.close()

        return users_to_crawl

    def get_crawl_level(self):
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        try:
            cur.callproc('BDSProject.get_crawl_level')
            level_to_crawl = list(next(cur.stored_results()))[0][0]

        except mysql.connector.Error as e:
             logging.error('getting crawl level problem: ' + str(e))

        cur.close()

        return level_to_crawl

    def get_process_level(self):
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        try:
            cur.callproc('BDSProject.get_process_level')
            level_to_process = list(next(cur.stored_results()))[0][0]

        except mysql.connector.Error as e:
             logging.error('getting process level problem: ' + str(e))

        cur.close()

        if level_to_process:
            return level_to_process


class DBWriter:
    def __init__(self, user, password, database):
        try:
            self.con = mysql.connector.connect(user=user, password=password, database=database, charset='utf8mb4')

        except mysql.connector.Error as e:
             logging.error('dbwriter connecting problem: ' + str(e))

    def write_users(self, users, bfs_level):
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        for user in users:
            try:
                args = (user.id_str, user.name, user.screen_name, user.created_at.strftime('%Y-%m-%d %H:%M:%S'),
                        user.description, int(user.protected), user.lang, empty_str(user.location), user.time_zone,
                        user.statuses_count, user.favourites_count, user.followers_count, user.friends_count,
                        user.listed_count, bfs_level, None, 0, datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
                cur.callproc('BDSProject.insert_user', args)
                logging.info('insert user - {} to database'.format(user.id))

            except mysql.connector.Error as e:
                logging.error('error on user {}: '.format(user.id) + str(e))

        self.con.commit()

        cur.close()

    def write_followers(self, user_id, followers_ids):
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        for follower_id in followers_ids:
            try:
                args = (user_id, follower_id)
                cur.callproc('BDSProject.insert_follower', args)

            except mysql.connector.Error as e:
                 logging.error('insert followers problem of user - {} and follower - {}: '.format(user_id,
                                                                                                  follower_id) + str(e))
        self.con.commit()

        try:
            cur.callproc('BDSProject.update_checked_followers', (user_id,))

        except mysql.connector.Error as e:
             logging.error('update checked followers problem of user - {}: '.format(user_id) + str(e))

        self.con.commit()

        cur.close()

    def write_tweets(self, tweets):
        self.con.ping(reconnect=True)
        cur = self.con.cursor()

        for tweet in tweets:
            type = 'tweet'

            if tweet.in_reply_to_user_id_str is not None:
                reply_to_user_id = tweet.in_reply_to_user_id_str
                reply_to_tweet_id = tweet.in_reply_to_status_id_str
                type = 'reply'

            else:
                reply_to_user_id = None
                reply_to_tweet_id = None

            ids_mentions = set([mention['id'] for mention in tweet.entities['user_mentions']])

            if 'media' in tweet.entities:
                has_media = 1

            else:
                has_media = 0

            if hasattr(tweet, 'retweeted_status'):
                type = 'retweet'

                retweeted_id = tweet.retweeted_status.id_str
                retweeted_user_id = tweet.retweeted_status.user.id_str

            else:
                # enter regular tweet or reply
                retweeted_id = None
                retweeted_user_id = None

            try:
                tweet_args = (tweet.id_str, tweet.created_at.strftime('%Y-%m-%d %H:%M:%S'), tweet.user.id_str,
                              tweet.full_text, tweet.processed_text, tweet.lang, tweet.favorite_count,
                              tweet.retweet_count, retweeted_id,
                              retweeted_user_id, reply_to_tweet_id, reply_to_user_id, type,
                              has_media)
                cur.callproc('BDSProject.insert_tweet', tweet_args)

            except mysql.connector.Error as e:
                 logging.error('insert problem of tweet id - {}: '.format(tweet.id) + str(e))

            if len(ids_mentions) > 0:
                for id_mention in ids_mentions:

                    try:
                        args_mention = (tweet.id_str, id_mention)
                        cur.callproc('BDSProject.insert_mention', args_mention)

                    except mysql.connector.Error as e:
                         logging.error('insert mention problem of tweet id- {}: '.format(tweet.id) + str(e))

        self.con.commit()

        cur.close()

    def update_type(self, user_id, type):
        self.con.ping(reconnect=True)
        cur = self.con.cursor()
        args = (user_id, type)

        logging.info('start update user - {}'.format(user_id))

        try:
            cur.callproc('BDSProject.update_user_type', args)

        except mysql.connector.Error as e:
             logging.error('update type problem of user id - {}: '.format(user_id) + str(e))

        logging.info('finished update user - {}'.format(user_id))
        self.con.commit()

        cur.close()


def empty_str(s):
    if len(s) == 0:
        return None

    else:
        return s



