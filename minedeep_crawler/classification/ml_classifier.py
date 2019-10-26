import sys
import os

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from nltk.corpus import stopwords
from nltk.tokenize import TweetTokenizer
from nltk.stem import PorterStemmer
from sklearn.feature_extraction.text import CountVectorizer
from sklearn.pipeline import Pipeline
from sklearn.linear_model import SGDClassifier
from sklearn.feature_selection import SelectPercentile, chi2
import string
import dateutil.parser as dp
import re
import itertools
import pickle
import logging

from helpers.my_helper import choose_file


class Preproccessing:
    def __init__(self, problems=None):
        """
        This class use to proccess text.
        :param problems: those are chosen token to dismiss when proccessing the training set
        """
        if problems is None:
            self.problems = pd.read_pickle(os.path.join(sys.path[0], 'classification/data/problems.pickle')).tolist()

        else:
            self.problems = problems

        self.tknz = TweetTokenizer()

        self.ps = PorterStemmer()

    def get_tokens(self, text):
        """

        :param text:
        :return:
        """
        return self.tknz.tokenize(text.lower())

    '''
    # Currently Not in use
    def r_names(tokens):
        terms_no_names = [term for term in tokens if '@' not in term]
        tokens = terms_no_names
        return tokens
    '''

    @staticmethod
    def r_one_char(tokens):
        """

        :param tokens:
        :return:
        """
        terms_no_chars = [term for term in tokens if
                          not ((len(term) == 1) and (any("\u0000" <= c <= "\u00FF" for c in term)))]

        return terms_no_chars

    @staticmethod
    def r_punctuation_stopwords(tokens, problems):
        """

        :param tokens:
        :param problems:
        :return:
        """
        punctuation = list(string.punctuation)

        stops = stopwords.words('english') + punctuation + ['rt', 'via'] + problems

        stops.remove('not')

        terms_no_stop = [term for term in tokens if term not in stops]

        return terms_no_stop

    @staticmethod
    def paterns_fixing(tokens):
        """

        :param tokens:
        :return:
        """
        paterns = ["'s", "'d"]
        i = 0

        for term in tokens:
            if any(map(term.__contains__, paterns)):
                tokens[i] = term.replace(next((p for p in paterns if p in term), None), '')

            i = i + 1

        return tokens

    @staticmethod
    def r_hebrew(tokens):
        """

        :param tokens:
        :return:
        """
        temp_tokens = []

        for token in tokens:
            if not any("\u0590" <= c <= "\u05FF" for c in token):
                temp_tokens.append(token)

        return temp_tokens

    @staticmethod
    def r_arabic(tokens):
        """

        :param tokens:
        :return:
        """
        temp_tokens = []

        for token in tokens:
            if not any("\u0600" <= c <= "\u06FF" for c in token):
                temp_tokens.append(token)

        return temp_tokens

    @staticmethod
    def is_date(token):
        """

        :param token:
        :return:
        """
        try:
            dp.parse(token)
            return True

        except Exception:
            return False

    def date_fixing(self, tokens):
        """

        :param tokens:
        :return:
        """
        no_date = [token for token in tokens if not self.is_date(token)]

        return no_date

    @staticmethod
    def is_url(token):
        """

        :param token:
        :return:
        """
        return any(re.findall('http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', token))

    def http_fixing(self, tokens):
        """

        :param tokens:
        :return:
        """
        no_http = [token for token in tokens if not self.is_url(token)]

        return no_http

    @staticmethod
    def numbers_fixing(tokens):
        """

        :param tokens:
        """
        pass  # numbers removing

    @staticmethod
    def negation_fixing(tokens):
        """

        :param tokens:
        :return:
        """
        i = 0
        tokens_end = len(tokens) - 1

        for term in tokens:
            token_position = i

            if "n't" in term:
                tokens[i] = ''

                if not tokens_end >= token_position:  # means last token in tokens
                    tokens.append("not_" + tokens[i + 1])

            if "not" == term and not (tokens_end == token_position):  # means last token in tokens:
                tokens[i + 1] = "not_" + tokens[i + 1]
                tokens[i] = ''

            i = i + 1

        return tokens

    @staticmethod
    def stemming(ps, tokens):
        """

        :param ps:
        :param tokens:
        :return:
        """
        new_tokens = []

        for word in tokens:
            new_tokens.append(ps.stem(word))

        tokens = new_tokens

        return tokens

    def proccess_tweet(self, text):
        """

        :param text:
        :return:
        """
        tokens = self.get_tokens(text)
        tokens = self.paterns_fixing(tokens)
        tokens = self.r_punctuation_stopwords(tokens, self.problems)
        tokens = self.negation_fixing(tokens)
        tokens = self.date_fixing(tokens)
        tokens = self.http_fixing(tokens)
        tokens = self.r_one_char(tokens)
        tokens = self.r_hebrew(tokens)
        tokens = self.r_arabic(tokens)
        # tokens = self.stemming(self.ps, tokens)

        txt = (' '.join(tokens))

        return txt

    def proccess_data(self, texts):
        """

        :param texts:
        :return:
        """
        processed_text = []

        for index in range(0, (len(texts))):
            txt = texts[index]
            processed_text.append(self.proccess_tweet(txt))

        return processed_text

    def get_x_y(self, dataframe):
        """

        :param dataframe:
        :return:
        """
        return dataframe.text, dataframe.cls


class SGDC:
    def __init__(self, data=None):
        """

        :param data:
        """
        if data is None:
            self.data = self.get_data_input(choose_file())

        else:
            self.data = data

        self.data.drop_duplicates(inplace=True)

        self.proccessor = Preproccessing()

        self.count_vect = CountVectorizer(min_df=3,
                                          tokenizer=self.proccessor.tknz.tokenize,
                                          ngram_range=(1, 2),
                                          analyzer='word',
                                          stop_words='english')

        self.sgdc = Pipeline([('pbest', SelectPercentile(chi2, percentile=40)),
                              ('sgdc_svm', SGDClassifier(loss='hinge',
                                                         alpha=0.0010235310218990269,
                                                         penalty='l2',
                                                         max_iter=100, tol=None,
                                                         random_state=4650))])

        self.X, self.Y = self.proccessor.get_x_y(self.data)

        self.X_proccessed = self.proccessor.proccess_data(self.X)

        self.X_vectorized = self.count_vect.fit_transform(self.X_proccessed)

    @staticmethod
    def get_data_input(path):
        """

        :param path:
        :return:
        """
        if 'csv' in path:
            return pd.read_csv(path, header=0, sep='\t',
                               encoding='utf16', engine='python')

        elif 'pickle' in path:
            return pd.read_pickle(path)

    def fit(self):
        """

        """
        self.sgdc.fit(self.X_vectorized, self.Y)

    def predict(self, x):
        """

        :param x:
        :return:
        """
        processed = self.proccessor.proccess_data(x)

        return self.sgdc.decision_function(self.count_vect.transform(processed))


class UserClassifier:
    user_types = ['pro - unactive',
                  'pro - active',
                  'pro - advanced active',
                  'other']

    def __init__(self, supporters=[]):
        """

        :param supporters:
        """
        self.supporters = supporters

        self.ml_classifier = SGDC(data=pd.read_pickle(os.path.join(sys.path[0], 'classification/data/data.pickle')))

        self.ml_classifier.fit()

        with open(os.path.join(sys.path[0], 'classification/data/pro_hashtags.pickle'), 'rb') as handle:
            self.pro_hashtags = pickle.load(handle)

        with open(os.path.join(sys.path[0], 'classification/data/against_hashtags.pickle'), 'rb') as handle:
            self.against_hashtags = pickle.load(handle)

        logging.info('classifier initialized')

    def update_supportes(self, supporter):
        """

        :param supporter:
        """
        self.supporters.append(supporter)

    def check_hashtags(self, tweets):
        """

        :param tweets:
        :return:
        """
        count_pro = 0
        count_against = 0

        for tweet in tweets:
            if any(hashtag in tweet for hashtag in self.pro_hashtags):
                count_pro = count_pro + 1

            if any(hashtag in tweet for hashtag in self.against_hashtags):
                count_against = count_against + 1

        if count_against > 0 and count_pro > 0:
            return None

        if count_against > 0 and count_pro == 0:
            return 'against'

        if count_pro > 0 and count_against == 0:
            return 'pro'

        return None # the other case of both equal to zero

    def retweet_pro(self, tweets):
        """

        :param tweets:
        :return:
        """
        for tweet in tweets:
            try:  # check if a tweet is retweeted. if not, catch the exception
                if tweet._json['retweeted_status']:
                    if tweet.retweeted_status.user.id in self.supporters:
                        return True

            except:
                pass

        return False

    def classify_supporter(self, user_id, tweets, period_length):
        """

        :param tweets:
        :param period_length:
        :return:
        """
        tweets_avg = len(tweets)/period_length
        if tweets_avg > 3:
            # advanced pro
            if user_id not in self.supporters:
                self.supporters.append(user_id)

            logging.info('finish classify user - {} as {}'.format(user_id, self.user_types[2]))

            return self.user_types[2], tweets

        elif tweets_avg > 0.13:
            # active pro
            if user_id not in self.supporters:
                self.supporters.append(user_id)

            logging.info('finish classify user - {} as {}'.format(user_id, self.user_types[1]))

            return self.user_types[1], tweets

        logging.info('finish classify user - {} as {}'.format(user_id, self.user_types[0]))

        return self.user_types[0], []

    def filter_tweets(self, tweets, tweets_prediction):
        pro_count = sum(tweets_prediction > 0)
        ratio = pro_count / len(tweets_prediction)

        if ratio >= 0.8:  # bfs_level=2 --->> 0.7
            tweets = tweets

        elif ratio >= 0.6:  # bfs_level=2 --->> 0.5
            tweets = [tweets[index] for index in np.where(tweets_prediction > 0.0)[0]]  # bfs_level=2 --->> 0.0

        else:
            tweets = [tweets[index] for index in np.where(tweets_prediction >= 0.9)[0]]  # bfs_level=2 --->> 0.65

        return ratio, tweets

    def classify_user(self, user_id, tweets_prediction, tweets, period_length):
        """

        :param tweets_prediction:
        :param tweets:
        :param period_length:
        :return:
        """
        ratio, tweets = self.filter_tweets(tweets, tweets_prediction)

        if ratio >= 0.3:  # bfs_level=2 --->> 17
            return self.classify_supporter(user_id, tweets, period_length)

        else:
            logging.info('finish classify user - {} as {}'.format(user_id, self.user_types[3]))

            return self.user_types[3], []

    def classify(self, user_id, tweets, period_length):
        """

        :param tweets:
        :param lang:
        :param period_length:
        :return:
        """
        logging.info('start classify user - {}'.format(user_id))
        if len(tweets) < 2:
            # pro - anemic user (our base assumption of unactive users are supporting BDS)
            logging.info('finish classify user - {} as {}'.format(user_id, self.user_types[0]))

            return self.user_types[0], []

        for tweet in tweets:
            processed_text = self.ml_classifier.proccessor.proccess_tweet(tweet.full_text)
            setattr(tweet, 'processed_text', processed_text)
            tweet._json['processed_text'] = processed_text

        tweets_text = [tweet.processed_text for tweet in tweets]
        tweets_prediction = self.ml_classifier.predict(tweets_text)

        if self.retweet_pro(tweets):
            # if find a retweet of a supporter tweet, classify as a supporter
            return self.classify_supporter(user_id, self.filter_tweets(tweets, tweets_prediction)[1], period_length)

        hashtags_check = self.check_hashtags(tweets_text)

        if hashtags_check is not None:
            if hashtags_check == 'pro':
                # classify which pro user
                return self.classify_supporter(user_id, self.filter_tweets(tweets, tweets_prediction)[1], period_length)

            if hashtags_check == 'against':
                # other type
                logging.info('finish classify user - {} as {}'.format(user_id, self.user_types[3]))

                return self.user_types[3], []

        return self.classify_user(user_id, tweets_prediction, tweets, period_length)


def plot_confusion_matrix(cm, classes,
                          normalize=False,
                          title='Confusion matrix',
                          cmap=plt.cm.Blues):
    """

    """
    if normalize:
        cm = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis]

    plt.imshow(cm, interpolation='nearest', cmap=cmap)
    plt.title(title)
    plt.colorbar()
    tick_marks = np.arange(len(classes))
    plt.xticks(tick_marks, classes, rotation=45)
    plt.yticks(tick_marks, classes)

    fmt = '.2f' if normalize else 'd'
    thresh = cm.max() / 2.

    for i, j in itertools.product(range(cm.shape[0]), range(cm.shape[1])):
        plt.text(j, i, format(cm[i, j], fmt),
                 horizontalalignment="center",
                 color="white" if cm[i, j] > thresh else "black")

    plt.tight_layout()
    plt.ylabel('True label')
    plt.xlabel('Predicted label')
