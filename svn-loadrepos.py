#!/usr/bin/python
import sys
import commands

SVNROOT="/var/svn"

for f in sys.argv[1:]:
    fnameparts = f.split(".")
    ext = fnameparts[-1]
    reponame = fnameparts[0]
    print( "arg is %s ext is %s reponame is %s" % ( f,ext,reponame))
    if ext == "dmp" and reponame.strip() != "":
        print( "Removing repo at %s/%s" % ( SVNROOT, reponame))
        (s,o) = commands.getstatusoutput("rm -rf %s/%s" % (SVNROOT,reponame) )
        print("status=%d" % s)
        print("output=%s" % o)
        print "Creating repo at %s/%s" % ( SVNROOT, reponame)
        (s,o) = commands.getstatusoutput("svnadmin create %s/%s" % (SVNROOT,reponame) )
        print("status=%d" % s)
        print("ouptut=%s" % o)
        print "Loading repo at %s/%s from file %s" % ( SVNROOT, reponame, f)
        (s,o) = commands.getstatusoutput("cat %s | svnadmin load %s/%s" % ( f, SVNROOT,reponame) )
        print("status=%d" % s)
        print("ouptut=%s" % o)
        print "Creating dav directory for repo %s" % ( reponame)
        (s,o) = commands.getstatusoutput("mkdir %s/%s/dav" % ( SVNROOT,reponame) )
        print("status=%d" % s)
        print("ouptut=%s" % o)    
        print "Changing ownership at %s/%s to apache:apache" % ( SVNROOT, reponame)
        (s,o) = commands.getstatusoutput("chown -R apache:apache %s/%s" % (SVNROOT, reponame) )	
        print("status=%d" % s)
        print("output=%s" % o)
