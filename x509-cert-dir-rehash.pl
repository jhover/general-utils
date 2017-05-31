#!/usr/bin/perl

# This is a modified version of the OpenSSL 1.0.0 c_rehash script
# adapted for use in GSI/GT environments.

# Perl x509-cert-dir-rehash script, scan all files in a directory
# and add symbolic links to their hash values.

# USAGE: x5009-cert-dir-hash [<dir>]
# where <dir> is a directory that contains certificate, crl and signing_policy
# files that are named as <hash>.[0-9]*, <hash>.r[0-9]* and <hash>.signing_policy
# respectively. If no <dir> is given, it's assumed to be the value of the environment
# variable X509_CERT_DIR. This script attempts to create symbolic links to these files
# in the given directory using new hash values introduced in OpenSSL 1.0.0. The symbolic
# links will be named <new_hash>.0, <new_hash>.r0 and <new_hash>.signing_policy
# respectively. The script will display ERROR messages in cases where there's a hash
# collision and such and the user is expected to manually handle these cases.
# Please see http://www.cilogon.org/openssl-1.0 for more information.

my $openssl;

if(defined $ENV{OPENSSL}) {
	$openssl = $ENV{OPENSSL};
} else {
	$openssl = "openssl";
	$ENV{OPENSSL} = $openssl;
}

my $pwd;
eval "require Cwd";
if (defined(&Cwd::getcwd)) {
	$pwd=Cwd::getcwd();
} else {
	$pwd=`pwd`; chomp($pwd);
}
my $path_delim = ($pwd =~ /^[a-z]\:/i) ? ';' : ':'; # DOS/Win32 or Unix delimiter?

if(! -x $openssl) {
	my $found = 0;
	foreach (split /$path_delim/, $ENV{PATH}) {
		if(-x "$_/$openssl") {
			$found = 1;
			$openssl = "$_/$openssl";
			last;
		}	
	}
	if($found == 0) {
		print STDERR "x509-cert-dir-rehash: rehashing skipped ('openssl' program not available)\n";
		exit 0;
	}
}

# make sure we are running version 1 of OpenSSL
my $version = `$openssl version`;
my @vers1 = split(/ /, $version);
my @vers2 = split(/\./, $vers1[1]);
if ($vers2[0] ne "1") {
	print "ERROR: OpenSSL version is NOT 1.x.x\n";
	exit 1;
}

if(@ARGV) {
	@dirlist = @ARGV;
} elsif($ENV{X509_CERT_DIR}) {
	@dirlist = split /$path_delim/, $ENV{X509_CERT_DIR};
} else {
	print STDERR "usage: x509-cert-dir-rehash <dir>\n";
	exit 1;
}

if (-d $dirlist[0]) {
	chdir $dirlist[0];
	$openssl="$pwd/$openssl" if (!-x $openssl);
	chdir $pwd;
}

foreach (@dirlist) {
	if(-d $_ and -w $_) {
		hash_dir($_);
	}
}

sub hash_dir {
	print "Processing files in directory $_[0]\n";
	chdir $_[0];
	opendir(DIR, ".");
	my @flist = readdir(DIR);
	# Delete any existing symbolic links
	#foreach (grep {/^[\da-f]+\.r{0,1}\d+$/} @flist) {
	#	if(-l $_) {
	#		unlink $_;
	#	}
	#}
	closedir DIR;
	FILE: foreach $fname (grep {/\.[r]*[0-9]*$/} @flist) {
		# Check to see if certificates and/or CRLs present.
		if ($fname eq "." or $fname eq "..") {
			next;
		}
		my ($cert, $crl) = check_file($fname);
		if(!$cert && !$crl) {
			print STDERR "WARNING: $fname does not contain a certificate or CRL: skipping\n";
			next;
		}
		link_hash_cert($fname) if($cert);
		link_hash_crl($fname) if($crl);
	}
}

sub check_file {
	my ($is_cert, $is_crl) = (0,0);
	my $fname = $_[0];
	open IN, $fname;
	while(<IN>) {
		if(/^-----BEGIN (.*)-----/) {
			my $hdr = $1;
			if($hdr =~ /^(X509 |TRUSTED |)CERTIFICATE$/) {
				$is_cert = 1;
				last if($is_crl);
			} elsif($hdr eq "X509 CRL") {
				$is_crl = 1;
				last if($is_cert);
			}
		}
	}
	close IN;
	return ($is_cert, $is_crl);
}


# Link a certificate to its subject name hash value, each hash is of
# the form <hash>.<n> where n is an integer. If the hash value already exists
# then we need to up the value of n, unless its a duplicate in which
# case we skip the link. We check for duplicates by comparing the
# certificate fingerprints

sub link_hash_cert {
		my $fname = $_[0];
		$fname =~ s/'/'\\''/g;
		my ($hash, $fprint) = `"$openssl" x509 -hash -fingerprint -noout -in "$fname"`;
		chomp $hash;
		chomp $fprint;
		$fprint =~ s/^.*=//;
		$fprint =~ tr/://d;
		my $suffix = 0;
		$old_hash = $fname;
		$old_hash =~ s/\.[0-9]*//;
		if ($old_hash eq $hash) {
			return;
		}
		$hash .= ".$suffix";
		if (-e $hash) {
			# See if the fingerprints match
			my ($hash2, $fprint2) = `"$openssl" x509 -hash -fingerprint -noout -in "$hash"`;
			chomp $hash2;
			chomp $fprint2;
			$fprint2 =~ s/^.*=//;
			$fprint2 =~ tr/://d;

			if ("$hash" eq "$hash2.$suffix" and "$fprint" eq "$fprint2") {
				# Duplicate
				goto SIGNING_POLICY;
			} else {
				print "ERROR: Hash collision; unable to create " .
					"symlink $hash ($hash2) ($fprint) ($fprint2) to file $fname\n";
				goto SIGNING_POLICY;
			}
		}
		# print "$fname => $hash\n";
		$symlink_exists=eval {symlink("",""); 1};
		if ($symlink_exists) {
			symlink $fname, $hash;
		} else {
			open IN,"<$fname" or die "can't open $fname for read";
			open OUT,">$hash" or die "can't open $hash for write";
			print OUT <IN>;	# does the job for small text files
			close OUT;
			close IN;
		}

SIGNING_POLICY:
		# GSI ADDITION: Also handle any <hash>.signing_policy file
		$fname =~ s/\.[0-9]*/.signing_policy/;
		if (-e $fname) {
			$hash =~ s/\.[0-9]*/.signing_policy/;
			#print "$fname => $hash\n";
			if (-e $hash) {
				my $different = system("cmp", "-s", $fname, $hash);
				if ($different != 0) {
					print "NON-FATAL ERROR: $hash already exists and " .
						"it's different from $fname; perhaps " .
						"$hash was created at bootstrap time " .
						"and needs to be replaced with a " .
						"symlink of same name to $fname? " .
						"Please compare " .
						"the contents of $hash and $fname " .
						"before making $hash a symlink to " .
						"$fname.\n";
				}
				return;
			}
			if ($symlink_exists) {
				symlink $fname, $hash;
			} else {
				system ("cp", $fname, $hash);
				open IN,"<$fname" or die "can't open $fname for read";
				open OUT,">$hash" or die "can't open $hash for write";
				print OUT <IN>;	# does the job for small text files
				close OUT;
				close IN;
			}
		}
}

# Same as above except for a CRL. CRL links are of the form <hash>.r<n>

sub link_hash_crl {
		my $fname = $_[0];
		$fname =~ s/'/'\\''/g;
		my ($hash, $fprint) = `"$openssl" crl -hash -fingerprint -noout -in '$fname'`;
		chomp $hash;
		chomp $fprint;
		$fprint =~ s/^.*=//;
		$fprint =~ tr/://d;
		my $suffix = 0;
		$old_hash = $fname;
		$old_hash =~ s/\.r[0-9]*//;
		if ($old_hash eq $hash) {
			return;
		}
		$hash .= ".r$suffix";
		if (-e $hash) {
			my ($hash2, $fprint2) = `"$openssl" crl -hash -fingerprint -noout -in "$hash"`;
			chomp $hash2;
			chomp $fprint2;
			$fprint2 =~ s/^.*=//;
			$fprint2 =~ tr/://d;

			if ("$hash" eq "$hash2.r$suffix" and "$fprint" eq "$fprint2") {
				# Duplicate
				return;
			} else {
				print "ERROR: Hash collision; unable to create " .
					"symlink $hash to file $fname\n";
				return;
			}
		}
		#print "$fname => $hash\n";
		$symlink_exists=eval {symlink("",""); 1};
		if ($symlink_exists) {
			symlink $fname, $hash;
		} else {
			system ("cp", $fname, $hash);
		}
}

