#!/bin/bash
# 
# Cron script to backup all Subversion repositories for automated backup.
# Script normally has no output.
# author: John Hover <jhover@bnl.gov>

# Set the following variables. No trailing /.
SVNDIR=/var/svn
OUTDIR=/var/backup/svn

#############################
# Do not edit below
#############################
DATE=`date +"%Y%m%d"`
REPOS=`ls $SVNDIR`

mkdir -p $OUTDIR
for r in $REPOS; do 
    svnadmin dump $SVNDIR/$r > $OUTDIR/$r.$DATE.dmp 2>/dev/null
    mv $OUTDIR/$r.$DATE.dmp  $OUTDIR/$r.dmp    
done
