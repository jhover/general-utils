#!/usr/bin/env python

class PandaQueue(object):
    def __init__(self, queue, rawdata):
        """
        :param queue: panda queue name
        :param rawdata: dict from schedconfig for this queue
        """
        self.queue = queue
        self.rawdata = rawdata
    
