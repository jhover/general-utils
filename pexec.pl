#!/usr/bin/perl -w
#
# Simple script to run several background commands in parallel using
# perl's event loop to manage them all simultaneously.
#
# Written by: Jason A. Smith <smithj4@bnl.gov>
#
# CVS: $Id$
#
# NOTE: To compile this with the perl packager, I need to do:
#
#   $ pp -l /usr/lib/libmysqlclient.so -o pexec pexec.pl
#
#          --== or ==--
#
#   $ pp -l /usr/lib/mysql/libmysqlclient.so -o pexec pexec.pl
#
#  - If the mysql module is statically linked then do this:
#
#   $ pp -o pexec pexec.pl
#

# Let CVS keep track of the version and date for me:
my $VERSION = sprintf("%d.%02d", q$Revision: 0.5$ =~ /(\d+)\.(\d+)/);
my $AUTHOR = 'Jason A. Smith <smithj4@bnl.gov>';

# Modules to use:
use POSIX qw(EINPROGRESS ECONNREFUSED);
use File::Basename;
use Getopt::Long;
use Data::Dumper;
use Event qw(loop unloop unloop_all all_watchers sweep);  # From the perl-Event module:  http://www.perl.com/CPAN/authors/id/JPRIT/
use Event::idle;   # NOTE: Letting the Event module autoload the watcher modules is depricated and breaks the perl packager!
use Event::io;
use Event::signal;
use Event::timer;
use Event::var;
use Time::HiRes qw(time usleep);		# From the perl-Time-HiRes module from RedHat.
use FileHandle;
use Socket;
use IO::Pipe;
use IO::File;
use DBI;  # Requires these packages:  perl-DBI & perl-DBD-MySQL
use subs qw(writemsg);			# Predeclare some sub names (no ampersand needed for these functions).
use English;
use strict;

# Get the process name from the script file:
my $process_name = basename $PROGRAM_NAME;

# List of nodes in the BNL RACF Grid group:
my @BNLGRID = ('atlasgrid01.usatlas.bnl.gov', 'atlasgrid02.usatlas.bnl.gov',
	       #'atlasgrid03.usatlas.bnl.gov', 'atlasgrid04.usatlas.bnl.gov', 'atlasgrid05.usatlas.bnl.gov', 'atlasgrid06.usatlas.bnl.gov',
	       'atlasgrid07.usatlas.bnl.gov',
	       #'atlasgrid08.usatlas.bnl.gov',
	       'atlasgrid09.usatlas.bnl.gov', 'atlasgrid10.usatlas.bnl.gov',
	       'atlasgrid11.usatlas.bnl.gov', 'atlasgrid12.usatlas.bnl.gov', 'atlasgrid13.usatlas.bnl.gov',
	       #'gremlin.usatlas.bnl.gov',
	       'giis01.usatlas.bnl.gov', 'vo.racf.bnl.gov', 'gridmon01.racf.bnl.gov', 'gridsec01.racf.bnl.gov',
	       'spider.usatlas.bnl.gov', 'atlasprod2.usatlas.bnl.gov',
	       'phenixgrid01.rcf.bnl.gov',
	       'stargrid01.rcf.bnl.gov', 'stargrid02.rcf.bnl.gov', 'stargrid03.rcf.bnl.gov', 'stargrid04.rcf.bnl.gov',
	       'db1.usatlas.bnl.gov', 'www.atlasgrid.bnl.gov',
	      );

# MySQL parameters:
my $mysql_server = 'rcfdb2.rcf.bnl.gov';
my $user = 'db_query';
my $password = undef;
my $database = 'linux_farm';

# Experiment indexes (0-Brahms, 2-Phenix, 4-Phobos, 6-Star):
my %exp = ('brahms' => '0',
           'phenix' => '2',
           'phobos' => '4',
           'star'   => '6',
          );

# Default parameters & Global variables:
my $range = '';
my $list = '';
my $exp = '';
my $query_string = '';
my $all = 0;
my $bnlgrid = 0;
my $script = '';
my $send = '';
my $num = 10;
my $min_num = 1;
my $max_num = 100;  # Set a maximum number of children to run to prevent fork errors when running out of pids or fds (normal limit is 1024)!
my $forks_per_sec = undef;
my $forks_per_sec_default = 8;  # NOTE: rcfmon04 [dual-PIII-800MHz] can handle about 8 forks/sec!
my $last_exec = time;
my $root = 0;
my $runlocal = 0;  # if true then run the command locally with arg NODE replaced with node name.
my $filelist = 0;
my $sanetest = 0;
my $hop = 0;
my $log_file = '';
my $log_dir = '';
my $timeout = 600;
my $noping = 0;
my $ping_only = 0;
my $verbose = 0;
my $debug = 0;
my $sshopts = '';
my $batchtype = '';

# Get the command line options:
#  - FIXME: Should add some kind of exception list.
$Getopt::Long::ignorecase = 0;  # Need this because I have two short options, same letter, different case:
my @SAVE_ARGV = @ARGV;  # Save a copy of my arguments because GetOptions modifies it.
GetOptions('A|all'        => \$all,
	   'e|exp=s'      => \$exp,
	   'r|range=s'    => \$range,
	   'l|list=s'     => \$list,
	   'q|query=s'    => \$query_string,
	   'R|root'       => \$root,
	   's|scp=s'      => \$send,
	   'O|sshopts=s'  => \$sshopts,
#	   'S|script=s'   => \$script,
	   'n|num=i'      => \$num,
	   'F|full:f'     => \$forks_per_sec,
	   'm|max=i'      => \$max_num,
	   't|timeout=i'  => \$timeout,
	   'p|ping-only'  => \$ping_only,
	   'P|no-ping'    => \$noping,
	   'G|grid'       => \$bnlgrid,
	   'H|hop'        => \$hop,
	   'L|log=s'      => \$log_file,
	   'D|logdir=s'   => \$log_dir,
	   'c|runlocal'   => \$runlocal,
	   'b|batchtype=s'  => \$batchtype,
	   'f|filelist=s' => \$filelist,
	   'T|test'       => \$sanetest,
	   'v|verbose'    => \$verbose,
	   'd|debug+'     => \$debug,
	   'h|help'       => \&print_usage,
          ) or &print_usage;

# Print usage help if no command or staging script was given to execute:
my $cmd = join ' ', @ARGV;
&print_usage if not ($cmd or $script or $send) and not $ping_only;

# Check if the send option looks good:
die "$process_name: Error: bad scp option: '$send'" if $send and $send !~ /=/;

# Set the forks/sec variable if needed:
if (defined $forks_per_sec) {
  $forks_per_sec = ($forks_per_sec > 0) ? $forks_per_sec : $forks_per_sec_default;
  # If a script is being staged then we are effectively executing 2 ssh commands, so I should halve the number of forks per second:
  if ($script) {
    $forks_per_sec /= 2;
    writemsg sprintf "$process_name: Warning: Reducing the number of forks/sec [fps=%.1f] because you are executing a staged script!\n", $forks_per_sec;
  }
}

# Reset some things if hopping over rsec00:
if ($hop) {
  writemsg "$process_name: Warning: Reseting the number of jobs to 5 because you are hopping over rsec00!\n" if $num != 5;
  $num = 5;
  writemsg "$process_name: Warning: Disabling forks/sec option because you are hopping over rsec00!\n" if defined $forks_per_sec;
  $forks_per_sec = undef;
  writemsg "$process_name: Warning: Disabling pings because you are hopping over rsec00!\n" if not $noping;
  $noping = 1;
}

# Create a list of nodes to execute on:
my ($num_pinging, $num_running) = (undef, undef);
my (@ping_queue, @fork_queue, @unresolved_nodes, @dead_nodes, @timeout_nodes, @error_nodes);
my @list = &node_list;
my $num_in_list = $#list + 1;
if ($noping) {
  @ping_queue = ();
  @fork_queue = @list;
} else {
  @ping_queue = @list;
  @fork_queue = ();
}

# Print usage help if no nodes were chosen to execute on:
&print_usage if not $num_in_list;

# Open a log file if requested:
my $log = IO::File->new(">$log_file") or die "$process_name: Error opening log file: $log_file - $!\n" if $log_file;

# Catch some useful signals:
my $signal;
my $stop_now = 0;
my %interrupt_event;
foreach my $sig ('HUP', 'INT', 'QUIT', 'TERM', 'PIPE') {
  $interrupt_event{$sig} = Event->signal(signal => $sig, desc => "sig_handler[$sig]", cb => \&sig_handler,);
}

# Define my own customized function to catch exceptions in the event loop:
#  - Defaults: &Event::default_exception_handler or &Event::verbose_exception_handler
$Event::DIED = sub { my ($self, $err) = @_;
		     my $watcher = $self->w;
		     my $desc = $watcher->desc;
		     $err =~ s/^\n//;  # Remove the preceding newline from the error message if any.
		     writemsg sprintf "%s: $process_name: Error: Caught exception in Event loop at $desc: $err", scalar localtime;
		     # Trigger the main event watchers:
		     $num_pinging += 0;
		     $num_running += 0;
		     #unloop_all(1);
		   };

# Signal to start the first set of commands when I start the event loop:
#  - this callback is only executed once, immediately after entering the event loop.
my $started;
my ($num_executed, $num_finished) = (0, 0);
my $start_timer;
my (%pid, %ping, %started, %output);
$start_timer = Event->timer(after => 0, desc => 'start_timer',
			    cb => sub { $started = time;
					writemsg sprintf "\n%s: Started: $process_name %s\n", scalar localtime, join ' ', @SAVE_ARGV;
					if ($ping_only) {
					  writemsg sprintf "%s: Ping only %d nodes in list.\n", scalar localtime, $num_in_list;
					} else {
					  writemsg sprintf "%s: Executing: '%s' on %d nodes in list.\n", scalar localtime, $cmd, $num_in_list;
					}
					writemsg sprintf "%s: ETA: Should finish in about %.1f seconds.\n",
					  scalar localtime, $num_in_list/$forks_per_sec if defined $forks_per_sec and not $ping_only;
					writemsg "\n";
					# This will trigger the event watchers below for the first time:
					$num_pinging = 0;
					$num_running = 0;
					$start_timer->cancel;
				      },
			   );

# This event watcher is useful for debugging and when waiting for unfinished events:
my $event_watcher_interval = 30;
my $event_watcher = Event->timer(interval => $event_watcher_interval, desc => 'event_watcher', suspend => 1,
				 cb => sub {
				   my $now = time;
				   if ($debug > 1) {
				     printf "\n%s: Event watcher:\n", scalar localtime;
				     printf "$process_name: Vars: num_pinging=$num_pinging, num_running=$num_running, stop_now=$stop_now\n";
				     printf "$process_name: Queues: ping_queue=%d, fork_queue=%d, num=$num\n", $#ping_queue+1, $#fork_queue+1;
				     printf "$process_name: Active event watchers:\n";
				   } else {
				     writemsg sprintf "\n%s: $process_name: Still waiting for these processes to finish ($num_pinging pings and $num_running forks):\n", scalar localtime;
				   }
				   foreach my $w (reverse all_watchers) {
				     my $desc = $w->desc;
				     if ($debug > 1) {
				       print "\tname=$desc  -  ($w)\n";
				     } else {
				       next if not $desc =~ /_read/;
				       my ($what, $node) = $desc =~ /(\w+)_read\[(.+)\]/;
				       if ($what eq 'ping') {
					 writemsg sprintf "\tPing reply from $node: sent %.1f seconds ago.\n", $now - $ping{$node}{'start'};
				       } elsif ($what eq 'pipe') {
					 my $running_time = $now - $started{$pid{$node}};
					 writemsg sprintf "\tCommand on $node: started %.1f seconds ago - timeout in %.1f seconds.\n", $running_time, $timeout - $running_time;
				       }
				     }
				   }
				   writemsg "\n";
				 },
				);
# Turn on throughout running if debugging:
if ($debug > 1) {
  $event_watcher->suspend(0);
  $event_watcher->again;
}

# Idle watcher:
#  - Sometimes all $num running jobs get stuck (running slow or waiting to timeout on dead nodes).
#  - Normally you would have to wait for a job to finish or timeout before things start moving again.
#  - This event watcher will detect this situation and increase the number of parallel jobs by one to get things moving again immediately.
my $max_exec_delay = 30;
my $idle_watcher = Event->idle(min => $max_exec_delay/2, max => $timeout, desc => 'idle_watcher',
			       cb => sub { my $exec_delay = int(time - $last_exec);
					   if ($exec_delay > $max_exec_delay and ($#ping_queue >= 0 or $#fork_queue >= 0)) {
					     writemsg sprintf "%s: Warning: Possible hung jobs, last execution was %d seconds ago, increasing num from %d to %d.\n",
					       scalar localtime, $exec_delay, $num, $num+1;
					     $num++;
					     # Now force a re-check of the fork and ping queues because the number of parallel jobs I can run has been changed:
					     $num_pinging += 0 if $#ping_queue >= 0;
					     $num_running += 0 if $#fork_queue >= 0;
					   }
					 }
			      );

# Ping queue and event watcher:
#my $port = 'http';  # Ping port 80 - none of the farm nodes should have a web-server running.
my $ping_timeout = 20;  # Allow 20 seconds for ping replies.
my ($num_pinged, $total_ping_time, $min_ping_time, $max_ping_time) = (0, 0, $ping_timeout+1, 0);
my $proto_num = (getprotobyname('tcp'))[2] or die "Can't get tcp protocol by name";
#my $port_num = (getservbyname($port, 'tcp'))[2] or die "Can't get tcp $port port by name";
my $port_num = 1001;  # Unused reserved port (http://www.iana.org/assignments/port-numbers).
my $ping_watcher;
$ping_watcher = Event->var(var  => \$num_pinging, poll => 'w', desc => 'ping_watcher',
			   prio => 3,  # Give it a higher priority - normal priority is 4.
			   cb   => sub {
			     printf "$process_name: Enter ping_watcher: ping_queue=%d, fork_queue=%d, num=$num, num_pinging=$num_pinging.\n",
			       $#ping_queue+1, $#fork_queue+1 if $debug > 1;
			     sweep(3);  # Read any ping replies that may have come back first!
			     # keep pinging until the fork queue has twice the number of threads that will be forked:
			     #  - do not let it depend on the num_pinging because a large block of down nodes can stall the script!
			     if (not $stop_now and $#ping_queue+1 > 0 and $#fork_queue+1 < 2*$num) {
			       # Some of this ping code is borrowed from the Net::Ping non-blocking tcp syn ping method:
			       #  - attempt to make a connection on a tcp port and wait for the "Connection refused" syn ack or the
			       #    normal syn ack from the listener.  There can't be a firewall blocking the tcp port being pinged.
			       # NOTE: Doing a real ICMP ping would require root permissions in order to send the ICMP packets
			       #       and I don't want to have to run this script as root just to be able to ping.
			       # NOTE: pinging the listening ssh port is very slow on a busy node. If there is no firewall
			       #       then it is much faster to ping an unused port and wait for the "Connection refused" reply
			       #       from the remote host on the unblocked port.
			       my ($node, $addr);
			       while ($#ping_queue+1 > 0) {
				 $node = shift @ping_queue;
				 $addr = inet_aton($node);
				 if ($addr) {
				   $ping{$node}{'ip'} = inet_ntoa($addr);
				   last;
				 } else {
				   writemsg sprintf "$process_name: Ping Error - Could not resolve hostname: $node - $!\n";
				   push @unresolved_nodes, (split(/\./,$node))[0];
				 }
			       }
			       die "No more valid hostnames to ping!\n" if not $addr;
			       printf "$process_name: Pinging host: $node [$ping{$node}{'ip'}]\n" if $debug;
			       my $saddr = pack_sockaddr_in($port_num, $addr);
			       my $fh = FileHandle->new or die "Error creating ping filehandle: $!";
			       socket($fh, PF_INET, SOCK_STREAM, $proto_num) or die "Ping Error - tcp socket error: $!";
			       $fh->blocking(0); # Non-blocking connection attempt!
			       $ping{$node}{'start'} = time;
			       if (connect($fh, $saddr)) {
				 # Connected already - must have been really fast or non-blocking!
			       } else {
				 # Error occurred when connecting:
				 if ($! == EINPROGRESS) {
				   # Expected result: the connection is just still in progress.
				 } else {
				   # Other connection error:
				   die "Ping Error - tcp connect error: $!";
				 }
			       }
			       $num_pinging++;
			       # Set an event to watch this ping's filehandle:
			       #  - FIXME: Should I create a re-usable event watcher like my gmetad-racf daemon?
			       my $ping_read;
			       $ping_read = Event->io(fd => $fh, poll => 'r', desc => "ping_read[$node]",
						      prio => 2, # Give it a higher priority - normal priority is 4.
						      cb => sub {
							# Connection must have been either initiated or refused:
							$ping{$node}{'end'} = time;
							$ping{$node}{'time'} = $ping{$node}{'end'} - $ping{$node}{'start'};
							my $l = <$fh>;
							if ($l or $! == ECONNREFUSED) {
							  # Node replied - must be up (Connection refused is expected for non-listening ports):
							  my $tmp = $debug ? "($!)" : '';
							  writemsg sprintf("%s: Ping OK on $node [%s]: time=%.3fms $tmp\n", scalar localtime,
									   $ping{$node}{'ip'}, 1000*$ping{$node}{'time'}), (not ($verbose or $debug));
							  push @fork_queue, $node if not $ping_only;
							  $num_running += 0;  # Node available - force more threads to be executed!
							  $num_pinged++;
							  $total_ping_time += $ping{$node}{'time'};
							  $min_ping_time = $ping{$node}{'time'} if $ping{$node}{'time'} < $min_ping_time;
							  $max_ping_time = $ping{$node}{'time'} if $ping{$node}{'time'} > $max_ping_time;
							} else {
							  # Connection error - node must be down:
							  writemsg sprintf "%s: Ping ERROR on $node: time=%.3fms - $!\n", scalar localtime, 1000*$ping{$node}{'time'};
							  push @dead_nodes, (split(/\./,$node))[0];
							  $num_running += 0;  # Force check my running children!
							}
							$fh->close;  # Or I will run out of filehandles to use!
							$ping_read->cancel;
							$num_pinging--;
						      },
						      timeout    => $ping_timeout,
						      timeout_cb => sub {
							$ping{$node}{'end'} = time;
							$ping{$node}{'time'} = $ping{$node}{'end'} - $ping{$node}{'start'};
							writemsg sprintf "%s: Ping Timeout on $node: time=%.1fs\n", scalar localtime, $ping{$node}{'time'};
							push @dead_nodes, (split(/\./,$node))[0];
							$fh->close;  # Or I will run out of filehandles to use!
							$ping_read->cancel;
							$num_pinging--;
						      },
						     );
			     }
			     # Start the event watcher if I am only pinging and just waiting for the replies:
			     if ($ping_only and $#ping_queue < 0 and $num_pinging > 0 and $event_watcher->is_suspended) {
			       print "$process_name: Done pinging - waiting for the replies.\n" if $debug;
			       $event_watcher->at(time + $event_watcher_interval);
			       $event_watcher->suspend(0);
			       $event_watcher->again;
			     }
			     # Cancel this watcher if there are no more hosts left to ping and no more replies to get (need for the unloop below):
			     $ping_watcher->cancel if $#ping_queue < 0 and $num_pinging == 0;
			     # Stop now if asked to and all active pings and children have finished:
			     unloop_all($stop_now) if $stop_now and $num_pinging == 0 and $num_running == 0;
			     # Stop if only pinging, all pings have been answered and there are no more left to ping:
			     unloop_all($stop_now) if $ping_only and $num_pinging == 0 and $#ping_queue < 0;
			     # Stop if all children have finished and I was only waiting for pings that have now timed out, thus no more children to run:
			     unloop_all($stop_now) if $num_pinging == 0 and $#ping_queue < 0 and $num_running == 0 and $#fork_queue < 0;
			   },
			  ) if not $noping;

# Main thread warcher responsible for forking new children:
my ($total_time, $min_time, $max_time) = (0, $timeout+1, 0);
my $thread_watcher = Event->var(var => \$num_running, poll => 'w', desc => 'thread_watcher',
				cb  => sub {
				  printf "$process_name: Enter thread_watcher: fork_queue=%d, num_running=$num_running, num=$num\n",
				    $#fork_queue+1 if $debug > 1;
				  if ( ($num_running == 5) && $sanetest ) {
				    print "Hit <enter> to continue.\n";
				    $| = 1;               # force a flush after our print
				    $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)
				    $sanetest = 0;
				  }
				  sweep(3);  # Read any ping replies that may have come back first!
				  if (not $stop_now and $#fork_queue+1 > 0 and $num_running < $num) {
				    my $node = shift @fork_queue;
				    &fork_cmd($node, $cmd);
				    $num_pinging += 0 if $#ping_queue >= 0;  # Force more nodes to be pinged to keep the fork queue filled up!
				    &adjust_num if defined $forks_per_sec;
				  }
				  # Start the event watcher if I am done forking and waiting for the children to finish:
				  if ($#fork_queue < 0 and $num_running > 0 and $event_watcher->is_suspended) {
				    writemsg sprintf "%s: Done forking children - waiting for them to finish.\n", scalar localtime;
				    $event_watcher->at(time + $event_watcher_interval);
				    $event_watcher->suspend(0);
				    $event_watcher->again;
				  }
				  # Stop now if asked to and all active pings and children have finished:
				  unloop_all($stop_now) if $stop_now and $num_pinging == 0 and $num_running == 0;
				  # Stop if all running children have completed and there are no more left to run on:
				  unloop_all($stop_now) if $num_running == 0 and $#fork_queue < 0 and $num_pinging == 0 and $#ping_queue < 0;
				},
			       ) if not $ping_only;

# Now start the main event loop:
my $ret = loop;

# Write summary report:
my $finished = time;
my $seconds = $finished - $started;
my $minutes = int($seconds/60);
my $hours = int($minutes/60);
$seconds -= 60*$minutes;
$minutes -= 60*$hours;
writemsg "\n";
writemsg "NOTE: Unfinished - interrupted by signal: SIG$signal!\n" if $signal;
if (not $noping) {
  writemsg "\n\t\t----------======== Ping Summary ========-----------\n\n";
  if ($ping_only) {
    writemsg sprintf "%s: Finished pinging $num_pinged/$num_in_list nodes in %.3f msec (min/ave/max: %.3f/%.3f/%.3f msec)\n",
      scalar localtime, 1000*($finished-$started), 1000*$min_ping_time, 1000*$total_ping_time/($num_pinged+1e-10), 1000*$max_ping_time;
  } else {
    writemsg sprintf "%s: Pinged $num_pinged/$num_in_list nodes (min/ave/max: %.3f/%.3f/%.3f msec)\n",
      scalar localtime, 1000*$min_ping_time, 1000*$total_ping_time/($num_pinged+1e-10), 1000*$max_ping_time;
  }
  writemsg sprintf "\t%d node(s) unresolved:  %s\n", $#unresolved_nodes+1, join ',', sort @unresolved_nodes;
  writemsg sprintf "\t%d node(s) down:  %s\n", $#dead_nodes+1, join ',', sort @dead_nodes;
}
if (not $ping_only) {
  my $average_time_per_child = $total_time / ($num_finished+1e-10);
  my $fps = $num / ($average_time_per_child+1e-10);
  writemsg "\n\t\t--------======== Execution Summary ========--------\n\n";
  writemsg sprintf "%s: Finished executing on $num_finished/$num_executed nodes in %d:%02d:%04.1f (%.1f nodes/sec - min/ave/max: %.1f/%.1f/%.1f sec/cmd - %.1ffps)\n",
    scalar localtime, $hours, $minutes, $seconds, $num_finished/($finished-$started), $min_time, $total_time/($num_finished+1e-10), $max_time, $fps;
  writemsg sprintf "\t%d node(s) timed-out:  %s\n", $#timeout_nodes+1, join ',', sort @timeout_nodes;
  writemsg sprintf "\t%d node(s) had errors:  %s\n", $#error_nodes+1, join ',', sort @error_nodes;
}
writemsg "\n";

# Clean-up and exit:
$log->close if defined $log;
exit $ret;

# Function to automatically adjust the number of parallel commands to try and keep a constant number of forks/sec:
sub adjust_num {
  return if $num_finished < $num;  # Make sure I have some statistics to calculate a good number for the forks/sec.
  my $delta = 0.5;  # Keep the number of fps to within this threshold.
  my $fps2 = $num_finished / (time - $started);  # NOTE: Don't use this one - why does it make $num unstable???
  my $average_time_per_child = $total_time / $num_finished;
  my $fps = $num / $average_time_per_child;
  my $diff = $forks_per_sec - $fps;
  my $old = $num;
  if (abs($diff) > $delta and $num > $min_num and $num < $max_num) {
    my $increment = $average_time_per_child * $diff;
    # NOTE: Don't increment the number of parallel jobs too fast:
    $increment = ($increment/abs($increment)) * 0.8 * $num if abs($increment) > 0.8 * $num;
    $num += $increment;
    $num = $min_num if $num < $min_num;  # Safeguard to prevent too few forks!
    $num = $max_num if $num > $max_num;  # Safeguard to prevent fork errors when running out of pids or fds!
    writemsg sprintf "Note: Adjusting number of parallel jobs: %.3f + %.3f = %.3f  [%.3ffps - %.3ffps2 - %.3fs/child]\n",
      $old, $increment, $num, $fps, $fps2, $average_time_per_child;
    # Now force a re-check of the fork and ping queues because the number of parallel jobs I can run has been changed:
    $num_pinging += 0 if $#ping_queue >= 0;
    $num_running += 0 if $#fork_queue >= 0;
  }
}

# Function to start a child thread and set an I/O event to capture its output:
sub fork_cmd {
  my ($node, $cmd) = @_;
  my $user = $root ? 'root@' : '';
  
  # Format the appropriate ssh command to execute:
  #  - stage the script to the node if asked to.
  my $ssh_cmd;
  if ($send) {
    my ($source, $destination) = split(/\=/, $send);
    $cmd = "Copying $source file here to $destination there.";
    $ssh_cmd = "scp $sshopts $source $user$node:$destination 2>&1 </dev/null";
  } elsif ($script) {
    # FIXME need to add the -O functionality here.
    my $tmp_script = "/tmp/$process_name.$PID";
    $cmd = "$tmp_script && rm -f $tmp_script";
    $ssh_cmd = "scp $script $user$node:$tmp_script 2>&1 && ssh $user$node \"$cmd\" 2>&1 </dev/null";
    $cmd = $script;  # So the print statements below will be more accurate.
  } elsif ($runlocal) {
    $cmd =~ s/NODE/$node/;
    $ssh_cmd = "$cmd 2>&1 </dev/null";
    print "Running locally: $ssh_cmd";
  } else {
    my $ssh_hop = $hop ? "ssh $sshopts -x -A rsec00.rhic.bnl.gov 2>/dev/null" : '';
    $ssh_cmd = "$ssh_hop ssh $sshopts -x $user$node \"$cmd\" 2>&1 </dev/null";
  }
  writemsg "\nPipe exec: $ssh_cmd\n" if $debug;
  
  # Fork the child thread:
  #  - NOTE: The fork can fail if I hit resource limits like the number of child processes or open file descriptors.
  #  - FIXME: Can I handle fork errors better, maybe wait and try again later and/or reduce -n or -F?
  my $pipe = IO::Pipe->new or die "$process_name: Error creating pipe filehandle: $!";
  # NOTE: I will run each ssh command in its own session using the setsid command:
  #  - This prevents interrupt signals sent from the terminal (hitting Control-C) from killing the ssh child processes.
  #  - The exec will replace the spawned shell with the ssh command so I can kill ssh later if I need to (timeout or user interrupt).
  #  - FIXME: This makes it impossible to stage a script with a single command, I would have to perform separate steps!
  $last_exec = time;
  $pipe->reader("exec setsid $ssh_cmd");
  $pipe->blocking(0);
  $pipe->autoflush(1);
  my $pid = &pipe_pid($pipe);
  $pid{$node} = $pid;
  writemsg sprintf "\n%s: Child[pid=$pid] started on %s: $cmd\n", scalar localtime, (split(/\./,$node))[0];
  $started{$pid} = time;
  $num_executed++;
  $num_running++;
  
  # Set an event to watch this fork's filehandle:
  my ($pipe_read, $read_null);
  $pipe_read = Event->io(fd => $pipe, poll => 'r', desc => "pipe_read[$node]",
			 prio => 3,  # Give it a higher priority - normal priority is 4.
			 cb => sub { my $line = $pipe->getline;
				     if (defined($line) and length($line)) {
				       push @{$output{$pid}}, $line;
				       $read_null = 0;
				       if ($debug > 1) {
					 $line .= "\n" if $line !~ /\n$/;
					 writemsg "pipe[$pid] read: $line";
				       }
				     } else {
				       # Read NULL from the pipe - close it only after 10 consecutive null reads:
				       #  - We discovered while executing a restart with the condor init script
				       #    that the pipe would sometimes send a null in the middle of executing???
				       writemsg "pipe[$pid] read: NULL\n" if $debug > 1;
				       return if ++$read_null < 10;
				       my $now = time;
				       # NOTE: I have to close the child pipe before I can check its error status ($? = $CHILD_ERROR):
				       $pipe->close;
				       # FIXME: Why don't signal and core work?
				       my $ret = $CHILD_ERROR >> 8;  my $signal = $CHILD_ERROR & 127;  my $core = $CHILD_ERROR & 128;
				       if ($CHILD_ERROR) {
					 my $err = $ret == 255 ? "(ssh error: ret=$ret, \$?=$?)": "(ret=$ret, signal=$signal, core=$core, \$?=$?)";
					 writemsg sprintf "\n%s: Child[$pid] finished in %.1fs on node: %s with an error $err!\n",
					   scalar localtime, $now - $started{$pid}, (split(/\./,$node))[0];
					 push @error_nodes, (split(/\./,$node))[0];
				       } else {
					 writemsg sprintf "\n%s: Child[$pid] finished in %.1fs on node: %s\n",
					   scalar localtime, $now - $started{$pid}, (split(/\./,$node))[0];
					 $num_finished++;  # Only count successful jobs.
				       }
				       $total_time += $now - $started{$pid};
				       $min_time = $now - $started{$pid} if $now - $started{$pid} < $min_time;
				       $max_time = $now - $started{$pid} if $now - $started{$pid} > $max_time;
				       if ($log_dir) {
					 my $node_log_file = sprintf "%s/completed_%s.log", $log_dir, (split(/\./,$node))[0];
					 my $node_log = IO::File->new(">$node_log_file");
					 if ($node_log) {
					   foreach my $line (@{$output{$pid}}) { print $node_log $line; }
					   $node_log->close;
					 } else {
					   writemsg "$process_name: Error opening node log file: $node_log_file - $!\n";
					 }
				       }
				       if ($verbose or $log) {
					 writemsg "  --> Output from command: $cmd\n", (not $verbose);
					 while (defined(my $l = shift @{$output{$pid}})) { writemsg $l, (not $verbose); }
					 writemsg "\n", (not $verbose);
				       }
				       $pipe_read->cancel;
				       $num_running--;
				       # Force more pinging to keep the run queue full:
				       $num_pinging += 0 if $#ping_queue >= 0;
				     }
				   },
			 timeout    => $timeout,
			 timeout_cb => sub { my $now = time;
					     writemsg sprintf "\n%s: Error-timeout: Killing child[pid=$pid] after %.1fs on node: %s\n",
					       scalar localtime, $now - $started{$pid}, (split(/\./,$node))[0];
					     push @timeout_nodes, (split(/\./,$node))[0];
					     # Have to kill the child process first or close will hang:
					     #  - it might also leave child processes laying around.
					     kill 'INT' => $pid;
					     # Read any remaining output:
					     while (my $line = <$pipe>) {
					       push @{$output{$pid}}, $line;
					     }
					     if ($log_dir) {
					       my $node_log_file = sprintf "%s/timeout_%s.log", $log_dir, (split(/\./,$node))[0];
					       my $node_log = IO::File->new(">$node_log_file");
					       if ($node_log) {
						 foreach my $line (@{$output{$pid}}) { print $node_log $line; }
						 $node_log->close;
					       } else {
						 writemsg "$process_name: Error opening node log file: $node_log_file - $!\n";
					       }
					     }
					     if ($verbose or $log) {
					       writemsg "  --> Output from command: $cmd\n", (not $verbose);
					       while (my $l = shift @{$output{$pid}}) { writemsg $l, (not $verbose); }
					       writemsg "\n", (not $verbose);
					     }
					     # Now cleanup:
					     $pipe->close;
					     $pipe_read->cancel;
					     $num_running--;
					     # Force more pinging to keep the run queue full:
					     $num_pinging += 0 if $#ping_queue >= 0;
					   },
			);
}
sub pipe_pid {
  my $pipe = shift;
  return ${*$pipe}{'io_pipe_pid'};
}

# Function to create a list of FQDNs for the requested nodes based on command line options:
sub node_list {
  my @list = ();
  
  # All nodes?
  if ($all) {
    $exp = join ",", sort('atlas', 'lsst', keys %exp);
  }
  
  if ($bnlgrid) {
    push @list, @BNLGRID;
  }
  # List of nodes to run on:
  if ($list) {
    foreach my $n (split(/\,/, $list)) {
      if ($n =~ /\./) {
	# If the node name already has a '.' in it assume it is a FQDN:
	push @list, $n;
      } else {
	# Assume it is just the node name only:
	if ($n =~ /^acas/) {
	  push @list, "$n.usatlas.bnl.gov";
	} elsif ($n =~ /rcas/ or $n =~ /^rcrs/) {
	  push @list, "$n.rcf.bnl.gov";
	} elsif ($n =~ /^lsst/) {
	  push @list, "$n.lst.bnl.gov";
	} else {
	  #die "$process_name: Error: Unknown node name to -l option: $n\n";
	  print "$process_name: Warning: Assuming domain of '.rcf.bnl.gov' for -l option: $n\n";
	  push @list, "$n.rcf.bnl.gov";
	}
      }
    }
  }
  # Range of nodes to run on:
  if ($range) {
    foreach my $r (split(/\,/,$range)) {
      my ($node, $start, $end) = $r =~ /([a-z]+)(\d+)-(\d+)/;
      foreach my $i ($start..$end) {
	if ($node eq 'acas') {
	  push @list, sprintf "%s%04d.usatlas.bnl.gov", $node, $i;
	} elsif ($node eq 'rcas' or $node eq 'rcrs') {
	  push @list, sprintf "%s%04d.rcf.bnl.gov", $node, $i;
	} elsif ($node eq 'lsst') {
	  push @list, sprintf "%s%02d.lst.bnl.gov", $node, $i;
	} else {
	  #die "$process_name: Error: Unknown node name ($node) given to -r option: $r\n";
	  print "$process_name: Warning: Assuming FQDN of '$node.rcf.bnl.gov' for -r option: $r\n";
	  push @list, sprintf "%s%04d.rcf.bnl.gov", $node, $i;
	}
      }
    }
  }
  # Whole experiment to run on:
  if ($exp) {
    # Connect to the database server (see: man/perldoc DBD::mysql):
    #  - gmond: used to set the location and multicast config options
    #  - gmetad: used to get the nodenames in each data_source experiment cluster
    #  - $ mysql -h rcfdb2.rcf.bnl.gov -u db_query
    #      mysql> show databases;  use linux_farm;  show tables;  describe machines;
    #      mysql> SELECT * FROM machines WHERE nodename like 'rcas6%';
    my $db_handle = DBI->connect("DBI:mysql:database=$database;host=$mysql_server", $user, $password, {RaiseError => 0})
      or die "$process_name: ERROR: can't connect to the mysql database server: $mysql_server";
    
    foreach my $e (split(/\,/, $exp)) {
      $e =~ tr/A-Z/a-z/;	# Make sure it is all lower case.
      # Form a query statement:
      my $where;
      if ($e =~ /(\w+)\-(\w+)/) {
	my ($ex, $type) = ($1, $2);
	if (not ($type eq 'cas' or $type eq 'crs' or $type eq 'interactive')) {
	  die "$process_name: Error: Unknown node type[$type] given to -e option: $exp\n";
	}
	if ((not ($type eq 'interactive')) and $ex eq 'atlas') {
	  $where = sprintf "nodename like 'acas%%'";
	} elsif ((not ($type eq 'interactive')) and $ex eq 'lsst') {
	  $where = sprintf "nodename like 'lsst%%'";
	} elsif ((not ($type eq 'interactive')) and ($ex eq 'brahms' or $ex eq 'phenix' or $ex eq 'phobos' or $ex eq 'star')) {
	  $where = sprintf "nodename like 'r%s%d%%'", $type, $exp{$ex};
	} elsif ($type eq 'interactive' and ($ex eq 'brahms' or $ex eq 'phenix' or $ex eq 'phobos' or $ex eq 'star')) {
	  $where = sprintf "access like 'interactive' and nodename like 'rc%%s%d%%'", $exp{$ex};
	} elsif ($type eq 'interactive' and ($ex eq 'atlas')) {
	  $where = sprintf "access like 'interactive' and nodename like 'acas%%'";
	} elsif ($type eq 'interactive' and ($ex eq 'lsst')) {
	  $where = sprintf "access like 'interactive' and nodename like 'lsst%%'";
	} else {
	  die "$process_name: Error: Unknown node name[$ex] given to -e option: $exp\n";
	}
      } else {
	if ($e eq 'atlas') {
	  $where = sprintf "nodename like 'acas%%'";
	} elsif ($e eq 'lsst') {
	  $where = sprintf "nodename like 'lsst%%'";
	} elsif ($e eq 'brahms' or $e eq 'phenix' or $e eq 'phobos' or $e eq 'star') {
	  $where = sprintf "nodename like 'rcas%d%%' or nodename like 'rcrs%d%%'", $exp{$e}, $exp{$e};
	} elsif ($e eq 'all') {
	  $where = "nodename like '%'";
	} else {
	  die "$process_name: Error: Unknown node name[$e] given to -e option: $exp\n";
	}
      }
      my $query = "SELECT nodename,domain FROM machines WHERE ($where) AND status='active';";  # Only select active nodes!
      writemsg "mysql QUERY: $query\n" if $debug;
      my $statement_handle = $db_handle->prepare($query) or die "$process_name: MySQL Error: ". $db_handle->errstr;
      
      # Send the query to the server:
      $statement_handle->execute or die "$process_name: MySQL Error: ". $statement_handle->errstr;
      writemsg sprintf "\t--> Returned %d results.\n", $statement_handle->rows if $debug;
      
      # Get the list of nodes this search returned:
      while (my $ref = $statement_handle->fetchrow_hashref) {
	writemsg Dumper $ref if $debug > 1;
	push @list, sprintf "%s.%s", $ref->{'nodename'}, $ref->{'domain'};
      }
      $statement_handle->finish;
    }
    $db_handle->disconnect;
  }
  # Select nodes based on Condor configuration.
  if ($batchtype) {
    my $db_handle = DBI->connect("DBI:mysql:database=$database;host=$mysql_server", $user, $password, {RaiseError => 0})
      or die "$process_name: ERROR: can't connect to the mysql database server: $mysql_server";

    my ($nodeexp,$condortype) = split(/_/,$batchtype);

    print "$batchtype\n";
    print "$nodeexp\n";
    print "$condortype\n";

    my $where='';
    if ($nodeexp eq 'atlas') {
        $where = sprintf "m.nodename like 'acas%%'";
    } elsif ($nodeexp eq 'lsst') {
        $where = sprintf "m.nodename like 'lsst%%'";
    } elsif ($nodeexp eq 'brahms' or $nodeexp eq 'phenix' or $nodeexp eq 'phobos' or $nodeexp eq 'star') {
        $where = sprintf "m.nodename like 'rcas%d%%' or m.nodename like 'rcrs%d%%'", $exp{$nodeexp}, $exp{$nodeexp};
    } elsif ($nodeexp eq 'all') { 
        $where = "m.nodename like '%'";
    } else {
        die "$process_name: Error: Unknown node name[$nodeexp] given to -e option: $nodeexp\n";
    } 

    my $query = "SELECT m.nodename,m.domain FROM condor_config as c,machines as m WHERE ($where) and condor_type like '$condortype' and c.nodename = m.nodename;";
    writemsg "mysql QUERY: $query\n" if $debug;
    my $statement_handle = $db_handle->prepare($query) or die "$process_name: MySQL Error: ". $db_handle->errstr;
    
    # Send the query to the server:
    $statement_handle->execute or die "$process_name: MySQL Error: ". $statement_handle->errstr;
    writemsg sprintf "\t--> Returned %d results.\n", $statement_handle->rows if $debug;
    
    # Get the list of nodes this search returned:
    while (my $ref = $statement_handle->fetchrow_hashref) {
      writemsg Dumper $ref if $debug > 1;
      push @list, sprintf "%s.%s", $ref->{'nodename'}, $ref->{'domain'};
    }
    $statement_handle->finish;
    $db_handle->disconnect;
  }
  # Custom mysql query string used to select nodes:
  if ($query_string) {
    my $db_handle = DBI->connect("DBI:mysql:database=$database;host=$mysql_server", $user, $password, {RaiseError => 0})
      or die "$process_name: ERROR: can't connect to the mysql database server: $mysql_server";
    my $query = "SELECT nodename,domain FROM machines WHERE $query_string;";
    writemsg "mysql QUERY: $query\n" if $debug;
    my $statement_handle = $db_handle->prepare($query) or die "$process_name: MySQL Error: ". $db_handle->errstr;
    
    # Send the query to the server:
    $statement_handle->execute or die "$process_name: MySQL Error: ". $statement_handle->errstr;
    writemsg sprintf "\t--> Returned %d results.\n", $statement_handle->rows if $debug;
    
    # Get the list of nodes this search returned:
    while (my $ref = $statement_handle->fetchrow_hashref) {
      writemsg Dumper $ref if $debug > 1;
      push @list, sprintf "%s.%s", $ref->{'nodename'}, $ref->{'domain'};
    }
    $statement_handle->finish;
    $db_handle->disconnect;
  }
  if ($filelist) {
    print "using $filelist\n";
    open(FILELIST,"<$filelist");
    while ( my $line = <FILELIST> ) {
      chomp $line;
      next if not $line;      # Skip empty lines.
      next if $line =~ /^#/;  # Skip comment lines.
      push @list, $line;
    }
    close(FILELIST);
  }
  
  # Sort, remove duplicates and return the list of nodes:
  my @tmp = sort @list;
  my $p = shift @tmp or die "$process_name: Error: no hosts specified!\n";
  @list = ($p);
  my @dup;
  foreach my $n (@tmp) {
    if ($n ne $p) {
      push @list ,$n;
    } else {
      push @dup, (split(/\./,$n))[0];
    }
    $p = $n;
  }
  writemsg sprintf "\n$process_name: Warning: Removed %d duplicate node(s) from the list:  %s\n\n", $#dup+1, join ',', @dup if $#dup >= 0;
  @list;
}

# Function to write a message to the terminal, log file or both:
sub writemsg {
  my ($msg, $noverbose) = @_;
  
  print STDERR $msg if not $noverbose;
  print $log $msg if $log;
}

# Signal handler:
my %sig_count;
sub sig_handler {
  my ($event) = @_;
  my $watcher = $event->w;
  $signal = $watcher->signal;
  
  # Count how many times I have received this signal;
  #  - Should I count each signal separately or just a single counter?
  $sig_count{$signal}++;
  
  # How many times have I caught this signal?
  if ($sig_count{$signal} == 1) {
    # If this is the first signal then just stop forking new children and wait for the current ones to complete:
    writemsg sprintf "$process_name: Warning: Caught signal SIG%s(#%d), waiting for children to finish: $num_pinging pings and $num_running forks.\n",
      $signal, $sig_count{$signal};
    if ($event_watcher->is_suspended) {
      $event_watcher->at(time + $event_watcher_interval);
      $event_watcher->suspend(0);
      $event_watcher->again;
    }
  } elsif ($sig_count{$signal} > 1) {
    # I will exit if I am getting a lot of signals:
    if ($sig_count{$signal} > 3) {
      writemsg sprintf "$process_name: Warning: Caught signal SIG%s(#%d), killing all children: $num_pinging pings and $num_running forks!\n",
	$signal, $sig_count{$signal};
      unloop_all($stop_now);
    }
    # Caught duplicate signals - kill all of my children now:
    writemsg sprintf "$process_name: Warning: Caught signal SIG%s(#%d), killing all children: $num_pinging pings and $num_running forks!\n",
      $signal, $sig_count{$signal};
    foreach my $w (reverse all_watchers) {
      my $desc = $w->desc;
      my ($what, $node) = $desc =~ /(\w+)_read\[(.+)\]/;
      next if not defined $what;
      my $now = time;
      if ($what eq 'ping') {
	$ping{$node}{'end'} = $now;
	$ping{$node}{'time'} = $ping{$node}{'end'} - $ping{$node}{'start'};
	writemsg sprintf "\tGiving up on ping reply from $node: sent %.1f seconds ago.\n", $ping{$node}{'time'};
	push @dead_nodes, (split(/\./,$node))[0];
	$w->cancel;
	$num_pinging--;
      } elsif ($what eq 'pipe') {
	writemsg sprintf "\tKilling child[pid=%d] on $node: started %.1f seconds ago.\n", $pid{$node}, $now - $started{$pid{$node}};
	kill 'INT' => $pid{$node};
	# NOTE: Killing the ssh command will cause a read error on the pipe so I don't have to add it to the error_nodes list!
      }
    }
  }
  
  # Set flag to prevent anymore children from being started:
  $stop_now = $sig_count{$signal};
  unloop_all($stop_now) if $num_running == 0 and $num_pinging == 0;
}

# Print usage function:
sub print_usage {
  print STDERR <<EndOfUsage;

Usage: $process_name [-Options] "command args ...."

 Options:
  -A|--all		Run the command on ALL nodes (every experiment).
  -e|--exp A,B,C	Run the command on the experiment nodes: A, B & C.
  -r|--range typeX-Y	Run the command on nodes of type in range X-Y.
  -l|--list A,B,C	Run the command on the list of nodes: A, B & C.
  -q|--query 'where'	Run the command on the nodes matching your mysql query.
			 (used after WHERE keyword in searching machines table)
  -f|--filelist 'list'	Run the command on nodes listed in file 'list'.
			 (one node per line)
  -b|--batchtype 'type'	Run over nodes with Condor configuration of 'type' where
                         'type' is of format 'experiment'_'type', i.e. 'atlas_cas4'.
  -R|--root		Log in as root on the remote node (Default: yourself).
  -s|--scp file=dest	Send (scp) file to the nodes at dest (do not execute).
  -O|--sshopts 'opts'   Pass 'opts' as options to ssh 
                         (must be quoted: -O '-q -o StrictHostKeyChecking=no').
  -n|--num #		Run # commands in parallel (Default: $num).
  -F|--fps [#]		Set the number of forks/sec to # i
                         (Default: $forks_per_sec_default).
			 (Start with, then auto-adjust the above # of children).
  -m|--max #		Run at most # commands in parallel (Default: $max_num).
  -t|--timeout #	Timeout the children after # seconds (Default: $timeout).
  -p|--ping-only	Only ping the nodes (do NOT execute any command).
  -P|--no-ping		Do NOT ping the nodes before executing the command.
  -G|--grid		Run the command on the BNL RHIC & Atlas Grid nodes.
  -H|--hop		Hop to rsec00 then to the node (NOTE: 10x slower!).
  -L|--log <file>	Log the output of every command to: file.
  -D|--logdir <dir>	Log output from each node to its own file in: <dir>
  -c|--runlocal		Run the command locally (no ssh).  The argument NODE is
			 replaced with the hostname.
  -T|--sanetest		Run the command and pause after five forks.
  -v|--verbose		Enable verbose mode (output of command is written).
  -d|--debug		Enable debugging (use multiple times for more messages).
  -h|--help		Print this help message.

This script will run the requested command on multiple farm nodes in parallel.
The -F option is recommended and will result in faster operation, finishing in
about [# of nodes / $forks_per_sec_default forks per sec] +/- [command
execution time] seconds.  Interrupting this script once will safely prevent it
from starting new children and allow the current ones to finish.  A second
interrupt signal will cause it to immediately kill all of its children and
exit.

 Examples:

  Execute a command on a list of nodes, one at a time:

    \$ $process_name -n 1 -l rcas6001,rcas6005,rcas6028 "command args ...."

  Run the command on 5 rcas & 5 rcrs nodes in a range simultaneously:

    \$ $process_name -n 10 -r rcas6014-6018,rcrs4023-6027 "command args ...."

  Run the command on all star nodes & phenix cas nodes, as fast as possible:

    \$ $process_name -F -e star,phenix-cas "command args ...."

  Send the file /local/file to all of the atlas node at /dest/path/file2:

    \$ $process_name -R -F -e atlas -L log -v -s /local/file=/dest/path/file2

  If the above file was a script that was staged, now you can execute it:

    \$ $process_name -R -F -e atlas -L log -v /dest/path/file2

  Run command as root on all 1.4GHz IBM machines:

    \$ $process_name -R -q "brand like 'IBM-1.4'" "command args...."

  Run command as root on all nodes nodes, as fast as possible with logging:

    \$ $process_name -R -A -F -L log -v "command args ...."

  Echo each hostname locally:

    \$ $process_name -n 10 -t 900 -L log -c -e phobos-cas "/bin/echo NODE"

EndOfUsage
  
  exit 0;
}

#
# End file.
#
