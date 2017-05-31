#!/bin/bash
#
# Use this wrapper by changing the name of the real binary to BINARY.real and creating a BINARY 
# symlink to this shell script and choosing a TTL. Any invocation of BINARY will run BINARY.real
# and cache output to CACHE_DIR/BINARY.args.cachefile. Subsequent invocations of BINARY in less than TTL
# seconds will simply cat the cached file. 
#
# Dependencies: This script requires a gridsite install that includes urlencode/urldecode
#
# Author: John Hover <jhover@bnl.gov>
#
# Limitations: 
# -- Because it uses urlencode, and urlencode takes a -m and -d switch, if these are the
# first switches in the actual command, there will be trouble. 
#
# -- It simply passes *all* arguments after the program name to the underlying real binary. So 
# no distinction is made between option arguments and, say, filename arguments. 
#
# -- This wrapper handles quoted arguments properly (i.e. it will pass them through, with the 
# quotes, to the underlying command. But backslashes, escape chars, single quotes, *might not
# be*. Beware, and do testing and log inspection before depending on this.  
#
# -- Commands that get issued with a particular argument only once can lead to cachefile clutter.
# Use the related cw-clean-cron.sh script to tidy up. 
#
# -- Obviously, this wrapper should only be used with *informational* commands. Not any that have
# side effects. 
#
#

# Changable variables. 
CACHE_DIR=/tmp
LOG_ROOT=/tmp
DEBUG=0
LOG=1
TTL=20    # in seconds
CMD_WAIT=15 # in seconds

##################Changes below here should not be necessary##################
# Basic command info
INVOKE_CMD=$0
ARGS=""
for arg ; do
   origlen=${#arg}
   nospace=${arg//' '/''}
   newlen=${#nospace}
   if [ $newlen -lt $origlen ]; then
	  ARGS="$ARGS \"$arg\""
   else
	  ARGS="$ARGS $arg"
   fi
done

FULL_CMD="$INVOKE_CMD $ARGS"
if [ $DEBUG -eq 1 ]; then
    echo "INVOKE_CMD is $INVOKE_CMD $ARGS"
    echo "ARGS is $ARGS"
fi

PROG=$(basename $0)
REAL_BINARY=$0.real

# Other info
REL_BINDIR=$(dirname $0)
INVOKE_DIR=$PWD
cd $REL_BINDIR
SRC_BASE=$PWD
cd $INVOKE_DIR

if [ $# -gt 0 ]; then
    ENCODED_ARGS=`urlencode $ARGS`
else
    ENCODED_ARGS=""
fi

USER_ID=`id -u`
CACHEFILE=$CACHE_DIR/$PROG.$ENCODED_ARGS.$USER_ID.cwf

# Cache flag indicates that an instance is currently running the command. 
# Other instances should continue using the cachefile
#
CACHEFLAG=$CACHE_DIR/$PROG.$ENCODED_ARGS.$USER_ID.cwf.flag

LOG_DIR=$LOG_ROOT/cwlog.$USER_ID
mkdir -p $LOG_DIR
LOGFILE=$LOG_DIR/$PROG.$ENCODED_ARGS.$USER_ID.log

if [ $DEBUG -eq 1 ]; then
	echo "CACHE_DIR is $CACHE_DIR"
	echo "PROG is $PROG"
	echo "REAL_BINARY=$PROG.real"
    echo "ARGS is $ARGS"
    echo "CACHEFILE is $CACHEFILE"
    echo "TTL is $TTL"
    echo "ENCODED_ARGS is $ENCODED_ARGS"
fi

################################
makecachefile () {
    # mktemp --tmpdir=/var/tmp ps.urleargs.XXXXXX

	if [ -r $CACHEFLAG ]; then
		now=`date +%s`
		mtime=`stat --format=%Z $CACHEFLAG`
		age=$(($now-$mtime))
	    if [ $age -gt $CMD_WAIT ]; then
	    	rm -f $CACHEFLAG
	        if [ $LOG -eq 1 ]; then
               echo "[$lognow] Found old cacheflag file. Deleting it. Skipping execution." >> $LOGFILE
            fi	    	
	    else
	       if [ $DEBUG -eq 1 ]; then
             echo "Found cacheflag file. Skipping execution."
           fi
	       if [ $LOG -eq 1 ]; then
               echo "[$lognow] Found cacheflag file. Skipping execution." >> $LOGFILE
           fi
	    fi   
	else
        if [ $LOG -eq 1 ]; then
               echo "[$lognow] No cacheflag file. Executing command." >> $LOGFILE
        fi  
	    touch $CACHEFLAG
	    if [ $DEBUG -eq 1 ] ; then
	    	 echo "mktemp --tmpdir=$CACHE_DIR $PROG.$ENCODED_ARGS.$USER_ID.cwf.XXXXX"
	    fi
	    TMPFILE=`mktemp -p $CACHE_DIR $PROG.$ENCODED_ARGS.cachefile.XXXXX`
	    #
	    # The -p arg is deprecated, but necessary on RHEL3/4
	    # New opt is --tmpdir. Use when possible. 
	    #
	    #TMPFILE=`mktemp --tmpdir=$CACHE_DIR $PROG.$ENCODED_ARGS.cachefile.XXXXX`
	    if [ $DEBUG -eq 1 ]; then
	        echo "Invoking $REAL_BINARY $ARGS > $TMPFILE "
	    fi
	    eval $REAL_BINARY $ARGS > $TMPFILE 
	    mv $TMPFILE $CACHEFILE
	    rm -f $CACHEFLAG
	    cat $CACHEFILE
	    
	fi
}



main () {
	if [ -r $CACHEFILE ]; then
		now=`date +%s`
		lognow=`date --iso-8601='seconds'`
		mtime=`stat --format=%Z $CACHEFILE`
	    age=$(($now-$mtime))
	    if [ $DEBUG -eq 1 ]; then
	        echo "mtime is $mtime"
	        echo "Age is $age"
	    fi 
	    if [ $age -lt $TTL ]; then
	        if [ $DEBUG -eq 1 ]; then 
	    	   echo "CACHE HIT!!!!"
	        fi
	        if [ $LOG -eq 1 ]; then
	           echo "[$lognow] Cache hit. Args: $ARGS" >> $LOGFILE
	        fi
            cat $CACHEFILE  	   
	    	exit 0
	    else
	        if [ $DEBUG -eq 1 ]; then 
	           echo "STALE CACHE"
	        fi
            if [ $LOG -eq 1 ]; then
               echo "[$lognow] Stale cache. Renew. Args: $ARGS" >> $LOGFILE
            fi        
	        makecachefile 
	        exit 0 
	    fi
	else
	        if [ $DEBUG -eq 1 ]; then 
	           echo "CACHE MISS"
	        fi
            if [ $LOG -eq 1 ]; then
               echo "[$lognow] Cache miss. Renew. Args: $ARGS" >> $LOGFILE
            fi    
	    makecachefile
	fi    
}

main

