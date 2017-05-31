#!/bin/env python
'''
Duplicates functionality of:

echo ""
echo "Job status on `hostname -f` at `date -Is`"

condor_status -grid
condor_q -globus | grep $1 > /tmp/$1
echo "Total number of jobs on $1              : " `cat /tmp/$1 | wc -l`
echo "Total number of ACTIVE jobs on $1       : " `cat /tmp/$1 | grep ACTIVE | wc -l`
echo "Total number of STAGE_IN/OUT jobs on $1 : " `cat /tmp/$1 | grep STAGE | wc -l`
echo "Total number of PENDING jobs on $1      : " `cat /tmp/$1 | grep PEND | wc -l`
echo "Total number of DONE jobs on $1         : " `cat /tmp/$1 | grep DONE | wc -l`
echo "Total number of UNSUBMITTED jobs on $1  : " `cat /tmp/$1 | grep UNSUB | wc -l`

cat /tmp/$1 | grep PEND | head -1 | awk '{print $1}' | xargs condor_q -l | grep UserLog | xargs cat

condor_q -l $1 | grep UserLog | xargs cat

And provides for deeper status inspection for Condor-G jobs. 
'''
import os
import commands
import logging
import cPickle as pickle
import datetime
import logging

logging.basicConfig()
log = logging.getLogger()
log.setLevel(logging.DEBUG)

CACHEFILE="~/var/condor-grid-info.save"
CQCMD="condor_q -long -xml "

class CacheRecord(object):
    ''' Object to be pickled. Contains all info.'''
    
    def __init__(self):
        self.cqstr = "uninitialized"   # raw output of "condor_q -xml"
        self.doc = "uninitialized"      # Processed xml doc
        self.lastupdate = None
        fullpath = os.path.expanduser(CACHEFILE)
        (dirpath, filename) = os.path.split(fullpath)
        logging.debug("Making dir for cache: %s" % dirpath)
        try:
            os.makedirs(dirpath)
        except OSError:
            pass
        self.cachefile = fullpath
        
    def setcqstr(self, cqstr):
        self.cqstr = cqstr
        self.lastupdate = datetime.now()
       
    def loadCache(self):
        '''
         Loads from saved cache, or creates empty one. ss 
        '''
        try:
            f = open(self.cachefile, 'r')
            info = dir(self)
            log.debug("Info before: %s" % info)
            obj = pickle.load(f)
            info = dir(obj)
            log.debug("Info after: %s" % info)
            f.close()
            return obj
        except IOError:
            return None
            
    def saveCache(self):
        try:
            f = open(self.cachefile, 'w')
            pickle.dump(self, f )
            f.close()
            logging.debug("Dumped to file %s" % file.name )
            return True
        except:
            logging.warn("Ran into error saving to cache")
            return False
    
def getcqinfo():
    (status, output) = commands.getstatusoutput(CQCMD)
    print("Got %d output from command" % len(output))
    return output
    
if __name__=="__main__":
    logging.debug("condor-grid-info.py begin...")
    cr = CacheRecord()  
    cr = cr.loadCache()
    if cr:
        logging.info("Loaded CacheRecord from cache with %d chars" % len(cr.cqstr))
    else:
        logging.info("Running condor-q to get info...")
        cr = CacheRecord()
        cr.cqstr = getcqinfo()
        logging.info("cr.cqstr = %s " % cr.cqstr[:50] )
    cr.saveCache()
    
    
    
    