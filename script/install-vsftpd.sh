#!/bin/sh
## yum install vsftpd service 
## this script is interactive.please input vsftp user.

function install_vsftpd(){
###############################################################################
yum -y install vsftpd
mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
cat >/etc/vsftpd/vsftpd.conf <<\EOF
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
xferlog_enable=YES
xferlog_std_format=YES
xferlog_file=/var/log/xferlog
dual_log_enable=YES
vsftpd_log_file=/var/log/vsftpd.log
connect_from_port_20=YES
xferlog_std_format=YES
listen=YES
listen_ipv6=NO
pam_service_name=vsftpd
userlist_enable=YES
tcp_wrappers=YES
chroot_local_user=YES
chroot_list_enable=NO
allow_writeable_chroot=YES
pasv_enable=YES
pasv_min_port=9001
pasv_max_port=9100
EOF
###############################################################################
}

function add_user(){
###############################################################################
echo -e "\e[32mNote: ftp采用被动模式，被动模式端口为：9001~9100 \e[0m"
read -p "请输入新增的用户名（譬如ftpuer01）：" user
useradd -d /home/www $user -s /sbin/nologin
read -p "请输入新用户的密码（注意不要跟用户名一样）：" password
echo -e  "\e[32m$password | passwd --stdin $user \e[0m"
sed -i '/pam_listfile.so/d' /etc/pam.d/vsftpd
sed -i '/pam_shells.so/d' /etc/pam.d/vsftpd
###############################################################################
}

function startup_vsftpd(){
###############################################################################
systemctl enable vsftpd
systemctl restart vsftpd
ps -ef |grep vsftpd
ss -tnl |grep 21
echo -e "\e[32mNote: 如果出现vsftpd进程和21号端口，说明安装成功！\e[0m"
echo -e  "\e[32mNote: 请使用"ftp 本地内网IP"进行测试！\e[0m"
###############################################################################
}

install_vsftpd
add_user
startup_vsftpd

