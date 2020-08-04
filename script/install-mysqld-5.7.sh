#!/bin/sh
## 提示：本脚本只支持centos 7 安装MySQL版本5.7 (二进制GA版本)
## 提示：本版本MySQL安装后只加载和使用basedir目录下的my.cnf，如果其他地方有my.cnf文件则## MySQL无法启动
# set -e

WORK_HOME=/usr/local/src
NEW_USER=mysql

function install_base(){
#############################################################################
yum  -y install libaio numactl wget epel-release

if [ -f /etc/my.cnf ]; then
  mv /etc/my.cnf* /tmp/
fi
#############################################################################
}

function create_user_optimization(){
#############################################################################
id ${NEW_USER} >/dev/null 2>&1
if [ $? -eq 0 ]; then
  grep ${NEW_USER} /etc/passwd
  echo -e "\e[0;32mNote: ${NEW_USER} user already exists.\e[0m"
else
  useradd -M -s /bin/nologiin ${NEW_USER}
  echo -e "\e[0;32mNote: ${NEW_USER} user crate finished.\e[0m"
fi

grep -r 65535 /etc/security/*
if [ $? -eq 0 ]; then
  echo -e "\e[32mNote: System optimization completed..\e[0m"
else
cat >> /etc/security/limits.conf << \EOF
*               soft    nproc           65535
*               hard    nproc           65535
*               soft    nofile          65535
*               hard    nofile          65535
EOF
ulimit -n 65535
ulimit -u 65535
fi
echo -e "\e[32mNote: This system optimization requires a reboot of the computer to finally take effect.\e[0m"
#############################################################################
}

function download_install_mysql(){
#############################################################################
echo -e "\e[0;32m在线下载二进制MySQL安装包 \e[0m"
if [ ! -f ${WORK_HOME}/mysql-5.7.31-linux-glibc2.12-x86_64.tar.gz ]; then
  wget https://cdn.mysql.com//Downloads/MySQL-5.7/mysql-5.7.31-linux-glibc2.12-x86_64.tar.gz -P  ${WORK_HOME}/
fi
if [ -d ${WORK_HOME}/mysql-5.7.31-linux-glibc2.12-x86_64 ]; then
  rm -fr ${WORK_HOME}/mysql-5.7.31-linux-glibc2.12-x86_64
fi
echo -e "\e[0;32mNote: 解压二进制MySQL安装包中。。。\e[0m"
tar xf ${WORK_HOME}/mysql-5.7.31-linux-glibc2.12-x86_64.tar.gz -C  /usr/local/
ln -s /usr/local/mysql-5.7.31-linux-glibc2.12-x86_64 /usr/local/mysql
mkdir -p /usr/local/mysql/{data,log}
chown -R mysql.mysql /usr/local/mysql/
#############################################################################
}

function create_conf_initmysql(){
#############################################################################
echo -e "\e[0;32mNote: 生成配置MySQL配置文件\e[0m"
cat  > /usr/local/mysql/my.cnf  << \EOF
[client]
port = 3306
socket = /usr/local/mysql/data/mysql.sock
 
[mysqld]
server_id=10
port = 3306
user = mysql
character-set-server = utf8mb4
default_storage_engine = innodb
log_timestamps = SYSTEM
socket = /usr/local/mysql/data/mysql.sock
basedir = /usr/local/mysql
datadir = /usr/local/mysql/data/
pid-file = /usr/local/mysql/data/mysql.pid
max_connections = 1000
max_connect_errors = 1000
table_open_cache = 1024
max_allowed_packet = 128M
open_files_limit = 65535
log-bin=mysql-bin
skip-name-resolve
symbolic-links = 0
explicit_defaults_for_timestamp = true
# skip-grant-tables  ## 忘记密码选项
#####====================================[innodb]==============================
innodb_buffer_pool_size = 768M           #使用物理内存的75%
innodb_buffer_pool_instances = 2     #默认值,或者逻辑CPU数量
innodb_buffer_pool_chunk_size = 128MB
innodb_file_per_table = 1
innodb_write_io_threads = 4
innodb_read_io_threads = 4
innodb_purge_threads = 2
innodb_flush_log_at_trx_commit = 1
innodb_log_file_size = 512M
innodb_log_files_in_group = 2
innodb_log_buffer_size = 16M
innodb_max_dirty_pages_pct = 80
innodb_lock_wait_timeout = 30
innodb_data_file_path=ibdata1:1024M:autoextend
 
#####====================================[log]==============================
log_error = /usr/local/mysql/log/mysql-error.log 
slow_query_log = 1
long_query_time = 1 
slow_query_log_file = /usr/local/mysql/log/mysql-slow.log
expire_logs_days = 7
sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES
EOF

echo -e "\e[0;32mNote: MySQL初始化中\e[0m"
/usr/local/mysql/bin/mysqld --initialize --user=mysql --basedir=/usr/local/mysql --datadir=/usr/local/mysql/data --innodb_undo_tablespaces=3 --explicit_defaults_for_timestamp  &> /usr/local/mysql/log/mysqld.log

echo -e "\e[0:32mNote: MYSQL初始化日志查看\e[0m"
cat /usr/local/mysql/log/mysqld.log

chown -R mysql:mysql /usr/local/mysql/

cat > /etc/profile.d/mysql.sh << \EOF
export PATH=$PATH:/usr/local/mysql/bin
EOF

source  /etc/profile.d/mysql.sh

echo -e "\e[0;32mNote: 生成systemd服务文件\e[0m"
#编写启动服务文件
cat  > /usr/lib/systemd/system/mysqld.service <<\EOF
[Unit]
Description=MySQL Server
Documentation=man:mysqld(8)
Documentation=http://dev.mysql.com/doc/refman/en/using-systemd.html
After=network.target
After=syslog.target

[Install]
WantedBy=multi-user.target

[Service]
User=mysql
Group=mysql
Type=forking
PIDFile=/usr/local/mysql/data/mysql.pid

# Disable service start and stop timeout logic of systemd for mysqld service.
TimeoutSec=0

# Execute pre and post scripts as root
PermissionsStartOnly=true

# Needed to create system tables
# ExecStartPre=/usr/bin/mysqld_pre_systemd

# Start main service
ExecStart=/usr/local/mysql/bin/mysqld --daemonize --pid-file=/usr/local/mysql/data/mysql.pid $MYSQLD_OPTS

# Use this to switch malloc implementation
#EnvironmentFile=-/etc/sysconfig/mysql

# Sets open_files_limit
LimitNOFILE = 5000
Restart=on-failure
RestartPreventExitStatus=1
PrivateTmp=false
EOF
#############################################################################
}

function start_mysql_setup(){
#############################################################################
systemctl daemon-reload

systemctl enable mysqld
systemctl start mysqld
systemctl status mysqld
ss -tnl |grep 3306

echo -e "\e[0;32mNote: MySQL用户密码查看\e[0m"
grep "password" /usr/local/mysql/log/mysqld.log
echo -e "\e[0;32mNote: ##备注：\e[0m"
echo -e "\e[0;32mNote: ##初次登陆需要修改密码\e[0m"
echo -e "\e[0;32mNote: ##ALTER USER USER() IDENTIFIED BY 'OE37HVJ8Ry30';\e[0m"
#############################################################################
}

install_base
create_user_optimization
download_install_mysql
create_conf_initmysql
start_mysql_setup

