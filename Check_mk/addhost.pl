#!/usr/bin/perl
# This script injects hosts into check_mk hosts.mk files.
# Used by the importInventory script to import VMWare inventory into CheckMK

use warnings;
use Getopt::Long;
use File::Copy qw(move);
use File::Basename qw( fileparse );
use File::Path qw( make_path );
use File::Spec;

my $inhosts = 0;
my $ipupdate = '';
my $inattribs = 0;
my $arttriblast = '';

my $hostsstring = '';
my $attribsstring = '';
my @hostsarray;
my @attribarray;
my @iparray;
my $filename = '';
my $otherstrings = '';

my $hostname = '';
my $ipaddress= '';

GetOptions ("filename=s" => \$filename,
			"hostname=s" => \$hostname,
			"ipaddress=s" => \$ipaddress);

if (($filename eq '' ) or ($hostname eq '' )) { 
	print "Error in command line arguments\nMust specify $0 --filename=/path/to/hosts.mk --hostname=Hostname --ipaddress=IPAddress\n";
	exit 1
}
if (-e $filename ){ # Check if the file exists, if it does open it.

} else { # create the file and directory if it does not exist
	my ( $file, $directories ) = fileparse $filename;
	if ( !$file ) {
	    $file = 'hosts.mk';
	    $filename = File::Spec->catfile( $filename, $file );
	}

	if ( !-d $directories ) {
	    make_path $directories 
	    	or die "Failed to create path: $directories";
	}
	
	open(my $newfh, '>:encoding(UTF-8)', $filename)
		or die "Could not create '$filename' $!";
	close $newfh;
}

open(my $fh, '<:encoding(UTF-8)', $filename)
	or die "Could not open '$filename' $!";

while (my $row = <$fh>) {
	chomp $row;
	if ($row =~ /^all_hosts/) { $inhosts = 1;}
	if (($row =~ /]$/) and ($inhosts == 1)) { $inhosts = 0;}
	if ($row =~ /^ipaddresses.update/) {
		$row =~ s/^ipaddresses.update\(\{//g;
		$row =~ s/\}\)//g;
		$ipupdate = $row;
		print "IP LIST: $ipupdate \n";
		$row='';
	}
	if ($row =~ /^host_attributes.update()/){$inattribs = 1;}
	if (($row =~ /\)$/ ) and ($inattribs == 1)) { 
		$inattribs = 0;
		$arttriblast = $row;
		$row='';
	}
	if ($inhosts){
		$row =~ s/all_hosts \+\= \[//g;
		$row =~ s/\s{2}\ //g;
		$row =~ s/\]//g;
		$hostsstring = "$hostsstring $row";
		$row='';
	}
	if ($inattribs){
		$row =~ s/host_attributes.update\(\s*//g;	# Remove header
		$row =~ s/^\{//g;							# Remove starting brace
		$row =~ s/\s{1}\ //g;						# Sanatize spaces
		$row =~ s/\}\)//g;							# Remove tail
		$attribsstring = "$attribsstring $row";
		if ($row =~ /\}\,/ ){						# Detect end of item and mark it
			$attribsstring = "$attribsstring !!";
		}
		$row='';
	}
	if ((!$inhosts) and (!$inattribs)){
		if (($row !~ /^]/) and ($row !~ /^\#/)) {
			$otherstrings = "$otherstrings\n$row";
		}
	}
}

close $fh;

@hostsarray = split(/\,/, $hostsstring);
@attribarray = split(/!!/, $attribsstring);
@iparray = split(/\,/, $ipupdate);

push @hostsarray, "\"$hostname|prod|lan|tcp|wato|/\" + FOLDER_PATH + \"/\"";
if ( length $ipaddress > 8){
	push @iparray, "'$hostname': u'$ipaddress'";
	push @attribarray, "'$hostname': {'ipaddress': u'$ipaddress'},";
} else {
	push @attribarray, "'$hostname': {},";
}

move $filename, $filename . ".backup";

open(my $fho, '>', $filename);
print $fho "# Written by WATO
# encoding: utf-8

all_hosts += [\n";
foreach my $host (@hostsarray) {
	print $fho "$host,\n";
}

print $fho "]\n";

print $fho "# Explicit IP addresses\n";

print $fho "ipaddresses.update({" . join (", ", @iparray) . "})\n";


print $fho "$otherstrings";

print $fho "
# Host attributes (needed for WATO)\n
host_attributes.update({\n";
foreach my $attrib (@attribarray) {
	print $fho "$attrib\n";
}

print $fho "})
";
close $fho;