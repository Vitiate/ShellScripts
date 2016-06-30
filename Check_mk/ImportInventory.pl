#!/usr/bin/perl -w
# Original Author: stumpr (http://communities.vmware.com/message/1265766#1265766)
# Heavily modified for use to take an inventory of VM's from virtual center and inject them into Check_MK via wato.

use strict;
use warnings;

use VMware::VIRuntime;
use Devel::Size qw(total_size);
use Time::HiRes qw(time);

# Add option to define datacenter.
my %opts = (
 datacenter => {
 type => "=s",
 variable => "datacenter",
 help => "DataCenter Name",
 required => 0,
 }
);

Opts::add_options(%opts);
Opts::parse();
Opts::validate();
Util::connect();
my fileprefix = '/omd/sites/SITE/etc/check_mk/conf.d/wato/AutoAdded'; # Prefix to create infrastructure under.
my @path;
my ($datacenter_name, $datacenter_views, $vmFolder_view, $indent, $start, $elapsed);
$datacenter_name = Opts::get_option("datacenter");

$indent = 0;
$start = time();
$datacenter_views = Vim::find_entity_views(
        view_type => 'Datacenter',
        properties => ["name", "vmFolder"]
);

$elapsed = time() - $start;
printf("Total size of Datacenter Views (Properties: name): %.2f KB in %.2fs\n", total_size($datacenter_views)/1024, $elapsed);
printf("Processing VM and Folder List:\n");
foreach ( @{$datacenter_views} )
{
        # If we are in the right DataCenter
        if ($_->name eq $datacenter_name) { 
                print "Datacenter: " . $_->name . "\n";
                # Process the folder tree
                TraverseFolder($_->vmFolder, $indent);
        }
}
$elapsed = time() - $start;
print "Traversed folders in $elapsed\n";

sub TraverseFolder
{
        # Work down the folder tree and create host.mk files for all inventory in the tree
        my ($entity_moref, $index) = @_;
        my ($num_entities, $entity_view, $child_view, $i, $mo, $vmname, $vmipaddress);

        $index += 4;

        $entity_view = Vim::get_view(
                mo_ref => $entity_moref,
                properties => ['name', 'childEntity']
        );

        $num_entities = defined($entity_view->childEntity) ? @{$entity_view->childEntity} : 0;
        if ( $num_entities > 0 )
        {
                foreach $mo ( @{$entity_view->childEntity} )
                {
                        $child_view = Vim::get_view(
                                mo_ref => $mo);
                        
                        # If the child item is a Virtual machine
                        if ( $child_view->isa("VirtualMachine") )
                        {
                                my $template = $child_view->config->template;
                                my $powerstate = '';
                                $powerstate = $child_view->runtime->powerState;
                                $vmname = $child_view->name;
                                $vmipaddress = $child_view->guest->ipAddress;

                                # If the Virtual Machine has an IP Address
                                if (defined $vmipaddress){
                                        # If the Virtual machine is not a Template
                                        if (!$template) {
                                                my $pathto = join ("/", @path);
                                                # Find out of the host exists in check_mk
                                                my $output = `check_mk --list-hosts | grep $vmname`;
                                                # if not then create the host.mk file
                                                if ($output eq ''){
                                                        print " " x $index . "Adding VM $vmname $vmipaddress\n";
                                                        $output = `perl /omd/sites/AUVC/local/share/addhost.pl --filename='$fileprefix/$pathto/hosts.mk' --hostname=$vmname --ipaddress $vmipaddress`;
                                                        # Perform an inventory of the new host
                                                        $output = `check_mk -II $vmname`; 
                                                        print $output . "\n";
                                                } else {
                                                        # VM already exists
                                                        print " " x $index . "Not adding Existing VM $vmname \n";
                                                }
                                                print " " x $index . "Virtual Machine: " . $child_view->name . "\n" ;
                                        } else {
                                                # VM is a template
                                                print " " x $index . "Not adding Template VM $vmname \n";
                                        }
                                } else {
                                        # VM does not have an IP address (we need one for Check_MK to add the machine
                                        print " " x $index . "Not adding VM with no ipAddress $vmname \n";
                                }
                        }
                        # If the Child Item is a folder
                        if ( $child_view->isa("Folder") )
                        {
                                # Add the folder to the path array
                                push @path, $child_view->name;
                                # Display the path
                                print join ("/", @path) . "\n";
                                $child_view = Vim::get_view(
                                        mo_ref => $mo, 
                                        properties => ['name', 'childEntity']
                                );
                                # Move down the folder structure
                                TraverseFolder($mo, $index);
                        }
                }
        }
        # Remove the folder from the current path, if we get to this point we are back to the root.
        pop @path;
}
# Reload the Check_MK inventory / compile config.
my $output = `check_mk --reload`;

Util::disconnect();
