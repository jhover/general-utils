#!/usr/bin/env python
#
# Takes file, finds IPs, replaces them with hostnames. 
# @author John R. Hover <jhover@bnl.gov>
#
import sys
import re
import socket

IPREGEX="(?:\d{1,3}\.){3}\d{1,3}"

f = open(sys.argv[1])

ip2hn = {}
hostsseen= {}
lineno = 1

# Read all lines in log and replace IPs with hostnames where possible. 
for line in f.readlines():
    #print "%s: %s" % (lineno, line)
    line = line.strip()
    all = re.findall(IPREGEX,line)
    for ipaddr in all:
        #print ipaddr
        try:
            hostname = ip2hn[ipaddr]
            hostsseen[hostname] += 1
            #print hostname
        except KeyError:
            try:
                #print "looking up %s" % ipaddr
                (hostname,aliaslist,iplist) = socket.gethostbyaddr(ipaddr)
                ip2hn[ipaddr] = hostname
                hostsseen[hostname] = 1            
            except socket.herror:
                ip2hn[ipaddr] = ipaddr
                hostsseen[ipaddr] = 1
    for ipaddr in all:
        line = line.replace(ipaddr, ip2hn[ipaddr])
    print "%s: %s" % (lineno, line)
    lineno += 1

# Output sorted list of hosts with activity. 
hostlist = []              
for k in hostsseen.keys():
    hostlist.append(k)
    hostlist.sort() 

for h in hostlist:
    print "%s : %d" %( h, hostsseen[h])
