#! /usr/bin/perl
#
# Require: libexpect-perl libfile-chdir-perl

use Expect;
use File::chdir;
use strict;

my $passphrase = 's3cr3t';
my $repository_dir = '/var/www/debian';
my $incoming_dir = "$repository_dir/incoming";
my $timeout = 7200;

sub remove {
	my ($distrib,$package) = @_;

	my $command = Expect->spawn("reprepro remove $distrib $package")
		or die "Cannot spawn: $!\n";

	$command->expect($timeout,
		[ qr/Please enter passphrase:/ => sub {
			my $exp = shift;
			$exp->send("$passphrase\n");
			exp_continue; } ],
		[ qr/There might be another instance with the/ => sub {
			exit(1); } ],
	);

	$command->soft_close();	
}

sub add {
	my ($distrib,$debfile) = @_;

	my $command = Expect->spawn("reprepro --ask-passphrase includedeb $distrib $debfile\n")
		or die "Cannot spawn: $!\n";

	$command->expect($timeout,
		[ qr/Please enter passphrase:/ => sub {
			my $exp = shift;
			$exp->send("$passphrase\n");
			exp_continue; } ],
		[ qr/There might be another instance with the/ => sub {
			exit(1); } ],
	);

	$command->soft_close();
}
	

$CWD = $repository_dir;

# Parse incoming
opendir (DH1, $incoming_dir) or die "Couldn't open dir '$incoming_dir': $!";
while (my $distrib = readdir(DH1)) {
	next if ($distrib =~ m/^\./);
	next unless (-d "$incoming_dir/$distrib");
	print "Inspecting: $distrib\n";

	opendir (DH2, "$incoming_dir/$distrib") or die "Couldn't open dir '$incoming_dir/$distrib': $!";
	while (my $file = readdir(DH2)) {
		next if ($file =~ m/^\./) or (-d "$incoming_dir/$distrib/$file");
		if ($file =~ m/([^_]+).*\.deb$/) {
			my $package = $1;
			print "Package: $package\n";
			my $published = `/usr/bin/reprepro list $distrib $package`; 
			if ($published =~ m/\s$package\s/) {
				print "*** $package already published: removing\n";
				remove($distrib, $package);
			}
			#if (($package =~ m/^apache2/) and ($package ne 'apache2-suexec')) {
			#	# Do NOT publish that ones (manual filter by olecam)
			#	print "*** Ignoring: $package\n";
			#	next;
			#}
			print "*** publishing: $file\n";
			add($distrib, "$incoming_dir/$distrib/$file");
		}
	}
	closedir(DH2);
}
closedir(DH1);
