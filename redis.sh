#!/bin/bash
SOURCE=/root/redis-6.2.7
SOFTWARE=/opt/redis6
PORT=6379
DATA_BASE=/data/redis6
DATA=$DATA_BASE/$PORT
CONF=$SOFTWARE/redis${PORT}.conf
CURRENT=`pwd`

REDIS_USER_PASS=$(openssl rand -hex 16)


ok_p(){
    echo -e "\033[1;42;37m ok \033[0m"
}

error_p(){
    echo -e "\033[1;41;37m error \033[0m"
    exit 3
}

title(){
    #echo -en "\033[1;33m================== $1 ======================\033[0m\n"
    for i in {1..100};do printf "\033[1;31m%s\033[0m" "=";done;printf "\n"
    printf "\033[1;33m %-20s \033[0m \n" "$1"
    for i in {1..100};do printf "\033[1;31m%s\033[0m" "=";done;printf "\n"
}


foo(){
    echo -en "\033[1;34m $1 \033[0m\n"
}

repo(){
    
    [ ! -f /etc/yum.repos.d/redis.repo  ] && \
    title "Creating a Local Source"
cat >/etc/yum.repos.d/redis.repo<<eof
[redis]
name=hc
baseurl=file://$CURRENT/hc/rpm
enable=1
gpgcheck=0
eof
ok_p
}

redis_create(){
    title "Create the redis environment"
    if [ ! -d $SOFTWARE/bin ] ;then
        ping -c1 www.baidu.com &>/dev/null
        if [ $? -eq 0 ];then
            repo
            yum install  make systemd-devel gcc -y
        else
            mkdir /etc/yum.repos.d/bak -p
            mv /etc/yum.repos.d/*.repo  /etc/yum.repos.d/bak
            repo
        fi
        yum install  make systemd-devel gcc -y
        cd $SOURCE
        make PREFIX=$SOFTWARE install && ok_p || error_p
    fi
    title  "Create a redis user"
    useradd redis &>/dev/null
    echo "$REDIS_USER_PASS" | passwd --stdin redis &>/dev/null
    mkdir $DATA -p
    chown  -R redis. $DATA $SOFTWARE && ok_p || error_p

}


kernel(){
    title "redis kernel parameter"
if [ ! -f /etc/sysctl.d/redis.conf ];then
cat >> /etc/sysctl.d/redis.conf <<eof
vm.overcommit_memory=1
net.core.somaxconn=1024
eof
fi
sysctl -p && ok_p || error_p
}

conf(){
    title "redis of configurage"
cat > $CONF <<eof
bind 0.0.0.0
protected-mode yes 
port $PORT
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile $DATA/redis_$PORT.pid
loglevel notice
logfile $DATA/redis_$PORT.log
syslog-enabled no
#databases 16
#是否显示logo
always-show-logo yes

###########################################
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump_$PORT.rdb
rdb-del-sync-files no
dir $DATA

requirepass $(openssl rand -hex 17)
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-diskless-load disabled
repl-disable-tcp-nodelay no
replica-priority 100
acllog-max-len 128
lazyfree-lazy-eviction no
lazyfree-lazy-expire no
lazyfree-lazy-server-del no
replica-lazy-flush no
lazyfree-lazy-user-del no
oom-score-adj no
oom-score-adj-values 0 200 800
appendonly no
appendfilename "${PORT}_appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes
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
stream-node-max-bytes 4096
stream-node-max-entries 100
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes
jemalloc-bg-thread yes
rename-command KEYS     "HCKEYS"
rename-command FLUSHDB  "HCFLUSHDB"
rename-command CONFIG   ""
rename-command FLUSHALL  "HCFLUSHALL"
eof
[ $? -eq 0 ] && ok_p || error_p
}

redis_start(){
    title "redis startup file && Starting redis"
cat > /usr/lib/systemd/system/redis_${PORT}.service <<eof
[Unit]
Description=Redis persistent key-value database
After=network.target
After=network-online.target


[Service]
Type=simple
PIDFile=$DATA/redis_$PORT.pid
ExecStart=$SOFTWARE/bin/redis-server $CONF 
ExecStop=$(which kill) -15 \$MAINPID
User=redis
Group=redis


[Install]
WantedBy=multi-user.target
eof

systemctl daemon-reload 
systemctl enable --now  redis_${PORT} && ok_p || error_p
}


menu(){
    cat <<eof
install <single | more | cluster>  port[s]
    single  Single instance deployment
            Only the first port you pass in will be used.
    more    Multi-instance deployment
            You need to pass in multiple ports, separated by Spaces.
    cluster Cluster Deployment
            You need an even number of ports, at least six.
eof
exit 2
}


redis(){
    repo 
    redis_create
    kernel
    conf
    redis_start
}

modify(){
    title "Configuration File Modification"
    sed -i "s/^port.*/port $PORT/" $CONF
    sed -i "s/^appendonly.*/appendonly yes/" $CONF
    sed -i "s/^requirepass.*/requirepass $1/" $CONF
    cat >> $CONF <<EOF
cluster-enabled yes
cluster-config-file $SOFTWARE/cluster.d/node_$PORT.conf
cluster-node-timeout 5000
EOF
[ $? -eq 0 ] && ok_p || error_p
}


redis_cluster(){
    repo
    redis_create
    kernel
    conf
    modify $1
    redis_start
}


is_port(){
    ss -tln  | awk '{print $4}' | awk -F':' '{print $NF}' | sed 1d|sort |uniq |grep -w $1 &>/dev/null
    if [ $? -eq 0 ];then 
     echo 'port '''$1''' already exists' 
     exit 1
    fi

}

case $1 in 
    single)
        shift
            num=$@

            if [ "$num" = "" ];then
                    menu
            fi
            p=$(echo "$@"  |awk '{print $1}')
            
            [[ $p =~ ^[1-9][0-9]+$ ]] || menu

            is_port $p
            
            PORT=$p

            redis

    ;;

    more)
        shift
            num=$@

            if [ "$num" = "" ];then
                    menu
            fi

            for i in  "$@";do
                
                if  [[ $i =~ ^[1-9][0-9]+$ ]];then
                    is_port $i
        
                else
                    menu
                fi
            done

            for s in "$@";do
                PORT=$s
 
                DATA=$DATA_BASE/$PORT
                CONF=$SOFTWARE/redis${PORT}.conf
                redis
            done
    ;;

    cluster)
         pass=`openssl rand -hex 16`
         shift
            num=$@
            #echo $num
            if [ "$num" = "" ];then
                    menu
            fi

            for i in  "$@";do
                
                if  [[ $i =~ ^[1-9][0-9]+$ ]];then
                    is_port $i
                    p_n=$(echo $num | wc -w)
                    if [ $p_n -lt 6 ];then
                        echo "Please enter at least six ports！！！"
                        exit 2
                    fi
                    if [ $(($p_n%2)) != 0 ];then
                        echo "The default is one master and one slave. Please enter an even number of ports"
                        exit 2
                    fi
                else
                    menu
                fi
            done
            mkdir -p $SOFTWARE/cluster.d
            chown -R redis. $SOFTWARE
            for s in "$@";do
                PORT=$s

                DATA=$DATA_BASE/$PORT
                CONF=$SOFTWARE/redis${PORT}.conf
                redis_cluster $pass
            done

            title "Create a redis cluster"
            echo yes|$SOFTWARE/bin/redis-cli --cluster create  $(echo $num | sed -r 's/([0-9]+)/127.0.0.1:\1/g') --cluster-replicas 1  -a $pass && \
            ok_p || error_p

    ;;

    *)
    menu
    ;;

esac



title "Environment"
foo "port    :   $num"
foo "software:   $SOFTWARE"
foo "conf    :   $SOFTWARE"
foo "data    :   $DATA_BASE"
foo "service :   systemctl [start|stop] redis_<port>"

