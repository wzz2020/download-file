#!/bin/sh

function rsyncd_install(){
########################################################################################
yum -y install rsync

if [ -f /etc/rsyncd.conf ];then
  mv /etc/rsyncd.conf /etc/rsyncd.conf.bak
fi
cat > /etc/rsyncd.conf <<\EOF
uid = root
gid = root
use chroot = yes
max connections = 10
lock file=/var/run/rsyncd.lock
log file = /var/log/rsyncd.log
exclude = lost+found/
transfer logging = yes
timeout = 900
ignore nonreadable = yes
dont compress   = *.gz *.tgz *.zip *.z *.Z *.rpm *.deb *.bz2

[www]
path = /home/www
comment = mytest export area
read only = yes
list = no
auth users=rsyncuser
secrets file=/etc/rsyncdserver.passwd
hosts allow=*
EOF

if [ -f /etc/rsyncdserver.passwd ]; then
  mv /etc/rsyncdserver.passwd /etc/rsyncdserver.passwd.bak
fi
echo rsyncuser:123456 > /etc/rsyncdserver.passwd
chmod 600 /etc/rsyncdserver.passwd

systemctl enable rsyncd
systemctl start rsyncd
ss -tnl |grep 873
########################################################################################
}

function note_note(){
########################################################################################
if [ $? -eq 0 ]; then
  echo -e "\e[32mNote: Rsync server install completed.\e[0m"
  echo -e "\e[32mNote: Rsync server is read only model.\e[0m"
  echo -e "\e[32mNote: target use command 'yum -y install rsync' \e[0m"
  echo -e "\e[32mNote: target use command 'echo 123456 > /etc/rsyncdclient.passwd' \e[0m"
  echo -e "\e[32mNote: target use comand 'chmod 600 /etc/rsyncdclient.passwd' \e[0m"
  echo -e "\e[32mNote: target use command 'rsync  -arv  --progress --password-file=/etc/rsyncdclient.passwd   rsyncuser@192.168.11.9::www   /home/www/' \e[0m"
  echo -e "\e[32mNote: Rsync server is read noly. optinos: --remove-source-files \e[0m"
else
  echo -e "\e[32mNote: Rsync server install failed. \e[0m"
fi
########################################################################################
}

rsyncd_install
note_note

