#!/usr/bin/env python
#
# Simple utility to confirm that for all groups and users, if a 
# user is listed as a member of a group, that user appears in that group. 
# This is an issue with nsswitch using LDAP, because LDAP has separate
# User and Group objects, which each contain independent entries (which can  
# therefore be inconsistent). 
#
#  PSEUDOCODE
#
#  for each user in getent passwd:
#       groups = id(user)
#       for g in groups:
#            check if user is member
#       
#   for each group in getent group:
#        users = getent group $group.users
#        for user in users:        
#              is group in id(user)
import commands
import os
import pwd
import grp

debug_flag = 1
status_threshold= 100


def debug(str, newline=True):
    if debug_flag:
        if newline:
            print(str)
        else:
            print "%s\r" % str ,  

def extract_groupname(instring):
    '''
        arg  500(jhover) or 501(vboxusers) for 'id' command
        returns only groupname
    '''
    if instring.isdigit():
        return instring
    try:
        (bef,aft) = instring.split('(')
        n = aft[:-1]
        if n == '':
            n = None
    except ValueError:
        
        n = None
        debug('Problem in extract_groupname with string %s' % instring)
    return n


def is_present(instring, strlist):
    '''
    if instr is in strlist, true, else false. 
    
    '''
    a = False
    for s in strlist:
        if instring == s:
            a = True
    return a


def generate_users():
    '''
    Runs getent passwd and id on all users. 
    Returns hash of username -> [group1,group2] 
    '''
    users = {}
    debug('Running getent passwd')
    (status, output) = commands.getstatusoutput('getent passwd')
    lines = output.splitlines()
    debug('Got getent passwd output of %d lines' % len(lines))
    for line in lines:
        (user,x,uid,gid,comment,homdir,shell) = line.split(':')
        (status, idstr) = commands.getstatusoutput('id %s' % user)
        try:
            (u,g,gstr) = idstr.split()
            (header, gstr) = gstr.split('=')
            groupstrlist = gstr.split(',')
            grpnames = []
            for gs in groupstrlist:
                group = extract_groupname(gs)
                grpnames.append(group)
            users[user] = grpnames
        except Exception:
            debug("Problem with 'id %s' output: %s" % (user, idstr) )
    return users

def generate_users2():
    users = {}
    allusers = pwd.getpwall()
    debug('Got %d users' % len(allusers))
    idx = 1
    for user in allusers:
        ( pw_name, pw_passwd, pw_uid,pw_gid, pw_gecos, pw_dir, pw_shell ) = user
        (status, idstr) = commands.getstatusoutput('id -Gn %s' % pw_name)
        grps = idstr.split()
        users[pw_name] = grps
        if idx % status_threshold == 0:
            debug('Called id on %d users' % idx, newline=False)
        idx += 1
    return users


def generate_groups():
    '''
    Runs getent group. 
    Returns hash of groupname -> [member1, member2]
    '''
    groups = {}
    debug('Running getent group')
    (status,output) = commands.getstatusoutput('getent group')
    lines = output.splitlines()
    debug('Got getent group output of %d lines' % len(lines))
    for line in lines:
        (group,x,gid,memstr) = line.split(':')
        members = []
        for m in memstr.split(','):
            if not m == '':
                members.append(m)
        groups[group] = members
    return groups



def generate_groups2():
    groups = {}
    allgroups = grp.getgrall()
    debug('Got %d groups' % len(allgroups))
    for group in allgroups:
        ( gr_name, gr_passwd, gr_gid, gr_mem) = group
        groups[gr_name] = gr_mem
    return groups


if __name__ == '__main__':    
      
    u = generate_users2()
    g = generate_groups2()

    # check users in passwd. if 'id user' says they are in a group, does getent group agree?
    for user in u.keys():
        debug("%s : %s " % ( user, u[user]))
        for gr in u[user]:
            if gr == user:
                debug("Assuming user '%s' is in group of same name '%s'" % (user, gr))
            else:
                if not is_present(user,g[gr] ):    
                    print("Hey, passwd for %s says they are in %s, but group says no." % (user, gr))
    
    # check groups in getent group, if the group says a user is in it, does 'id user' agree?
    for group in g.keys():
        debug("%s : %s " % ( group, g[group]))
        for us in g[group]:
            #print("Handling user %s from group %s" % (us, group))
            if not is_present(group, u[us]):
                print("Hey, getent group for '%s' says user '%s' is in it, but 'id %s' says no." % (gr,us, us))
        
      
