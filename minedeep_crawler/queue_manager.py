from queue import Queue
import logging


class QueuesManager:
    def __init__(self):
        self.queue_toCrawl = Queue()  # only create the queue object
        self.queue_toProcess = Queue()  # only create the queue object
        logging.info('queue manager initialized')

    def fill_crawl_queue(self, users_to_crawl):
        for user_id in users_to_crawl:
            self.queue_toCrawl.put(user_id)

        logging.info('crawl queue was filled')

    def fill_process_queue(self, users_to_process):
        for user_id in users_to_process:
            self.queue_toProcess.put(user_id)

        logging.info('process queue was filled')

    def fill_queues(self, users_to_crawl, users_to_process):
        self.fill_crawl_queue(users_to_crawl)
        self.fill_process_queue(users_to_process)