#!/bin/bash -l
#
# Cleans up cache and log files created by caching-wrapper.sh. 
#
# Author: John Hover <jhover@bnl.gov>
#
#
#
# Changable variables. 
CACHE_DIR=/tmp
LOG_ROOT=/tmp
LOG_FILE=/var/log/caching-wrapper-clean.log
DEBUG=0
LOG=1
CACHE_TTL=300    # in seconds 300=5 minutes
LOG_TTL=900     # in seconds 1800=30 minutes

####################Should not change#################3

# cachefiles=`ls $CACHE_DIR/*.cwf 2>/dev/null`
# find /tmp -cmin 5 -name '*.cwf' -print
# find /tmp -cmin +5 -name '*.cwf' -print
# find /tmp -cmin +5 -name '*.cwf' -delete

#
# Handle deletion of cachefiles older than CACHE_TTL value. 
#
cachefiles=`find $CACHE_DIR -maxdepth 1 -name "*.cwf"  2>/dev/null`
# echo $cachefiles

now=`date +%s`
lognow=`date --iso-8601='seconds'`
for cf in $cachefiles; do
	if [ -r $cf ]; then      
        mtime=`stat --format=%Z $cf`
        age=$(($now-$mtime))
        if [ $DEBUG -eq 1 ]; then
            echo "file: $cf mtime: $mtime age: $age"
        fi
        # Delete old cachefiles
        if [ $age -gt $CACHE_TTL ]; then
            if [ $LOG -eq 1 ]; then 
               echo "[$lognow] Cache file: $cf $age seconds old. Deleting..." >> $LOG_FILE
            fi
            rm -f $cf
        else
	        if [ $LOG -eq 1 ]; then 
               echo "[$lognow] Cache file: $cf $age seconds old. Keeping." >> $LOG_FILE
            fi
	   fi
	fi
done 

#
#  Now handle logfiles for each command. Delete logfiles older than LOG_TTL value. 
#
#logroots=`ls -d $LOG_ROOT/cwlog.* 2>/dev/null`
logroots=`find $LOG_ROOT -type d -maxdepth 1 -name "cwlog.*"  2>/dev/null`
now=`date +%s`
lognow=`date --iso-8601='seconds'`

for lr in $logroots; do
    logfiles=`ls $lr/*.log 2>/dev/null`
    logfiles=`find $lr -maxdepth 1 -name "*.log"  2>/dev/null`
	for lf in $logfiles; do
	    if [ -r $lf ]; then
	        mtime=`stat --format=%Z $lf`
	        age=$(($now-$mtime))
	        if [ $DEBUG -eq 1 ]; then
	            echo "file: $lf mtime: $mtime age: $age"
	        fi
	        # Delete old logfiles
	        if [ $age -gt $LOG_TTL ]; then
	            if [ $LOG -eq 1 ]; then 
	               echo "[$lognow] Log file: $lf $age seconds old. Deleting..." >> $LOG_FILE
	            fi
	            rm -f $lf
	        else
	            if [ $LOG -eq 1 ]; then 
	               echo "[$lognow] Log file: $lf $age seconds old. Keeping." >> $LOG_FILE
	            fi
	       fi
	    fi
	done
done 


