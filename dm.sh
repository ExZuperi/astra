#! /bin/bash

#Sources fix
astraVersion=$(cat /etc/astra_version)
echo "deb http://dl.astralinux.ru/astra/frozen/1.7_x86-64/$astraVersion/repository-base/ 1.7_x86-64  main contrib non-free" > /etc/apt/sources.list
echo "deb http://dl.astralinux.ru/astra/frozen/1.7_x86-64/$astraVersion/repository-extended/ 1.7_x86-64  main contrib non-free" >> /etc/apt/sources.list
echo "deb http://dl.astralinux.ru/astra/frozen/1.7_x86-64/$astraVersion/repository-main/ 1.7_x86-64  main contrib non-free" >> /etc/apt/sources.list
apt update

#Going to AD
apt install fly-admin-ad-client -y
read -p "AD net: " ADnet
read -p "DC name: " DCname
read -p "User admin: " adminName
read -p "Pass: " adminPass

astra-winbind -dc $DCname.$ADnet -u $adminName -p $adminPass
# TODO: Is it required? reboot

#DM preinstall
# 	Net Core
sudo apt install ca-certificates apt-transport-https -y
wget -O - https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null
sudo wget https://packages.microsoft.com/config/debian/10/prod.list -O /etc/apt/sources.list.d/microsoft-prod.list
sudo apt update
sudo apt install dotnet-sdk-6.0 -y

#	PostgreSQL
sudo apt install postgresql-11 -y
read -p "Pass of PSQL admin?: " PSQLpass
sudo -u postgres psql -c "alter user postgres with password '$PSQLpass'"

#	DM packages
apt install socat conntrack -y

#	Folder and install
mkdir /dm
mv i* /dm/
cd /dm/
tar xvf iw_devicemonitor*

#DM platform
./setup.py install
kubectl get pods -n infowatch 
kubectl get configmap nginx-config -o yaml -n infowatch > /tmp/n.yaml
# TODO: Add string to file
nano /tmp/n.yaml
kubectl apply -f /tmp/n.yaml
kubectl rollout restart deployment webgui-central -n infowatch

#DM server
#	Certificates import
read -p "TM server ip: " TMip
read -p "User: " TMuser
scp $TMuser@$TMip:/opt/iw/tm5/etc/cert/trusted_certificates /tmp/tmca.crt
echo -n | openssl s_client -connect $TMip:443 | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /tmp/site-certificate.crt
kubectl get secret -n infowatch epeventskeys-central -o 'go-template={{index .data "tls.crt"}}' | base64 -d > /tmp/plca.crt
cp /tmp/tmca.crt /usr/local/share/ca-certificates/
cp /tmp/site-certificate.crt /usr/local/share/ca-certificates/
cp /tmp/plca.crt /usr/local/share/ca-certificates/
update-ca-certificates
kubectl get secret guardkeys-central -n infowatch -o 'go-template={{index .data "ec256-public.pem"}}' | base64 -d > /tmp/guard.pem
echo "Platform key is on: /tmp/guard.pem"

#	Install script run
chmod +x ./install.sh
./install.sh