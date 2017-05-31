#!/bin/bash
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
# Disable selinux /etc/sysconfig/selinux
#

RPMDIR=/afs/usatlas.bnl.gov/mgmt/src/sl4-panda
SETUPDIR=/afs/usatlas.bnl.gov/mgmt/etc/gridui.usatlas.bnl.gov
IPTABLESGREP="20000:30000"
IPTABLESRULE="[0:0] -A INPUT -p tcp -m state --state NEW -m tcp --dport 20000:30000 -j ACCEPT"
INSIDENETS="185 80"
OUTSIDENETS="54"


ensure_sm() 
{
    echo "Checking for sm account status..."
	acctinfo=`cat /etc/passwd | grep "^sm:"`
	#echo $acctinfo

	grpinfo=`cat /etc/group | grep "^usatlas:"`

	if [ "${grpinfo}X" != "X" ] ; then
    		echo "Local usatlas group already exists."
	else
    		echo "Needs local usatlas group. Creating..."
		echo "usatlas:x:31152:" >> /etc/group
	fi

	if [ "${acctinfo}X" != "X" ] ; then
    		echo "Local sm account already exists."
	else
    		echo "Needs local sm account. Creating..."
		echo "sm:x:8989:31152:Panda Service Account:/home/sm:/bin/tcsh" >> /etc/passwd
		echo "sm:!!:13954:0:99999:7:::" >> /etc/shadow
	fi

	if [ -d "/home/sm" ]; then
    		echo "Home directory already exists for sm."
	else
    		echo "Creating SM home directory from /etc/skel..."
    		cp -r /etc/skel /home/sm
    		chown -R sm:usatlas /home/sm
	fi
    
    if [ -f "/home/sm/.ssh/authorized_keys" ]; then
        echo "sm authorized_keys already exists. Done."
    else
        echo "sm authorized_keys needed"
        mkdir -p /home/sm/.ssh
        cp $SETUPDIR/authorized_keys.sm /home/sm/.ssh/authorized_keys
    	chown -R sm:usatlas /home/sm/.ssh
    fi
}

ensure_usatlas1() 
{
    echo "Checking for usatlas1 account status..."
	acctinfo=`cat /etc/passwd | grep "^usatlas1:"`
	#echo $acctinfo

	grpinfo=`cat /etc/group | grep "^usatlas:"`

	if [ "${grpinfo}X" != "X" ] ; then
    		echo "Local usatlas group already exists."
	else
    		echo "Needs local usatlas group. Creating..."
		echo "usatlas:x:31152:" >> /etc/group
	fi

	if [ "${acctinfo}X" != "X" ] ; then
    		echo "Local usatlas1 account already exists."
	else
        echo "Needs local usatlas1 account. Creating..."
        echo "usatlas1:x:6435:31152:USAtlas Production Account:/usatlas/grid/usatlas1:/bin/tcsh" >> /etc/passwd
	fi

	if [ -d "/home/usatlas1" ]; then
    		echo "Home directory already exists for usatlas1."
	else
    		echo "Creating usatlas home directory from /etc/skel..."
    		cp -r /etc/skel /home/usatlas1
    		chown -R usatlas1 /home/usatlas1
	fi
    
    if [ -f "/home/usatlas1/.ssh/authorized_keys" ]; then
        echo "usatlas1 authorized_keys already exists. Done."
    else
        echo "usatlas1 authorized_keys needed"
        mkdir -p /home/usatlas1/.ssh
        cp $SETUPDIR/authorized_keys.usatlas1 /home/usatlas1/.ssh/authorized_keys
    	chown -R usatlas1:usatlas /home/usatlas1/.ssh
    fi
}


ensure_lcgca()
{
    echo "Checking for lcg-CA installation..." 
	echo up2date --nosig lcg-CA
	up2date --nosig lcg-CA

}

ensure_rpms() 
{
    echo "Adding required RPMs..."
	echo rpm --import /afs/usatlas.bnl.gov/lcg/mgmt/etc/GPG-KEYS/*
	rpm --import /afs/usatlas.bnl.gov/lcg/mgmt/etc/GPG-KEYS/*
	
    echo rpm -Uvh $RPMDIR/*.rpm
	rpm -Uvh $RPMDIR/*.rpm

	echo up2date mod_ssl mod_python httpd httpd-devel MySQL-python lcg-CA 
	up2date --nosig httpd subversion mod_ssl mod_python httpd-devel MySQL-python rrdtool openmpi-devel openmpi-libs openmpi 


    echo "Double checking gridsite..."
    rpm -Uvh $RPMDIR/gridsite/gridsite-*.rpm
}

ensure_condor_user()
{
    echo "Checking for sm account status..."
	cacctinfo=`cat /etc/passwd | grep "^condor:"`
	cgrpinfo=`cat /etc/group | grep "^rhstaff:"`

	if [ "${cgrpinfo}X" != "X" ] ; then
    		echo "Local rhstaff group already exists."
	else
    	echo "Needs local rhstaff group. Creating..."
		echo "rhstaff:x:31016:" >> /etc/group
	fi

	if [ "${cacctinfo}X" != "X" ] ; then
    		echo "Local condor account already exists."
	else
    	   echo "Needs local condor account. Creating..."
		   echo "condor:x:31020:31016:Condor Service Account:/home/sm:/bin/bash" >> /etc/passwd
	fi

	if [ -d "/home/condor" ]; then
    		echo "Home directory already exists for condor."
	else
    		echo "Creating condor home directory from /etc/skel..."
    		cp -r /etc/skel /home/condor
    		chown -R condor:rhstaff /home/condor
	fi

}



ensure_local_condor()
{

	echo Setting up local BNL condor...
    export CONDOR_CONFIG=/opt/condor-7.0.2/etc/condor_config 
	if [ -f /etc/init.d/condor ]; then
		/etc/init.d/condor stop
	fi
    sleep 10
    echo "Checking for condor user..."
    ensure_condor_user

	echo "Installing/Upgrading Condor..."
	rpm  -Uvh $RPMDIR/condor/condor-7.0.2*.rpm
	rm -rf /etc/condor
	rm -rf /home/condor
	rm -f /etc/profile.d/condor*
	echo mkdir -p /home/condor/local/atlas/ /var/condor/local/atlas/log /var/condor/local/atlas/spool 
	mkdir -p /home/condor/local/atlas/ /var/condor/local/atlas/log/GridLogs /var/condor/local/atlas/spool /home/condor/local/atlas/execute
	cp $SETUPDIR/condor_config /opt/condor-7.0.2/etc/condor_config
	echo cp $SETUPDIR/condor_config.local /home/condor/local/atlas/
	cp $SETUPDIR/condor_config.local /home/condor/local/atlas/
	echo cp $SETUPDIR/condor_config.local.eightvm /home/condor/local/atlas/
	cp $SETUPDIR/condor_config.local.eightvm /home/condor/local/atlas/
	echo chown -R condor:rhstaff /var/condor /home/condor
	chown -R condor:rhstaff /var/condor /home/condor
	echo cp $SETUPDIR/condor.init /etc/init.d/
	cp $SETUPDIR/condor.init /etc/init.d/condor
	chmod +x /etc/init.d/condor
    echo "Setting up condor profile files..."
    cd /etc/profile.d/ ; ln -s /opt/condor-7.0.2/condor.sh ./
	cd /etc/profile.d/ ; ln -s /opt/condor-7.0.2/condor.csh ./
	echo "Setting condor to start at boot..."
    chkconfig condor on
	/etc/init.d/condor start
    sleep 15
    echo "Checking for running condor executables..."
	ps aux | grep condor | grep -v grep

}

ensure_grid_condor()
{

	echo Setting up Grid only condor...
    export CONDOR_CONFIG=/opt/condor-7.0.2/etc/condor_config 
	if [ -f /etc/init.d/condor ]; then
		/etc/init.d/condor stop
	fi
    sleep 10
    echo "Checking for condor user..."
    ensure_condor_user

	echo "Installing/Upgrading Condor..."
	rpm  -Uvh $RPMDIR/condor/condor-7.0.2*.rpm
	rm -rf /etc/condor
	rm -rf /home/condor
	rm -f /etc/profile.d/condor*
	echo "cp $SETUPDIR/condor_config.outside /opt/condor-7.0.2/etc/condor_config"
	cp $SETUPDIR/condor_config.outside /opt/condor-7.0.2/etc/condor_config
	
    shorthost=`hostname -s`
    echo "Host shortname is $shorthost..."
    echo cp $SETUPDIR/condor_config.local.outside /opt/condor-7.0.2/local.$shorthost/
    cp $SETUPDIR/condor_config.local.outside /opt/condor-7.0.2/local.$shorthost/condor_config.local
	
    echo "Setting up condor profile files..."
    cd /etc/profile.d/ ; ln -s /opt/condor-7.0.2/condor.sh ./
	cd /etc/profile.d/ ; ln -s /opt/condor-7.0.2/condor.csh ./
	
    echo "Setting condor to start at boot..."
    chkconfig condor on
	/etc/init.d/condor start
    
    sleep 15
    echo "Checking for running condor executables..."
	ps aux | grep condor | grep -v grep

}


ensure_java()
{
    echo "Installing required Java..."
	rpm -e --nodeps jdk
	rpm -e --nodeps java-1.5.0-sun-compat
	rpm -Uvh $RPMDIR/java/*.rpm
    up2date java-1.5.0-sun-compat
    rpm -e --nodeps j2re
}


ensure_glite()
{
    echo "Setting up gLite..."
	echo "Removing RPMs that interfere with glite install..."
    echo "rpm -e --nodeps jdk"
    rpm -e --nodeps jdk
    
    echo up2date --nosig glite-UI
	up2date --nosig glite-UI

	echo /opt/glite/yaim/bin/yaim -c  -s $SETUPDIR/site-info.def.glite.gridui0X -n glite-UI
	/opt/glite/yaim/bin/yaim -c  -s $SETUPDIR/site-info.def.glite.gridui0X -n glite-UI
    
    echo "Getting rid of j2re..."
    rpm -e --nodeps j2re
    
    
    echo "up2date --nosig gridsite-apache java-1.5.0-sun-compat"
    up2date --nosig gridsite-apache java-1.5.0-sun-compat
}

disable_selinux()
{
	echo "Setting SELinux to disabled..."
	echo "# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#	enforcing - SELinux security policy is enforced.
#	permissive - SELinux prints warnings instead of enforcing.
#	disabled - SELinux is fully disabled.
SELINUX=disabled
# SELINUXTYPE= type of policy in use. Possible values are:
#	targeted - Only targeted network daemons are protected.
#	strict - Full SELinux protection.
SELINUXTYPE=targeted" > /etc/sysconfig/selinux

}

ensure_dq2()
{
    echo "Setting up dq2..."
    echo up2date --nosig dq2-clientapi-cli dq2-common-client-curl
    up2date --nosig dq2-clientapi-cli dq2-common-client-curl
    . /opt/dq2/profile.d/dq2_common_post_install.sh

}




update_system()
{
    echo "Updating OS via up2date..."
    up2date --nosig -u

}

set_subnet()
{
  SN=`ifconfig eth0 | grep "inet addr" | awk '{print $2}' | awk -F '.' '{print $3}'`
   return $SN
    

}

ensure_iptables()
{
    #echo $IPTABLESRULE
    #echo $IPTABLESGREP
    iprange=`cat /etc/sysconfig/iptables | grep $IPTABLESGREP`
    #echo "iprange is $iprange"
    if [ "${iprange}X" != "X" ] ; then
	echo "Iptables OK."
else
	echo "Add this line to iptables:"
	echo $IPTABLESRULE
	fi
}





echo "Panda system setup script..."

set_subnet
RETVAL=$?
SUBNET=$RETVAL
echo "This host is on the $SUBNET subnet."

#ensure_sm
#disable_selinux
#ensure_lcgca
#ensure_local_condor
#ensure_grid_condor
#ensure_glite
#ensure_java
#ensure_rpms
#ensure_dq2
#update_system
#ensure_iptables



