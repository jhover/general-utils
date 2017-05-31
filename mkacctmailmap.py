#!/usr/bin/env python
import sys
args = sys.argv[1:]
#print args
if len(args) < 2:
        print("usage: app <acct-dn-file> <dn-email-file>")
        sys.exit(0)

udf = open(args[0])
dnef = open(args[1])

acct2dn = {}
dn2email = {}

for line in udf.readlines():
        (acct, userdn) = line.split(',')
        acct = acct.strip()
        acct2dn[acct] = userdn.strip()
        #print line
for line in dnef.readlines():
        (userdn,email) = line.split(',')
        userdn = userdn.strip()
        dn2email[userdn]=email.strip()

for a in acct2dn.keys():
        try:
            dn = acct2dn[a]
            email = dn2email[dn]
            print ("%s,%s,%s" % ( a,dn,email))
        except KeyError:
            pass


