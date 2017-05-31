#!/bin/env python
#
# Parse input Panda .out files and calculate iofactor statistics. 
#
# Assumes standard log output:
#
# 22 Feb 23:37:33| pUtil.py    | . CPU consumption time      : 810 s
# 22 Feb 23:37:33| pUtil.py    | . Payload execution time    : 871 s
# 22 Feb 23:37:33| pUtil.py    | . GetJob consumption time   : 0 s
# 22 Feb 23:37:33| pUtil.py    | . Stage-in consumption time : 8 s
# 22 Feb 23:37:33| pUtil.py    | . Stage-out consumption time: 11 s
#
#

import os
import sys
import logging
import getopt


class PandaJob(object):
    
    def __init__(self, cpu, wall, getjob, stagein, stageout):
        log = logging.getLogger()
        self.cputime = float(cpu)
        self.walltime = float(wall)
        self.getjob = float(getjob)
        self.stagein = float(stagein)
        self.stageout = float(stageout)
        
            
       

def handlefiles(files):
    log = logging.getLogger()
    log.info("Handling %d files..." % len(files))
    joblist = []
    for file in files:
        log.debug("file: %s" % file)
        handlefile(file, joblist)
    log.info("Made list of %d jobs." % len(joblist))
    return joblist
    
def handlefile(file, joblist):
    '''
    Get info from file, create job objects, return updated list
    '''
    f = open(file)
    rl = f.readlines()
    log.debug("%d lines in file %s" % (len(rl), file))
    for i in range(0,len(rl)):
        line = rl[i]
        #print(line)
        try:
            if "CPU consumption time" in line:
                fields = line.split()
                log.debug("fields: %s" % fields)
                scpu = fields[10]
                log.debug("cpu is %s" % scpu)
                
                # Handle exec time
                line = rl[i+1]
                fields = line.split()
                swall = fields[10]
                log.debug("wall is %s" % swall)            
                
                # Handle getjob time
                line = rl[i+2]
                fields = line.split()
                sgetjob = fields[10]
                            
                # Handle stagein time
                line = rl[i+3]
                fields = line.split()
                stagein = fields[10]
                
                # Handle stageout time
                line = rl[i+3]
                fields = line.split()            
                stageout = fields[10]
                
                # Construct object and add to list
                try:
                    jobobj = PandaJob( scpu, swall, sgetjob, stagein, stageout)
                    joblist.append(jobobj)
                except ValueError:
                    log.error("input: %s %s %s %s %s " % ( scpu, swall, sgetjob, stagein, stageout))
        except IndexError:
            pass

def iofactorstats(joblist):
    '''
    Calculate mean cputime, mean walltime, and mean cpu/wall
    '''
    n = len(joblist)
    cputot = 0
    walltot = 0
    for j in joblist:
        cputot += j.cputime
        walltot += j.walltime
    cpumean = cputot / float(n)
    wallmean = walltot / float(n)
    iomean = cputot / walltot 
    iofactor = 1.0 - iomean

    print("iofactor= %f meancpu = %f meanwall = %f " % (iofactor, 
                                                        cpumean, 
                                                        wallmean)
          )


def main():
      
    global log
            
    debug = 0
    info = 0
    warn = 0
    logfile = sys.stderr
    outfile = sys.stdout
    fileroot = None
    
    usage = """Usage: embed.py [OPTIONS] FILE1  [ FILE2  FILE3 ] 
   embed-files takes one or more YAML file specifications and merges them, 
   creating a TDL-compatible template file with the file contents embeded.  
   OPTIONS: 
        -h --help                   Print this message
        -d --debug                  Debug messages
        -V --version                Print program version and exit.
        -L --logfile                STDERR
     """

    # Handle command line options
    argv = sys.argv[1:]
    try:
        opts, args = getopt.getopt(argv, 
                                   "hdvL:", 
                                   ["help", 
                                    "debug", 
                                    "verbose",
                                    "logfile=",
                                    ])
    except getopt.GetoptError, error:
        print( str(error))
        print( usage )                          
        sys.exit(1)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print(usage)                     
            sys.exit()            
        elif opt in ("-d", "--debug"):
            debug = 1
        elif opt in ("-v", "--verbose"):
            info = 1
        elif opt in ("-L","--logfile"):
            logfile = arg

    
    major, minor, release, st, num = sys.version_info
    FORMAT24="[ %(levelname)s ] %(asctime)s %(filename)s (Line %(lineno)d): %(message)s"
    FORMAT25="[%(levelname)s] %(asctime)s %(module)s.%(funcName)s(): %(message)s"
    FORMAT26=FORMAT25
    FORMAT27=FORMAT26
    
    if major == 2:
        if minor == 4:
            formatstr = FORMAT24
        elif minor == 5:
            formatstr = FORMAT25
        elif minor == 6:
            formatstr = FORMAT26
        elif minor == 7:
            formatstr = FORMAT27
            
    log = logging.getLogger()
    hdlr = logging.StreamHandler(sys.stdout)
    formatter = logging.Formatter(formatstr)
    hdlr.setFormatter(formatter)
    log.addHandler(hdlr)
    # Handle file-based logging.
    if logfile != sys.stderr:
        ensurefile(logfile)        
        hdlr = logging.FileHandler(logfile)
        hdlr.setFormatter(formatter)
        log.addHandler(hdlr)

    if warn:
        log.setLevel(logging.WARN)
    if debug:
        log.setLevel(logging.DEBUG) # Override with command line switches
    if info:
        log.setLevel(logging.INFO) # Override with command line switches

    log.debug("%s" %sys.argv)
    files = args
    log.debug(files)   
    
    if files:
        jl = handlefiles(files)
        iofactorstats(jl)

if __name__ == "__main__":
    main()