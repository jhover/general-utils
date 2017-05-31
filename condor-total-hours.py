#!/bin/env python
#
# Calculates total CPU hours consumed via condor_history
#
#
import subprocess
import logging
import string
import sys


log = logging.getLogger()
formatstr="[%(levelname)s] %(asctime)s %(module)s.%(funcName)s(): %(message)s"
hdlr = logging.StreamHandler(sys.stdout)
formatter = logging.Formatter(formatstr)
hdlr.setFormatter(formatter)
log.addHandler(hdlr)
log.setLevel(logging.DEBUG)

cmd = "condor_history -autoformat  RemoteWallClockTime RequestCpus" 
log.debug("command= '%s'" % cmd)
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
(out, err) = p.communicate()

#log.debug('out = %s' % out)
log.debug('err = %s' % err)

days = 0
hours = 0
minutes = 0
seconds = 0
processed = 0
lineno = 0
lines = out.split('\n')
num = len(lines)
log.info("Got %d lines of output." % num)

for line in lines:
    line = line.strip()
    lineno +=1
    try:
        fields = line.split()
        log.debug(fields)
        val = int(float(fields[0]))
        cores = int(fields[1])
        seconds += val * cores
        processed += 1
    except ValueError:
        log.debug("Line %s value is '%s' " % (lineno, line))


log.debug("%d lines successfully processed." % processed)
log.debug("%d total lines processed." % lineno)
print("Total core-seconds: %s" % seconds)

minutes += seconds / 60
seconds = seconds % 60
hours += minutes / 60
minutes = minutes % 60
days += hours / 24
hours = hours % 24
hours = string.zfill(hours,2)
minutes = string.zfill(minutes,2)
seconds = string.zfill(seconds, 2)

print("Total core-time: %s+%s:%s:%s" % (days, hours, minutes, seconds))






    