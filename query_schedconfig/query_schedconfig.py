#!/usr/bin/env python

# imports
import getopt
import json
import os
from pprint import pprint as pp
import sys
import urllib2

from PandaQueue import PandaQueue

class MissingPandaResourceException(Exception):
    def __init__(self, panda_resource):
        self.value = "there is no pandaresource %s" %panda_resource
    def __str__(self):
        return self.value

class MissingFiledException(Exception):
    def __init__(self, field):
        self.value = "there is no field %s" %field
    def __str__(self):
        return self.value



class Options(object):
    def __init__(self):
        self.force_reload = False



class SchedConfig(object):

    def __init__(self, opts):

        self.cache = '/tmp/schedconfig.json'

        self.opts = opts

        if not os.path.isfile(self.cache): 
            self.reload()
        if self.opts.force_reload:
            self.reload()
        self.schedconfig_data = self.get_source_data()
        self.panda_resource_l = self.schedconfig_data.keys()


    def reload(self):
        URL = "http://atlas-schedconfig-api.cern.ch/request/pandaqueue/query/list/?json&preset=schedconf.all"
        schedconfig_data = json.load(urllib2.urlopen(URL))
        dest = open(self.cache, 'w')
        json.dump(schedconfig_data, dest)


    def get_source_data(self):
        src = open(self.cache) 
        schedconfig_data = json.load(src)
        return schedconfig_data


    def get_panda_resource_data(self, panda_resource):
        if panda_resource not in self.panda_resource_l:
            raise MissingPandaResourceException(panda_resource)
        return self.schedconfig_data[panda_resource]


    def get_ce_queues_data(self, panda_resource):
        if panda_resource not in self.panda_resource_l:
            raise MissingPandaResourceException(panda_resource)
        return self.schedconfig_data[panda_resource]['queues']


    def list_panda_resources(self):
        return [x['panda_resource'] for x in self.schedconfig_data.values() if x['vo_name']=="atlas"]
     

    def get_field(self, panda_resource, field):
        data = self.get_panda_resource_data(panda_resource)
        if field not in data.keys():
            raise MissingFiledException(field)
        return data[field]


    def get_queue(self, panda_resource):
        """
        creates a PandaQueue object
        """
        data = self.get_panda_resource_data(panda_resource)
        queue = PandaQueue(panda_resource, data)
        return queue


    def get_queue_l(self, *panda_resource_l):
        """
        creates a list of PandaQueue objects
        """
        queue_l = []
        if len(panda_resource_l) == 0:
            panda_resource_l = self.panda_resource_l
        for panda_resource in panda_resource_l:
            queue = self.get_queue(panda_resource)
            queue_l.append(queue)
        return queue_l

    
    def get_queue_l_pattern(self, *panda_resource_patterns)
        """
        same as get_queue_l, but the inputs can be patterns.
        For example, "BNL" means "ANALY_BNL_SHORT", "BNL_PROD", etc
        """
        panda_resource_l = []
        for pattern in panda_resource_patterns:
            for panda_resource in self.panda_resource_l:
                if pattern in panda_resource:
                    panda_resource_l.append(panda_resource)
        queue_l = self.get_queue_l(panda_resource_l)
        return queue_l




    

# =============================================================================

if __name__ == '__main__':
    
    schedconfig_opts = Options()
    try:
        opts, args = getopt.getopt(sys.argv[1:], 
                                   "",
                                   ["reload"]
                                  )
    except getopt.GetoptError, err:
            print str(err)
    for k,v in opts:
            if k == "--reload":
                schedconfig_opts.force_reload = True
                   
    schedconfig = SchedConfig(schedconfig_opts)


    try:
        #pp(schedconfig.get_panda_resource_data('BNL_PROD-condor'))
        #pp(schedconfig.get_ce_queues_data('BNL_PROD-condor'))
        print schedconfig.get_field('BNL_PROD-condor', 'jobseed')
    except Exception, ex:
        print(ex)





