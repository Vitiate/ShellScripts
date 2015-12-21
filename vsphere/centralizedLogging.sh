### SYSLOG CONFIGURATION ###
esxcli system syslog config set --default-rotate 20 --loghost udp://elk.test.ca:6060
 
# change the individual syslog rotation count
esxcli system syslog config logger set --id=hostd --rotate=20 --size=2048
esxcli system syslog config logger set --id=vmkernel --rotate=20 --size=2048
esxcli system syslog config logger set --id=fdm --rotate=20
esxcli system syslog config logger set --id=vpxa --rotate=20
 
 
### FIREWALL CONFIGURATION ###

# add custom firewall rule for outbound udp 6060
cat >/etc/vmware/firewall/Syslog-6060.xml << __SYSLOG_CONFIG_
<ConfigRoot>
<service id='0000'>
<id>AU-Syslog-6060</id>
<rule id = '0000'>
<direction>outbound</direction> 
<protocol>udp</protocol>    
<porttype>dst</porttype>       
<port>6060</port>          
</rule>              
<enabled>true</enabled>               
<required>false</required>                
</service>                 
</ConfigRoot>
__SYSLOG_CONFIG_

# correct perms on new file
chmod 444 /etc/vmware/firewall/Syslog-6060.xml

# refresh the firewall rules
esxcli network firewall refresh

# open httpClient port so we cann connect to vcenter
esxcli network firewall ruleset set -e true -r httpClient

# restart syslog
esxcli system syslog reload

esxcli storage nmp satp rule add -s "VMW_SATP_ALUA" -P "VMW_PSP_RR" -O "iops=1" -c "tpgs_on" -V "3PARdata" -M "VV" -e "HP 3PAR Custom Rule"

# backup ESXi configuration to persist changes
/sbin/auto-backup.sh