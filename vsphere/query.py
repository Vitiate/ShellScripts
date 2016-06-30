#!/usr/bin/env python2
# Copyright (C) 2013 - Remy van Elst
# Mostly re-written for speed and convinence in 2016. - Jeremy Tirrell

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pysphere
import re
import sys
import argparse
import os

try:
    import json
except ImportError:
    import simplejson as json

# Get envrionment variables, if they do not exist set values to ''
# Done to keep passwords user based and to maintain compatability with ansible
server_fqdn = os.environ.get('VCENTER', "")
server_username = os.environ.get('VCUSER', "")
server_password = os.environ.get('VCPASS', "")
ip = os.environ.get('RETURNIP', "0")

guest_id_filer = "rhel"     # Custom filter to ONLY see machines of this guest_id; this is to filter out appliance machines

def vcenter_connect(server_fqdn, server_username, server_password):
    vserver = pysphere.VIServer()
    try:
        vserver.connect(server_fqdn, server_username, server_password)
    except Exception as error:
        print(('Could not connect to vCenter: %s') % (error))
    return vserver

# Test if server is a linux machine based on guest_os string
def server_guest_is_linux(guest_os):
    if 'linux' in guest_os.lower() \
            or 'ubuntu' in guest_os.lower() \
            or 'centos' in guest_os.lower():
        return True
    return False

def hostinfo(name):
    vserver = vcenter_connect(server_fqdn, server_username, server_password)
    try:
        vm = vserver.get_vm_by_name(name)
    except Exception as e:
        print("[Error]: %s" % e)
        sys.exit(1)

    # Inject some variables for all hosts
    vars = {
        'admin': 'sysadmin@example.org',
        'source_database': 'VMWare'
    }

    #if 'ldap' in name.lower():
    #    vars['baseDN'] = 'dc=example,dc=org'

    print json.dumps(vars, indent=4)

def printHelp():
    parser.print_help()
    print '\n'
    print 'Environment variables can also be set to configure these settings'
    print 'VCENTER = fqdn of vsphere server'
    print 'VCUSER  = user name'
    print 'VCPASS  = password'
    print 'RETURNIP = 0 or 1, 1 returns a list of ip as inventory, 0 the default returns the vmname'
    print 'export VCENTER=vcserver.vmware.local and other variables prior to execution.'

def grouplist():
    inventory = {}
    vms_info = {}
    properties = [
        'guest.guestState',
        'guest.toolsVersionStatus',
        'guest.guestId',
        'guest.guestFullName',
        'guest.ipAddress',
        'guest.net',
        'name',
        'parent',
    ]

    vserver = vcenter_connect(server_fqdn, server_username, server_password)
    props = vserver._retrieve_properties_traversal(property_names=properties, obj_type='VirtualMachine') 
    for prop in props: 
        mor = prop.Obj 
        vm = {} 
        for p in prop.PropSet: 
            vm[p.Name] = p.Val 
        vms_info[mor] = vm 

    #Get names from all the parents 
    parent_list = [vm['parent'] for vm in vms_info.values() if 'parent' in vm] 
    props = vserver._get_object_properties_bulk(parent_list, {'ManagedEntity':['name']}) 
    vserver.disconnect
    #build a parent_mor=>parent_name dictionary 
    parent_info = {} 
    for prop in props: 
        parent_info[prop.Obj] = prop.PropSet[0].Val 

    #add the parent names to the vms_info dictionary 
    for vm_info in vms_info.values(): 
        parent = vm_info.get('parent') 
        if not parent or parent not in parent_info: continue 
        vm_info['parent_name'] = parent_info[parent] 
        vm_info['parent_type'] = parent.get_attribute_type() 

    inventory["no_group"] = {
        'hosts': []
    }

    for vsphere_vm in vms_info.values():
        guest_state = vsphere_vm['guest.guestState']
        if guest_state == 'notRunning':                                 # A non running vm is not something we care about, or a vapp.
            continue
        if 'guest.guestFullName' not in vsphere_vm:                     # Check for the fullname key, if it does not exist skip this vm
            continue
        if 'guest.guestId' not in vsphere_vm:                           # Check for the guestId key, if it does not exist skip this vm
            continue
        if 'parent_type' not in vsphere_vm:                             # No parent means that this is probably a vapp machine, ignore it.
            continue
        guest_os = vsphere_vm['guest.guestFullName']
        guest_id = vsphere_vm['guest.guestId']                                         
        virtual_machine_name = vsphere_vm['name']
        virtual_machine_ip = vsphere_vm['guest.ipAddress']

        if guest_id_filer:                                                  # if there is a guest_id_filter set
            if guest_id_filer not in guest_id.lower():                      # and the guest id does not match
                continue                                                    # continue to the next machine

        if server_guest_is_linux(guest_os):                                 # Filter out all non-Linux machines
            if ip == "0":
                inventory['no_group']['hosts'].append(virtual_machine_name)
            else:
                if virtual_machine_ip is not None:
                    inventory['no_group']['hosts'].append(virtual_machine_ip)

    print json.dumps(inventory, indent=4)

# Argements are no longer required, to keep ansible compatability
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--server', help='fqdn of vsphere server',
            action='store')
    parser.add_argument('-u', '--username', help='your vsphere username',
            action='store',)
    parser.add_argument('-p', '--password', help='your vsphere password',
            action='store')
    parser.add_argument('-l', '--list', help='List all guest VMs',
            action='store_true')
    parser.add_argument('-g', '--guest', help='Print a single guest',
            action='store')
    parser.add_argument('-n', '--no-ssl-verify',
        help="Do not do SSL Cert Validation", action='store_true')

    args = parser.parse_args()
    if args.no_ssl_verify is True:
        import ssl
        try:
            _create_unverified_https_context = ssl._create_unverified_context
        except AttributeError:
            # Legacy Python that doesn't verify HTTPS certificates by default
            pass
        else:
            # Handle target environ.getment that doesn't support HTTPS verification
            ssl._create_default_https_context = _create_unverified_https_context

    if args.server:
        server_fqdn = args.server

    if args.username:
        server_username = args.username

    if args.password:
        server_password = args.password
    else:
        if not server_password:                                             # If no password set
            if server_fqdn:                                                 # If the servername is set, then ask for a password.
                import getpass
                server_password = getpass.getpass()

    if (server_fqdn, server_username, server_password):

        if args.list:
            grouplist()
        elif args.guest:
            hostinfo(args.guest)
        else:
            printHelp()
            sys.exit(1)
    else:
        printHelp()
        sys.exit(1)
