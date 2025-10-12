import logging

def setup_logging(log_path="/var/log/A-M-S.log"):
    logging.basicConfig(filename=log_path, level=logging.INFO, format="%(asctime)s - %(message)s")
