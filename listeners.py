#!/usr/bin/env python
import os
import sys
import commands
import logging
import getopt
import string


LSOFBIN='/usr/sbin/lsof'
loglev='warn'
servicecache=None

        # cmd             python from "lsof | grep LISTEN"
        # fullcommand     /usr/bin/python /usr/local/eclipse/plugins/fsasr.py 52913 37098 (from pid) OR python
        # longcommand     /usr/bin/python
        # shortcommand    python
        # whichcommand    `which python`
        # commandargs     /usr/local/eclipse/plugins/fsasr.py 52913 37098
        # command         full path from from cmd -> which OR cmd if not on path

class Listener(object):
    def __init__(self, cmd, pid, user, utime, ipv, something, prot, iface, service, port):
        log = logging.getLogger()
        log.debug("listeners.Listener.__init__(): Creating...")
        self.cmd = cmd
        self.pid = pid
        self.user = user
        self.utime = utime
        self.ipv = ipv
        self.something = something
        self.prot = prot
        self.iface = iface
        self.service = service
        self.port = port        
        self.fullcommand = self.full_command() 
        self.commandfields = self.fullcommand.split()
        
        if len(self.commandfields)> 1:
            self.commandargs = " ".join(self.commandfields[1:])
        else:
            self.commandargs = ""
 
        log.debug("listeners.Listener.__init__(): Processing fullcommand %s" % self.fullcommand)
        if self.fullcommand[0] == '/':
            log.debug("Starts with '/'")
            self.longcommand = self.commandfields[0]
            (status, output) = commands.getstatusoutput("rpm -qf %s" % self.longcommand)
            if "not owned" in output:
                self.rpmowner = "UNOWNED"
            else:
                self.rpmowner = output           
        else:
            log.debug("Doesn't start with '/'")
            self.shortcommand = self.commandfields[0]
            if self.shortcommand[-1] == ":":
                self.shortcommand = self.shortcommand[:-1] 
            (status, output) = commands.getstatusoutput("/usr/bin/which %s" % self.shortcommand )
            if status:
                log.debug("'which %s' didn't return a path" % self.shortcommand)
                self.longcommand = self.shortcommand
                self.rpmowner = "UNKNOWN"
            else:
                log.debug("'which %s' did return a path %s" % (self.shortcommand, output))
                self.longcommand = output  
                (status, output) = commands.getstatusoutput("rpm -qf %s" % self.longcommand)
                if "not owned" in output:
                    self.rpmowner = "UNOWNED"
                else:
                    self.rpmowner = output            
    
            

    
    def which_command(self):
        pass
    
    
    def full_command(self):
        (status, output) = commands.getstatusoutput("ps u -p %s" % self.pid )
        lines = output.split("\n")
        lineno = 1
        for line in lines[1:]:   # ignore headers
            #print "Line %d %s" % (lineno, line)
            lineno += 1
            fields = line.split()
            uname = fields[0]
            pid = fields[1]
            cpu = fields[2]
            mem = fields[3]
            vsz = fields[4]
            rss  = fields[5]
            tty = fields[6]
            stat = fields[7]
            start = fields[8]
            time = fields[9]
            fullcommand = " ".join(fields[10:])
        return fullcommand
  

    def simplePrint(self):
        s = ""
        s += "%s  " % self.fformat(8, self.user)
        s += "%s  " % self.fformat(5, self.pid )
        s += "%s  " % self.fformat(12, self.service)
        s += "%s:%s\t" % (self.iface,str(self.port) )
        s += "%s\t" % self.rpmowner
        s += "%s " % " ".join([self.longcommand, self.commandargs])
        return s 
    
    def fformat(self, preflen, strng):
        s = strng
        if len(s)>preflen:
            #truncate string
            a = s[:preflen]
        elif len(s) < preflen:
            #pad string
            a = s.ljust(preflen)
        else:
            a = s
        return a
    
        
    def __str__(self):
        return self.simplePrint()
        #s = ""
        #s += "fullcmd=%s pid=%s user=%s port=%s rpmowner=%s" % (self.fullcmd, self.pid, self.user, self.port, self.rpmowner)
        #return s
# user  pid    user X   NET    ?         PROT  IFACE:PORT  LISTEN
# sshd  23190  root 7u  IPv6  127133802  TCP   [::1]:6014 (LISTEN)
def lsof_listeners():
    global log
    global servicecache

    lstnrs=[]
    
    (status,output) = commands.getstatusoutput('%s | grep LISTEN' % LSOFBIN)
    outlen = len(output)
    if outlen:
        lines = output.split("\n")
        for line in lines:
            offset = None
            try:
                log.debug("listeners.lsof_listeners(): Parsing line: '%s'" % line)
                fieldlist = line.split()
                i = 0
                cmd = fieldlist[i].strip()
                log.debug("listeners.lsof_listeners(): cmd is %s" % cmd)
                i+=1 
                pid = fieldlist[i].strip()
                log.debug("listeners.lsof_listeners(): pid is %s" % pid)  
                i+=1 
                user = fieldlist[i].strip()
                log.debug("listeners.lsof_listeners(): user is %s" % user) 
                i+=1 
                filedescriptor = fieldlist[i].strip() 
                log.debug("listeners.lsof_listeners(): fd is %s" % filedescriptor)
                i+=1 
                type = fieldlist[i]
                log.debug("listeners.lsof_listeners(): type is %s" % type)
                i+=1 
                device = fieldlist[i]
                log.debug("listeners.lsof_listeners(): device is %s" % device)
                i+=1 
                # deal with presence or absence of offset
                something = fieldlist[i].strip()
                log.debug("listeners.lsof_listeners(): something is %s" % something)
                if not something == "TCP":
                    offset = fieldlist[i]
                    log.debug("listeners.lsof_listeners(): offset is %s" % offset)
                    i+=1
                node=fieldlist[i]
                log.debug("listeners.lsof_listeners(): node is %s" % node)
                i+= 1
                ifaceport=fieldlist[i]
                log.debug("listeners.lsof_listeners(): ifaceport is %s" % ifaceport)
                i +=1
                listen=fieldlist[i]
                log.debug("listeners.lsof_listeners(): listen is %s" % listen) 
            
                lastindex = ifaceport.rfind(':')
                iface = ifaceport[:lastindex]
                service = ifaceport[lastindex + 1:]
                
                try:
                    port = int(service)
                except:
                    port = _get_service_port(service)            
                
                #cmd = get_command_by_pid(pid)            
                
                # cmd, pid, user, utime, ipv, something, prot, iface, service, port
                if offset:
                    lst = Listener(cmd, pid, user, filedescriptor, type, offset, node, iface, service, port)
                else:
                    lst = Listener(cmd, pid, user, filedescriptor, type, '0t0', node, iface, service, port)
                log.debug("listeners.lsof_listeners(): Listener object created. Adding to list.")
                lstnrs.append(lst)
            except Exception, e:
                log.debug("listeners.lsof_listeners(): Something wrong with line: '%s' Error %s" % (line, e))        
    else:
        log.info("listeners.lsof_listeners(): No listening processes found.")
    return lstnrs

def _get_service_port(service):
    global servicecache
    
    if servicecache:
        log.debug("listeners.lsof_listeners(): servicecache found, using...")
        port = servicecache[service]
    else:
        log.debug("listeners.lsof_listeners(): servicecache not found, creating new one....")
        _build_service_cache()
        port = servicecache[service]
                  
    return port

def _build_service_cache():
    global servicecache
    servicecache = {}
    svcfile = open('/etc/services').readlines()
    for line in svcfile:
        if line[0] != '#' and line[0] != ' ' and line[0] != '\n':
            fields = line.split()
            servicename = fields[0]
            (sport, sprot) = fields[1].split('/')
            servicecache[servicename] = sport
    log.debug("listeners.lsof_listeners(): servicecache w %d entries created" % len(servicecache)) 
            

#[root@griddev01 ~]# ps -f --pid 13237
#UID        PID  PPID  C STIME TTY          TIME CMD
#daemon   13237 13131  0 May01 ?        00:00:07 /vdt181/apache/bin/httpd -d /vdt181/apache -k start -f /vdt181/apache/conf/httpd.conf



    
    
    
    #(user,ppid, cpu, mem, vsz, rss, tty, stat, start, time, command)



if __name__== "__main__":
    
    # Check python version 
    major, minor, release, st, num = sys.version_info
    
    # Set up logging, handle differences between Python versions... 
    # In Python 2.3, logging.basicConfig takes no args
    #
    FORMAT="%(asctime)s [ %(levelname)s ] %(message)s"
    
    if major == 2 and minor <=3:
        logging.basicConfig()  
    else:
        logging.basicConfig(format=FORMAT)
    
    log = logging.getLogger()
    if loglev == 'debug':
        log.setLevel(logging.DEBUG)
    elif loglev == 'info':
        log.setLevel(logging.INFO)
    elif loglev == 'warn':
        log.setLevel(logging.WARN)
    
    usage = '''Usage: listeners.py [OPTION]... 
listeners.py -- What TCP listeners are running? What RPM are they from? 
   -h | --help      print this message
   -d | --debug     debug logging
   -v | --verbose   verbose logging 
Report problems to <jhover@bnl.gov>'''

    # Command line arg defaults   

    #process command line   
    argv = sys.argv[1:]
    
    try:
        opts, args = getopt.getopt(argv, "hdv", ["help", "debug", "verbose"])
    except getopt.GetoptError:
        print "Unknown option..."
        print usage                          
        sys.exit(1)        
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print usage                     
            sys.exit()            
        elif opt in ("-d", "--debug"):
            log.setLevel(logging.DEBUG)
        elif opt in ("-v", "--verbose"):
            log.setLevel(logging.INFO)
            log.info("verbose logging enabled.")
    
    log.info("Listeners -- correlate processes and packages")
    
    #plist = process_list()
    #for p in plist:
    #    pass
        #print("%s=%s" % (p.pid, p.cmdline))
    
    all_listeners = lsof_listeners()
    for lst in all_listeners:
        print(lst)
    
 