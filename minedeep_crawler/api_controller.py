import tweepy
import logging
from threading import Thread
from twitter_collectors import Collector
from sql_builder import DBWriter


class AppWorker(Thread):
    def __init__(self, name, consumer_key, consumer_secret, date_start, date_end, time_to_stop, bfs_level,
                 crawl_queue, process_queue, classifier, already_processed, users_already_in_system, db_configure):
        super().__init__()

        self.name = name
        self.consumer_key = consumer_key
        self.consumer_secret = consumer_secret
        self.date_end = date_end
        self.period_length = (date_end-date_start).days
        self.time_to_stop = time_to_stop
        self.bfs_level = bfs_level
        self.api = self.generate_api()
        self.followers_collect_remain = self.api.rate_limit_status()['resources']['followers']['/followers/ids']['remaining']
        self.tweets_collect_remain = self.api.rate_limit_status()['resources']['statuses']['/statuses/user_timeline']['remaining']
        self.followers_reset_time = self.api.rate_limit_status()['resources']['followers']['/followers/ids']['reset']
        self.tweets_reset_time = self.api.rate_limit_status()['resources']['statuses']['/statuses/user_timeline']['reset']
        self.collector = Collector(date_start, date_end, time_to_stop)
        self.crawl_queue = crawl_queue
        self.process_queue = process_queue
        self.classifier = classifier
        self.already_processed = already_processed
        self.users_already_in_system = users_already_in_system
        self.sql_writer = DBWriter(**db_configure)
        self.to_crawl = None

        logging.info('worker {} initlized'.format(self.name))

    def generate_api(self):
        auth_app = tweepy.AppAuthHandler(self.consumer_key, self.consumer_secret)


        return tweepy.API(auth_app, wait_on_rate_limit=True, wait_on_rate_limit_notify=True)

    def set_to_crawl(self, to_crawl):
        self.to_crawl = to_crawl

    def update_rate_limit(self):
        self.followers_collect_remain = self.api.rate_limit_status()['resources']['followers']['/followers/ids']['remaining']
        self.tweets_collect_remain = self.api.rate_limit_status()['resources']['statuses']['/statuses/user_timeline']['remaining']
        self.followers_reset_time = self.api.rate_limit_status()['resources']['followers']['/followers/ids']['reset']
        self.tweets_reset_time = self.api.rate_limit_status()['resources']['statuses']['/statuses/user_timeline']['reset']

    def filter_users(self, users_ids):
        new_users_ids = [user_id for user_id in users_ids if user_id not in self.users_already_in_system]
        old_users_ids = [user_id for user_id in users_ids if user_id in self.users_already_in_system]

        self.users_already_in_system.extend(new_users_ids)

        return old_users_ids, new_users_ids

    def filter_followers(self, users, followers_list):
        new_users_ids = [user.id for user in users]
        old_users_ids = [user_id for user_id in followers_list if user_id in self.users_already_in_system]

        return new_users_ids + old_users_ids

    def update_processed_queue(self, users):
        for user in users:
            if not user.protected:
                self.process_queue.put(user.id)

    def empty_queues(self):
        if self.to_crawl is True:
            while True:
                self.crawl_queue.get()
                self.crawl_queue.task_done()

        else:
            while True:
                self.process_queue.get()
                self.process_queue.task_done()

    def run(self):
        while True:
            if time.time() < self.time_to_stop:
                if self.to_crawl:
                    # followers = []
                    # Get the id from the queue
                    user_id = self.crawl_queue.get()
                    logging.info('start mine user {} followers '.format(user_id))

                    followers_list, users_to_process = self.collector.collect_followers(user_id, self)
                    logging.info('finished mine user {} followers '.format(user_id))
                    # user_processed -> (user_to_process_id, tweets -> [tweet1, tweet2, .....])
                    # follower_list  -> [(follower id1), (follower id2), ....]

                    old_users_ids, new_users_ids = self.filter_users(followers_list)
                    users = self.collector.collect_users(new_users_ids, self)
                    logging.info('finished collect followers data of user {}'.format(user_id))

                    self.sql_writer.write_users(users, (self.bfs_level + 1))
                    logging.info('finished write followers data to db of user {}'.format(user_id))

                    self.sql_writer.write_followers(user_id, [user.id for user in users] + old_users_ids)
                    logging.info('finished write following data of to follower table of user - {}'.format(user_id))
                    # This allow us to process users in the followers collector

                    self.update_processed_queue(users)
                    logging.info('there are {} users to classify while'
                                 ' getting followers of user - {}'.format(len(users_to_process), user_id))

                    if len(users_to_process) > 0:
                        for user_to_process in users_to_process:
                            user_id, tweets = user_to_process
                            logging.info('(while collecting followers) start classify user {}'.format(user_id))

                            user_type, tweets = self.classifier.classify(user_to_process[1],
                                                                         tweets,
                                                                         self.period_length)
                            logging.info('(while collecting followers) finish classify user {}'.format(user_id))

                            if len(tweets) > 0:
                                logging.info('(while collecting followers) start'
                                             ' insert user {} tweets'.format(user_id))
                                self.sql_writer.write_tweets(tweets)

                                logging.info('(while collecting followers) finished'
                                             ' insert user {} tweets'.format(user_id))

                            self.sql_writer.update_type(user_to_process[0], user_type)

                    self.crawl_queue.task_done()

                else:
                    # Get the id from the queue
                    to_process_id = self.process_queue.get()

                    if to_process_id not in self.already_processed:
                        logging.info('worker {} start process user - {}'.format(self.name, to_process_id))
                        tweets = self.collector.collect_tweets(to_process_id, self)
                        logging.info('tweets collected of user - {}'.format(to_process_id))

                        logging.info('start classify user - {}'.format(to_process_id))
                        user_type, tweets = self.classifier.classify(to_process_id,
                                                                     tweets,
                                                                     self.period_length)
                        logging.info('worker {} finished classify user - {}'.format(self.name, to_process_id))

                        if len(tweets) > 0:
                            logging.info('worker {} start insert user {} tweets'.format(self.name, to_process_id))
                            self.sql_writer.write_tweets(tweets)
                            logging.info('worker {} finished insert user {} tweets'.format(self.name, to_process_id))

                        self.sql_writer.update_type(to_process_id, user_type)

                    self.process_queue.task_done()

            else:
                break

        time.sleep(60)

        self.empty_queues()


class UserWorker(AppWorker):
    def __init__(self, name, consumer_key, consumer_secret, access_token, access_secret, crawl_queue, process_queue,
                 date_start, date_end, time_to_stop, bfs_level, classifier, already_processed, users_already_in_system,
                 db_configure):
        self.access_token = access_token
        self.access_secret = access_secret

        super().__init__(name, consumer_key, consumer_secret, crawl_queue, process_queue, date_start, date_end,
                         time_to_stop, bfs_level, classifier, already_processed, users_already_in_system, db_configure)

        self.api = self.generate_api()

    def generate_api(self):
        auth_user = tweepy.OAuthHandler(self.consumer_key, self.consumer_secret)
        auth_user.set_access_token(self.access_token, self.access_secret)

        return tweepy.API(auth_user, wait_on_rate_limit=True, wait_on_rate_limit_notify=True)


class WorkersManager:
    def __init__(self, json_file, date_start, date_end, time_to_stop, crawl_level, crawl_queue, process_queue,
                 classifier, already_processed, users_already_in_system, db_configure):
        self.date_start = date_start
        self.date_end = date_end
        self.time_to_stop = time_to_stop
        self.bfs_level = crawl_level
        self.json_file = json_file
        self.user_workers = []
        self.app_workers = []
        self.crawl_queue = crawl_queue
        self.process_queue = process_queue  # to process
        self.classifier = classifier
        self.already_processed = already_processed
        self.users_already_in_system = users_already_in_system
        self.db_configure = db_configure
        self.to_crawl = None

        logging.info('workers manager initialized')

    def generate_userWorkers(self):
        for auth in self.json_file['user_tokens']:
            self.user_workers.append(UserWorker(auth['user_name'],
                                                auth['consumer_key'],
                                                auth['consumer_secret'],
                                                auth['access_token'],
                                                auth['access_secret'],
                                                self.date_start,
                                                self.date_end,
                                                self.time_to_stop,
                                                self.bfs_level,
                                                self.crawl_queue,
                                                self.process_queue,
                                                self.classifier,
                                                self.already_processed,
                                                self.users_already_in_system,
                                                self.db_configure))

    def generate_appWorkers(self):
        for auth in self.json_file['app_tokens']:
            self.app_workers.append(AppWorker(auth['app_name'],
                                              auth['consumer_key'],
                                              auth['consumer_secret'],
                                              self.date_start,
                                              self.date_end,
                                              self.time_to_stop,
                                              self.bfs_level,
                                              self.crawl_queue,
                                              self.process_queue,
                                              self.classifier,
                                              self.already_processed,
                                              self.users_already_in_system,
                                              self.db_configure))

    def generate_workers(self):
        self.user_workers.clear()
        self.app_workers.clear()
        self.generate_appWorkers()
        self.generate_userWorkers()

        logging.info('workers manager generate workers')

    def close_sql_cons(self):
        workers = self.app_workers + self.user_workers

        for worker in workers:
            worker.sql_writer.con.close()
            logging.info('closed sql con of worker = {}'.format(worker.name))

    def set_to_crawl(self, to_crawl):
        self.to_crawl = to_crawl

    def update_bfs_level(self, level):
        self.bfs_level = level

