#!/bin/bash

#Sources fix
astraVersion=$(cat /etc/astra_version)
echo "deb http://dl.astralinux.ru/astra/frozen/1.7_x86-64/$astraVersion/repository-base/ 1.7_x86-64  main contrib non-free" > /etc/apt/sources.list
apt update

#Going to AD
apt install fly-admin-ad-client -y
read -p "AD net: " ADnet
read -p "DC name: " DCname
read -p "User admin: " adminName
read -p "Pass: " adminPass 
astra-winbind -dc $DCname.$ADnet -u $adminName -p $adminPass
# TODO: Is it required? reboot

#TM preinstall
#	Package 
apt install lsb-release lshw ntp ntpdate gsfonts libnewt0.52 libwmf-bin libwmf0.2-7 libxml2-utils python-newt -y

#	Hosts file
urIP=$(ifconfig eth0 | awk '/inet / {split($2, a, ":"); print a[1]}')
hostname=$(hostname)
newEntry="$urIP $hostname.$ADnet $hostname"
sed -i "2s/.*/$newEntry/" /etc/hosts

#	SSH
/etc/init.d/ssh start
systemctl enable ssh

#	Mandat
pdpl-user -i 63 root

#Folder and install
mkdir /distr
mv ./iwtm-* /distr/
cd /distr
chmod +x ./iwtm-installer*
./iwtm-installer*
