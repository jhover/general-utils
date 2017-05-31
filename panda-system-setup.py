#!/bin/env python
#
# quick script to set up gridui* hosts
#
#  RECIPE FOR JDK DEP PROBLEM
# 1) rpm -e --nodeps jdk
# 2) rpm -e --nodeps java-1.5.0-sun-compat (if you have one)
# 3) yum -y install xml-commons-apis
# 4) yum install java-1.5.0-sun-compat (and jdk as dependences)
# 5) yum update 
#
#
#
#
#
# Add channels in Redhat Satellite:
# bnl-contrib-ws4
# X racf-atlas-dashboard-ws4
# X racf-atlas-ddm-external-ws4
# X racf-atlas-ddm-ws4
# racf-dag-ws4
# racf-glite31-externals-ws4
# racf-glite31-release-ws4
# racf-glite31-updates-ws4
# racf-jpackage17-generic-free-ws4
# racf-lcg-ca-ws4
# rhel-i386-ws-4
# rhel-i386-ws-4-extras
# rhel-i386-ws-4-fastrack
# rhn-tools-rhel-4-ws-i386
#
# Disable selinux /etc/syscong/selinux
#
import os
import sys
import commands

RPMDIR='/afs/usatlas.bnl.gov/mgmt/src/sl4-panda'
SETUPDIR='/afs/usatlas.bnl.gov/mgmt/etc/gridui.usatlas.bnl.gov'
INSIDENETS="185 80"
OUTSIDENETS="54"


def ensure_account(username, uid, groupname, gid, comment, homedir, shell ): 
    '''
    Checks for presence of account and group, adds if necessary, succeeds if exists, error
    if partially true. 
        
    '''

    print "Checking for %s account status..." % username
    (status,acctinfo)=commands.getstatusoutput('cat /etc/passwd | grep "^%s:"' % username)
    (status,grpinfo)=commands.getstatusoutput('cat /etc/group | grep "^%s:"' % groupname)

    if grpinfo:
        print "Local %s group already exists." % groupname
    else:
        print "Needs local usatlas group. Creating..."
        f = open('/etc/group','a')
        f.write("%s:x:%s:\n" % (groupname, gid))
        f.close()

    if acctinfo: 
        print "Local sm account already exists."
    else:
        print "Needs local sm account. Creating..."
        f = open('/etc/passwd','a')
        f.write("%s:x:%s:%s:%s:%s:%s" % (username, uid, gid, comment, homdir, shell))
        f.close() 
    
    if os.path.isdir(homedir):
        print "Home directory already exists for sm."
    else:
        print "Creating SM home directory from /etc/skel..."
        (status,output) = commands.getstatusoutput('cp -r /etc/skel %s' % homedir)
        (status, output) = commands.getstatusoutput('chown -R %s:%s %s' % (username, groupname, homedir)
    
    
    if os.path.isfile('%s/.ssh/authorized_keys' % homedir): 
        print "%s authorized_keys already exists. Done." % username
    else:
        print "sm authorized_keys needed"
        os.mkdir("%s/.ssh" % homedir )
        cp $SETUPDIR/authorized_keys.sm /home/sm/.ssh/authorized_keys
        chown -R sm:usatlas /home/sm/.ssh
    


ensure_usatlas1() 

    print "Checking for usatlas1 account status..."
    acctinfo=`cat /etc/passwd | grep "^usatlas1:"`
    #print $acctinfo

    grpinfo=`cat /etc/group | grep "^usatlas:"`

    if [ "$grpinfoX" != "X" ] : 
            print "Local usatlas group already exists."
    else
            print "Needs local usatlas group. Creating..."
        print "usatlas:x:31152:" >> /etc/group
    

    if [ "$acctinfoX" != "X" ] : 
            print "Local usatlas1 account already exists."
    else
        print "Needs local usatlas1 account. Creating..."
        print "usatlas1:x:6435:31152:USAtlas Production Account:/usatlas/grid/usatlas1:/bin/tcsh" >> /etc/passwd
    

    if [ -d "/home/usatlas1" ]: 
            print "Home directory already exists for usatlas1."
    else
            print "Creating usatlas home directory from /etc/skel..."
            cp -r /etc/skel /home/usatlas1
            chown -R usatlas1 /home/usatlas1
    
    
    if [ -f "/home/usatlas1/.ssh/authorized_keys" ]: 
        print "usatlas1 authorized_keys already exists. Done."
    else
        print "usatlas1 authorized_keys needed"
        mkdir -p /home/usatlas1/.ssh
        cp $SETUPDIR/authorized_keys.usatlas1 /home/usatlas1/.ssh/authorized_keys
        chown -R usatlas1:usatlas /home/usatlas1/.ssh
    



ensure_lcgca()

    print "Checking for lcg-CA installation..." 
    print up2date --nosig lcg-CA
    up2date --nosig lcg-CA



ensure_rpms() 

    print "Adding required RPMs..."
    print rpm --import /afs/usatlas.bnl.gov/lcg/mgmt/etc/GPG-KEYS/*
    rpm --import /afs/usatlas.bnl.gov/lcg/mgmt/etc/GPG-KEYS/*
    
    print rpm -Uvh $RPMDIR/*.rpm
    rpm -Uvh $RPMDIR/*.rpm

    print up2date mod_ssl mod_python httpd httpd-devel MySQL-python lcg-CA 
    up2date --nosig httpd subversion mod_ssl mod_python httpd-devel MySQL-python rrdtool openmpi-devel openmpi-libs openmpi 


    print "Double checking gridsite..."
    rpm -Uvh $RPMDIR/gridsite/gridsite-*.rpm


ensure_condor_user()

    print "Checking for sm account status..."
    cacctinfo=`cat /etc/passwd | grep "^condor:"`
    cgrpinfo=`cat /etc/group | grep "^rhstaff:"`

    if [ "$cgrpinfoX" != "X" ] : 
            print "Local rhstaff group already exists."
    else
        print "Needs local rhstaff group. Creating..."
        print "rhstaff:x:31016:" >> /etc/group
    

    if [ "$cacctinfoX" != "X" ] : 
            print "Local condor account already exists."
    else
           print "Needs local condor account. Creating..."
           print "condor:x:31020:31016:Condor Service Account:/home/sm:/bin/bash" >> /etc/passwd
    

    if [ -d "/home/condor" ]: 
            print "Home directory already exists for condor."
    else
            print "Creating condor home directory from /etc/skel..."
            cp -r /etc/skel /home/condor
            chown -R condor:rhstaff /home/condor
    





ensure_condor()


    print Setting up condor...
    export CONDOR_CONG=/opt/condor-7.0.2/etc/condor_cong 
    if [ -f /etc/init.d/condor ]: 
        /etc/init.d/condor stop
    
    sleep 10
    print "Checking for condor user..."
    ensure_condor_user

    print "Installing/Upgrading Condor..."
    rpm  -Uvh $RPMDIR/condor/condor-7.0.2*.rpm
    rm -rf /etc/condor
    rm -rf /home/condor
    rm -f /etc/prole.d/condor*
    print mkdir -p /home/condor/local/atlas/ /var/condor/local/atlas/log /var/condor/local/atlas/spool 
    mkdir -p /home/condor/local/atlas/ /var/condor/local/atlas/log/GridLogs /var/condor/local/atlas/spool /home/condor/local/atlas/execute
    cp $SETUPDIR/condor_cong /opt/condor-7.0.2/etc/condor_cong
    print cp $SETUPDIR/condor_cong.local /home/condor/local/atlas/
    cp $SETUPDIR/condor_cong.local /home/condor/local/atlas/
    print cp $SETUPDIR/condor_cong.local.eightvm /home/condor/local/atlas/
    cp $SETUPDIR/condor_cong.local.eightvm /home/condor/local/atlas/
    print chown -R condor:rhstaff /var/condor /home/condor
    chown -R condor:rhstaff /var/condor /home/condor
    print cp $SETUPDIR/condor.init /etc/init.d/
    cp $SETUPDIR/condor.init /etc/init.d/condor
    chmod +x /etc/init.d/condor
    print "Setting up condor prole les..."
    cd /etc/prole.d/ : ln -s /opt/condor-7.0.2/condor.sh ./
    cd /etc/prole.d/ : ln -s /opt/condor-7.0.2/condor.csh ./
    print "Setting condor to start at boot..."
    chkcong condor on
    /etc/init.d/condor start
    sleep 15
    print "Checking for running condor executables..."
    ps aux | grep condor | grep -v grep


ensure_java()

    print "Installing required Java..."
    rpm -e --nodeps jdk
    rpm -e --nodeps java-1.5.0-sun-compat
    rpm -Uvh $RPMDIR/java/*.rpm
    up2date java-1.5.0-sun-compat
    rpm -e --nodeps j2re



ensure_glite()

    print "Setting up gLite..."
    print up2date --nosig glite-UI
    up2date --nosig glite-UI

    print /opt/glite/yaim/bin/yaim -c  -s $SETUPDIR/site-info.def.glite.gridui0X -n glite-UI
    /opt/glite/yaim/bin/yaim -c  -s $SETUPDIR/site-info.def.glite.gridui0X -n glite-UI
    
    print "Getting rid of j2re..."
    rpm -e --nodeps j2re
    up2date --nosig gridsite-apache


disable_selinux()

    print "Setting SELinux to disabled..."
    sysconfigstring='''# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#    enforcing - SELinux security policy is enforced.
#    permissive - SELinux prints warnings instead of enforcing.
#    disabled - SELinux is fully disabled.
SELINUX=disabled
# SELINUXTYPE= type of policy in use. Possible values are:
#    targeted - Only targeted network daemons are protected.
#    strict - Full SELinux protection.
SELINUXTYPE=targeted''' 
    f = open('/etc/sysconfig/selinux','w')
    f.write(sysconfigstring)
    f.close()


def ensure_dq2():

    print "Setting up dq2..."
    print up2date --nosig dq2-clientapi-cli dq2-common-client-curl
    up2date --nosig dq2-clientapi-cli dq2-common-client-curl
    . /opt/dq2/prole.d/dq2_common_post_install.sh



def update_system():
    print "Updating OS via up2date..."
    (status, output) = commands.getstatusoutput("up2date --nosig -u")
    print output


if __name__ == '__main__':
    
    
    print "Panda system setup script..."
     
    ensure_account(
    #disable_selinux
    #ensure_lcgca
    #ensure_condor
    #ensure_rpms
    #ensure_java
    #ensure_glite
    #ensure_dq2
    #update_system



