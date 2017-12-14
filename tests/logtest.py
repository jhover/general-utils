#!/bin/env python
print("Logging testing.")

import logging

logging.info("info  test")
logging.warn("warn test")

log = logging.getLogger()
log.setLevel(logging.DEBUG)

log.info("info test2")

log2 = logging.getLogger('mylibrary')
log2.info("info test 3")
log2.debug("debug test 3")
log2.setLevel(logging.WARN)
log2.debug("debug test 4")