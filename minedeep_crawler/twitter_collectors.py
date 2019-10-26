import tweepy
import datetime
import time
import logging


class Collector:
    def __init__(self, date_start, date_end, time_to_stop):
        self.time_to_stop = time_to_stop
        self.date_start = date_start
        self.date_end = date_end

    def filter_en_users(self, users):
        return [user for user in users if user.lang == 'en']

    def collect_users(self, users_ids, worker):
        users_data = []

        while len(users_ids) > 0:
            while True:
                try:
                    temp_users = worker.api.lookup_users(users_ids[0:100])

                    users_data.extend(temp_users)

                    users_ids[0:100] = []
                    break
                except tweepy.error.TweepError as e:
                    logging.error('lookup for users: ' + e.reason)
                    logging.info('{}'.format(str(users_ids[0:100])))

                    time.sleep(30)

            logging.info('get users data of {} users'.format(len(users_data)))

        return self.filter_en_users(users_data)

    def collect_followers(self, user_id, worker):
        '''
        :param user_id:
        :param worker:
        :return:
        '''
        ids = []
        tweets = []
        processed_users = []
        cursor = -1

        while not cursor == 0:
                if worker.followers_collect_remain == 0:

                    if worker.tweets_collect_remain == 0 > time.time() and self.time_to_stop > time.time():
                        logging.warning('no more tweets and followers requests'
                                        ' to make of worker - {}'.format(worker.name))

                        time.sleep(min(worker.followers_reset_time, worker.tweets_reset_time) + 5)
                        worker.update_rate_limit()

                    elif self.time_to_stop > time.time() and worker.followers_reset_time > time.time():
                        # get a user from process queue and collect tweets
                        if not worker.process_queue.empty():
                            processed_user_id = worker.process_queue.get()
                            logging.info('workr {} start process user - {}'.format(worker.name, processed_user_id))

                            tweets = self.collect_tweets(processed_user_id, worker)

                            processed_users.append((processed_user_id, tweets))

                            worker.process_queue.task_done()
                        else:
                            logging.warning('''no get_followers requests and processed queue is empty, already {} 
                                            users were collected'''.format(len(ids)))
                            time.sleep(60)

                            if time.time() > worker.followers_reset_time:
                                worker.update_rate_limit()

                    elif worker.followers_reset_time < time.time():
                        worker.update_rate_limit()

                    else:
                        logging.warning('followers requests to make of worker - {}'.format(worker.name))
                        time.sleep(worker.followers_reset_time + 5)

                        worker.update_rate_limit()
                else:
                    while True:
                        try:
                            response = worker.api.followers_ids(id=user_id, cursor=cursor, count=5000)

                            break

                        except tweepy.error.TweepError as e:
                            logging.error('error while sending api request of followers of user - {}: '.format(user_id)
                                          + e.reason)

                            if 'Not authorized' in e.reason:
                                response = ([], (0, 0))
                                break

                            time.sleep(10)

                    worker.followers_collect_remain = worker.followers_collect_remain - 1

                    ids.extend(response[0])
                    cursor = response[1][1]

        return ids, processed_users

    def proccess_tweets(self, tweets):
        for tweet in tweets:
            if hasattr(tweet, 'retweeted_status'):
                tweet._json['full_text'] = tweet.retweeted_status.full_text

                setattr(tweet, 'full_text', tweet.retweeted_status.full_text)

        return tweets

    def collect_tweets(self, user_id, worker):
        worker.already_processed.append(user_id)

        timeline_tweets = []
        stop = False
        i = 1

        while not stop:
            if worker.tweets_collect_remain == 0:
                time.sleep(worker.tweets_reset_time)
                worker.update_rate_limit()

            if time.time() > worker.tweets_reset_time:
                worker.update_rate_limit()

            while True:
                try:
                    tweets_pulled = worker.api.user_timeline(id=user_id, count=200, tweet_mode='extended', page=i)

                    break

                except tweepy.error.TweepError as e:
                    logging.error('user timeline problem id user - {}: '.format(user_id) + e.reason)
                    if 'Not authorized' in e.reason or 'User not found' in e.reason:
                        return []

                    if 'that page does not exist.' in e.reason:
                        return self.proccess_tweets(timeline_tweets)

                    time.sleep(10)

            worker.tweets_collect_remain = worker.tweets_collect_remain - 1

            if not tweets_pulled:
                break

            for tweet in tweets_pulled:
                if tweet.created_at >= self.date_start:
                    if tweet.lang == 'en':
                        if tweet.created_at <= self.date_end:
                            timeline_tweets.append(tweet)

                else:
                    stop = True

                    break

            i = i + 1

        return self.proccess_tweets(timeline_tweets)



