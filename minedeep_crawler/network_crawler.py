#!/usr/bin/env python3.5
import datetime
import time
import os
import argparse
import json
import logging
import sys

from queue_manager import QueuesManager
from api_controller import WorkersManager
from sql_builder import DBExtractor
from classification.ml_classifier import UserClassifier


class Crawler:
    def __init__(self, working_time, start_date, end_date):
        """
        main class
        :param working_time: time to work
        :param db_configurer: database connection params
        """
        with open(os.path.join(sys.path[0], 'config.json'), 'r') as f:
            self.json_file = json.load(f)

        self.sql_tool = DBExtractor(**self.json_file['db_con_params'])
        self.working_time = working_time  # in hours
        self.end_of_day = time.time() + (self.working_time*60*60)
        self.start_time = time.time()
        self.start_date = start_date
        self.end_date = end_date
        self.queue_manager = QueuesManager()
        self.level_to_crawl = self.sql_tool.get_crawl_level()
        if self.level_to_crawl == 1:
            self.level_to_process = 2

        else:
            self.level_to_process = self.sql_tool.get_process_level()

        self.already_processed = list(map(int, self.sql_tool.get_already_processed()))
        self.users_already_in_system = list(map(int, self.sql_tool.get_users_in_sys()))
        self.supporters = list(map(int, self.sql_tool.get_supporters()))
        self.classifier = UserClassifier(self.supporters)

        self.workers_manager = WorkersManager(self.json_file,
                                              start_date,
                                              end_date,
                                              self.end_of_day,
                                              self.level_to_crawl,
                                              self.queue_manager.queue_toCrawl,
                                              self.queue_manager.queue_toProcess,
                                              self.classifier,
                                              self.already_processed,
                                              self.users_already_in_system,
                                              self.json_file['db_con_params'])  # access tokens manager
        logging.info('crawler initialized, crawl_level={}, processing={}'.format(self.level_to_crawl,
                                                                                 self.level_to_process))

    def day_is_finished(self):
        if time.time() > self.end_of_day:
            return True

        else:
            return False

    def finished_crawl(self):
        if self.queue_manager.queue_toCrawl.empty() and self.queue_manager.queue_toProcess.empty():
            return True

        else:
            return False

    def need_to_crawl(self):
        if not self.level_to_crawl == self.level_to_process:
            return True

        else:
            return False

    def backup_db(self, user, password, database):
        logging.info('start database backup')
        BACKUP_DIR = os.path.join(sys.path[0], 'DB_backups')
        BACKUP_FILE_NAME = "MineDeep_backup_"
        FILE_SUFFIX_DATE_FORMAT = "%Y%m%d%H%M%S"
        USERNAME = user
        PASSWORD = password
        DBNAME = database

        # get today's date and time
        timestamp = datetime.datetime.now().strftime(FILE_SUFFIX_DATE_FORMAT)
        backup_filename = BACKUP_DIR + "/" + BACKUP_FILE_NAME + timestamp + ".sql"

        os.system("mysqldump -u " + USERNAME + " --password=" + PASSWORD + " --databases " + DBNAME + " > " +
                  backup_filename)
        logging.info('finished backup')

    def crawl(self):
        self.queue_manager.fill_process_queue(self.sql_tool.get_users_to_process())
        while not self.finished_crawl():
            if not self.day_is_finished():
                if self.need_to_crawl():
                    logging.info('start crawl level = {}'.format(self.level_to_crawl))

                    # crawl
                    self.queue_manager.fill_crawl_queue(self.sql_tool.get_users_to_crawl())
                    self.workers_manager.generate_workers()

                    workers = self.workers_manager.app_workers + self.workers_manager.user_workers

                    for worker in workers:
                        worker.set_to_crawl(True)
                        worker.daemon = True
                        worker.start()

                    self.queue_manager.queue_toCrawl.join()

                    logging.info('finished crawl level = {}'.format(self.level_to_crawl))

                    time.sleep(4)

                    self.level_to_crawl = self.level_to_crawl + 1
                    self.workers_manager.update_bfs_level(self.level_to_crawl)
                    self.workers_manager.close_sql_cons()

                else:
                    self.workers_manager.generate_workers()
                    workers = self.workers_manager.app_workers + self.workers_manager.user_workers

                    for worker in workers:
                        worker.set_to_crawl(False)
                        worker.daemon = True
                        worker.start()

                    self.queue_manager.queue_toProcess.join()

                    time.sleep(4)

                    self.workers_manager.close_sql_cons()

                    self.level_to_process = self.level_to_process + 1

        # work day is finished
        self.sql_tool.con.close()
        logging.info('closed sql con of reader')
        self.backup_db(**self.json_file['db_con_params'])


def valid_date(s):
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%d")

    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)

        raise argparse.ArgumentTypeError(msg)


def initialize_logger(output_dir):
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)
    FILE_SUFFIX_DATE_FORMAT = "%Y%m%d%H%M%S"
    timestamp = datetime.datetime.now().strftime(FILE_SUFFIX_DATE_FORMAT)


    # create console handler and set level to info
    handler = logging.StreamHandler()
    handler.setLevel(logging.INFO)
    formatter = logging.Formatter("'%(asctime)s %(levelname)s %(message)s'")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # create error file handler and set level to error
    error_file_name = timestamp + "_error.log"
    handler = logging.FileHandler(os.path.join(output_dir, error_file_name), "w", encoding=None, delay="true")
    handler.setLevel(logging.ERROR)
    formatter = logging.Formatter("%(levelname)s - %(message)s")
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # create debug file handler and set level to debug
    all_file_name = timestamp + "_all.log"
    handler = logging.FileHandler(os.path.join(output_dir, all_file_name), "w")
    handler.setLevel(logging.INFO)
    formatter = logging.Formatter("'%(asctime)s %(levelname)s %(message)s'")
    handler.setFormatter(formatter)
    logger.addHandler(handler)


if __name__ == '__main__':
    initialize_logger(os.path.join(sys.path[0], 'logging'))
    parser = argparse.ArgumentParser(description='This a social network site crawler')

    parser.add_argument('-t',
                        action='store',
                        dest='running_time',
                        required = True,
                        help='The crawling running time')

    parser.add_argument("-s",
                        dest='start_date',
                        help="Crawling and classification of tweets start date - format YYYY-MM-DD",
                        required=True,
                        type=valid_date)

    parser.add_argument('-e', action='store',
                        dest='end_date',
                        help='Crawling and classification of tweets end date',
                        required=True,
                        type=valid_date)

    results = parser.parse_args()
    my_crawler = Crawler(float(results.running_time), results.start_date, results.end_date)
    my_crawler.crawl()
