#!/usr/bin/env bash
# It's Used to be install redis.
# Created on 2020/06/01 11:18.
# Version: 1.0  

REDIS_VERSION=redis-5.0.8
INSTALL_DIR=/usr/local/redis
WORK_DIR=/usr/local/src
NEW_USER=redis

function env_optimal () {
#############################################################################
cat >> /etc/rc.d/rc.local << EOF
echo 511 > /proc/sys/net/core/somaxconn
echo never > /sys/kernel/mm/transparent_hugepage/enabled
EOF

chmod +x /etc/rc.d/rc.local

echo 511 > /proc/sys/net/core/somaxconn
echo never > /sys/kernel/mm/transparent_hugepage/enabled

echo 'vm.overcommit_memory = 1' >> /etc/sysctl.d/redis.conf
sysctl -p
echo -e "\e[0;32menv optimal completed..\e[0m"

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

sleep 2

function create_user(){
#############################################################################
id ${NEW_USER} >/dev/null 2>&1
if [ $? -eq 0 ]; then
  grep ${NEW_USER} /etc/passwd
  echo -e "\e[0;32mNote: ${NEW_USER} user already exists.\e[0m"
else
  useradd -M -s /bin/nologiin ${NEW_USER}
  echo -e "\e[0;32mNote: ${NEW_USER} user crate finished.\e[0m"
fi
#############################################################################
}

function install_redis () {
#############################################################################
echo -e "\e[0;32mNote:yum install some sofeware ...\e[0m"
cd ${WORK_DIR}
yum -y install wget gcc
if [ ! -f "${WORK_DIR}/${REDIS_VERSION}.tar.gz" ]; then
    wget http://download.redis.io/releases/${REDIS_VERSION}.tar.gz -P ${WORK_DIR}/
else
    ls ${WORK_DIR}/${REDIS_VERSION}.tar.gz
	echo ${REDIS_VERSION}.tar.gz file exist.
fi
if [ -d $REDIS_VERSION ]; then
    rm -fr ${REDIS_VERSION}
fi
tar -zxvf ${REDIS_VERSION}.tar.gz

cd ${REDIS_VERSION}
make PREFIX=${INSTALL_DIR} install
mkdir -p ${INSTALL_DIR}/{etc,var}
ln -s ${INSTALL_DIR}/bin/* /usr/local/bin/

echo "modify config file..."
cp {redis.conf,sentinel.conf}  ${INSTALL_DIR}/etc/
cp ${INSTALL_DIR}/etc/redis.conf ${INSTALL_DIR}/etc/redis.conf.bak

cat > ${INSTALL_DIR}/etc/redis.conf  << \EOF
bind 0.0.0.0
protected-mode yes
port 6379
tcp-backlog 511
timeout 300
tcp-keepalive 300
daemonize yes
supervised no
pidfile /usr/local/redis/var/redis_6379.pid
loglevel notice
logfile /usr/local/redis/var/redis_6379.log
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump-6379.rdb
dir /usr/local/redis/var
slave-serve-stale-data yes
slave-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
slave-priority 100
requirepass OE37HVJ8Ry30
maxmemory 1GB
maxmemory-policy allkeys-lru
appendonly no
appendfsync everysec
no-appendfsync-on-rewrite yes
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 256mb
aof-load-truncated yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
# slaveof 192.168.11.11 6379
EOF

echo -e "\e[0;32mNote:install start(systemd) script...\e[0m"

cat > /usr/lib/systemd/system/redis.service << \EOF
[Unit]
Description=Redis persistent key-value database
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf --supervised systemd
ExecStop=/usr/local/redis/bin/redis-shutdown
Type=notify
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/lib/systemd/system/redis-sentinel.service <<EOF
[Unit]
Description=Redis Sentinel
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/local/redis/bin/redis-sentinel /usr/local/redis/etc/redis-sentinel.conf --supervised systemd
ExecStop=/usr/local/redis/bin/redis-shutdown redis-sentinel
Type=notify
User=redis
Group=redis
RuntimeDirectory=redis
RuntimeDirectoryMode=0755

[Install]
WantedBy=multi-user.target
EOF

cat > ${INSTALL_DIR}/bin/redis-shutdown << \EOF
#!/bin/bash
#
# Wrapper to close properly redis and sentinel
test x"$REDIS_DEBUG" != x && set -x

REDIS_CLI=/usr/local/redis/bin/redis-cli

# Retrieve service name
SERVICE_NAME="$1"
if [ -z "$SERVICE_NAME" ]; then
   SERVICE_NAME=redis
fi

# Get the proper config file based on service name
CONFIG_FILE="/usr/local/redis/etc/$SERVICE_NAME.conf"

# Use awk to retrieve host, port from config file
HOST=`awk '/^[[:blank:]]*bind/ { print $2 }' $CONFIG_FILE | tail -n1`
PORT=`awk '/^[[:blank:]]*port/ { print $2 }' $CONFIG_FILE | tail -n1`
PASS=`awk '/^[[:blank:]]*requirepass/ { print $2 }' $CONFIG_FILE | tail -n1`
SOCK=`awk '/^[[:blank:]]*unixsocket\s/ { print $2 }' $CONFIG_FILE | tail -n1`

# Just in case, use default host, port
HOST=${HOST:-127.0.0.1}
if [ "$SERVICE_NAME" = redis ]; then
    PORT=${PORT:-6379}
else
    PORT=${PORT:-26739}
fi

# Setup additional parameters
# e.g password-protected redis instances
[ -z "$PASS"  ] || ADDITIONAL_PARAMS="-a $PASS"

# shutdown the service properly
if [ -e "$SOCK" ] ; then
	$REDIS_CLI -s $SOCK $ADDITIONAL_PARAMS shutdown
else
	$REDIS_CLI -h $HOST -p $PORT $ADDITIONAL_PARAMS shutdown
fi
EOF

chmod +x ${INSTALL_DIR}/bin/redis-shutdown
chown -R redis.redis ${INSTALL_DIR}/var
systemctl enable redis.service
systemctl start redis.service
systemctl status redis.srevice
#############################################################################
}


env_optimal
create_user
install_redis

echo -e "\e[32mNote:Redis Server install completed \e[0m"
echo -e "\e[32mNote:command：systemctl start redis.service is startup. \e[0m"


