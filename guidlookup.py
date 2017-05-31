#!/bin/env python
# 
# Simple script to lookup both long and short SFN in LFC to derive GUID
# Requires an Oracle environment prior to running so 
#
#

import os
import sys
import subprocess
import cx_Oracle

#print("ORACLE_HOME is %s" % os.environ['ORACLE_HOME'])
#print("PATH is %s" % os.environ['PATH'])
#print("LD_LIBRARY_PATH is %s" % os.environ['LD_LIBRARY_PATH'])
#print("TNS_ADMIN is %s" % os.environ['TNS_ADMIN'])

if len(sys.argv) > 1:
	infilename = sys.argv[1]
else:
	print("Usage: guidlookup.py <infilename>")
        sys.exit(0)   

infile = open(infilename)

prefix = "srm://dcsrm.usatlas.bnl.gov"
longprefix = "srm://dcsrm.usatlas.bnl.gov:8443/srm/managerv2?SFN="

conn_str = u'LFC_USBNLPRIN_READER/"4lfc2bn3yTwv"@DDMOPS'
conn = cx_Oracle.connect(conn_str)
c = conn.cursor()

for fname in infile.readlines():
#for fname in ['srm://dcsrm.usatlas.bnl.gov/pnfs/usatlas.bnl.gov/BNLT0D1/rucio/group/phys-gener/bb/72/group.phys-gener.alpgen.117094.ttbarlnqqNp1_ktfac05.TXT.mc11_v1._02166.tar.gz','srm://dcsrm.usatlas.bnl.gov/pnfs/usatlas.bnl.gov/BNLT0D1/mc12_8TeV/log/e1422_s1499_s1504/mc12_8TeV.167321.AlpgenJimmy_Auto_AUET2CTEQ6L1_VBF_ZeeNp1.merge.log.e1422_s1499_s1504_tid00921271_00/log.00921271._000510.job.log.tgz.1','srm://dcsrm.usatlas.bnl.gov/pnfs/usatlas.bnl.gov/atlasuserdisk/user/kkiuchi/data12_8TeV/user.kkiuchi.data12_8TeV.periodL.physics_JetTauEtmiss.PhysCont.NTUP_SMWZ.grp14_v01_p1328_p1329.0606.slim.130606031657/user.kkiuchi.018328._00322.physics.root.1'  ]:
	if fname.startswith(prefix):
		pathname = fname[27:].strip()
		short = "%s%s" % (prefix, pathname )
		long = "%s%s" % (longprefix, pathname )
		#print("pathname is %s" % pathname )
		#print("short is %s%s" % (prefix, pathname ))
		#print("long is %s%s" % (longprefix, pathname ))
         	#
		# This works:
		#c.execute(u'select guid from lfc_usbnlprin_reader.cns_file_metadata where fileid=(select fileid from lfc_usbnlprin_reader.cns_file_replica where sfn=\'srm://dcsrm.usatlas.bnl.gov:8443/srm/managerv2?SFN=/pnfs/usatlas.bnl.gov/BNLT0D1/rucio/group/phys-gener/bb/72/group.phys-gener.alpgen.117094.ttbarlnqqNp1_ktfac05.TXT.mc11_v1._02166.tar.gz\')')
		guid = ''
		c.execute(u'select guid from lfc_usbnlprin_reader.cns_file_metadata where fileid=(select fileid from lfc_usbnlprin_reader.cns_file_replica where sfn=\'%s\')' % long)
		for row in c:
			for el in row:
                		#print(el)
				guid = el
		else:
			pass
		c.execute(u'select guid from lfc_usbnlprin_reader.cns_file_metadata where fileid=(select fileid from lfc_usbnlprin_reader.cns_file_replica where sfn=\'%s\')' % short)
		for row in c:
			for el in row:
                		#print(el)
				guid = "%s%s" % (guid, el)
                	#print(row[0])
		else:
			pass
                guid = guid.strip()
		if len(guid) == 0:
			guid = "None"
		print("%s %s" % (guid, short))
conn.close()
