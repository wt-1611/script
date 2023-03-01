#!/bin/bash
DATA=/var/lib/mysql
TAR=mysql-5.7.22-linux-glibc2.12-x86_64.tar.gz
SOFT=mysql-5.7.22-linux-glibc2.12-x86_64
DIR=$(pwd)
LOG=/var/log/
LOGFILE=$LOG/mysqld.log
BASE=/opt/mysql
PASS=/root/.pass
USER="root pinpoint sqladm sqlapp"
SQL_FILE=/root/sql.txt
REPO_NAME=/etc/yum.repos.d/mysql.repo

useradd mysql &>/dev/null

flag=false

function ok_p(){
    echo -e "\033[1;42;37m ok \033[0m"
}

function error_p(){
    echo -e "\033[1;41;37m error \033[0m"
    exit 2
}


function title(){
    #echo -en "\033[1;33m================== $1 ======================\033[0m\n"
    for i in {1..100};do printf "\033[1;31m%s\033[0m" "=";done;printf "\n"
    printf "\033[1;33m %-20s \033[0m \n" "$1"
    for i in {1..100};do printf "\033[1;31m%s\033[0m" "=";done;printf "\n"
}


function prompt(){
    echo -en "\033[1;35m$1\033[0m\n"
}

function foo(){
    echo -en "\033[1;36m$1\033[0m\n"    
    $1 2>&1 >> /var/log/mysql_install.log
}

function check(){
    title "MySQL Environment Check"
    #操作系统版本检查
    if [ -f /etc/redhat-release ];then
        OS=rhel
        VERSION=$(awk -F '.' '{print $1}' /etc/redhat-release  |  awk '{print $NF}')
        if [ $VERSION -ne 7 -a $VERSION -ne 8 ];then
            prompt "不支持的操作系统版本"
            exit 2
        fi
    elif [ -f /etc/openEuler-release ];then
        OS=euler
        VERSION=$(awk -F '.' '{print $1}' /etc/openEuler-release  | awk '{print $NF}')
        foo "yum install tar net-tools -y"
        
    else
        prompt "不支持的操作系统"
        exit 2
        
    fi

    #mysql安装包检查
    if [ ! -f $DIR/$TAR ];then
        prompt "离线安装包不存在，请勿使用离线安装"
        prompt "The offline installation package does not exist. Do not install it offline"
        flag=true #禁用离线安装
    fi

    #mysql环境检查
    ps aux | grep mysql[d] &>/dev/null
    if [ $? -eq 0  ];then
        prompt "mysqld 已经存在"
        prompt "mysql already exists"
        exit 2
    else
        if [ -d $DATA -o -d $BASE ];then
            prompt "$DATA or $BASE directory already exists"
            prompt "$DATA or $BASE 目录已经存在。请删除"
            exit 2
        fi
    fi
    ok_p
}

function conf(){
    \cp  -f /etc/my.cnf{,.bak} &>/dev/null
cat >/etc/my.cnf<<eof
[client] 
socket=$DATA/mysql.sock
 
[mysql]  
port=3306
no-auto-rehash  
default-character-set=utf8 
 
[mysqld]
pid-file=/var/run/mysqld/mysqld.pid
character-set-server=utf8
#####dir#####  
datadir=$DATA
socket=$DATA/mysql.sock
log-error=$LOGFILE
#慢查询
slow_query_log_file=$DATA/slow.log 
log_timestamps=SYSTEM

######replication#####  
gtid-mode = on 
log-slave-updates=ON 
enforce-gtid-consistency=ON 
master-info-file=$DATA/master.info  
relay-log = $DATA/mysqld-relay-bin  
relay_log_info_file=$DATA/relay-log.info  
relay-log-index=$DATA/mysqld-relay-bin.index  
skip-slave-start 

#####binlog#####  
log-bin=$DATA/mysql-bin  
server_id=1
binlog_cache_size=32K  
binlog_format=ROW  
sync_binlog=0  
expire_logs_days=7 

#####not innodb options #####  
back_log=200  
max_connections=1000  
max_allowed_packet=24M  
max_heap_table_size=64M  
sort_buffer_size=2M  
join_buffer_size=4M  
thread_cache_size=400  
tmp_table_size=64M  


#####server#####  
default-storage-engine=INNODB  
lower_case_table_names=1  
long_query_time=1 
slow_query_log=1  
port=3306  
# skip-name-resolve  
skip-ssl  
max_connect_errors=65535  
max_user_connections=950 
 
#####innodb#####  
innodb_buffer_pool_size = 2G
innodb_file_per_table = 1  
innodb_flush_log_at_trx_commit = 0
innodb_lock_wait_timeout = 100  
innodb_log_buffer_size= 100M  
innodb_log_file_size = 30M  
innodb_log_files_in_group = 4  
innodb_thread_concurrency = 16  
innodb_max_dirty_pages_pct = 50  
#transaction-isolation = READ-COMMITTED  
innodb_buffer_pool_instances=4 
#innodb_force_recovery = 1
eof

}


function user(){
    if [ ! -f  $PASS ];then
        export MYSQL_PWD=$(grep password $LOG/mysqld.log | awk '{print $NF}'|head -n1)
        #echo "set global validate_password_policy = 0;"
        for i in $USER;do
            pa=$(openssl rand -hex 8)
            echo "$i,AD!${pa}W@#" >> $PASS
            if [ "$i" = "root" ];then
                echo "alter user root@'localhost' identified by \"$(grep  ^$i $PASS | awk -F"," '{print $2}')\";" > $SQL_FILE
                #echo "set global validate_password_policy = 0;" >> $SQL_FILE
            elif [ "$i" = "sqlapp" ];then
                echo "create user $i@'localhost' identified by \"$(grep ^$i $PASS | awk -F"," '{print $2}')\";" >> $SQL_FILE
                echo "grant update,delete,alter on *.* to $i@'localhost';" >> $SQL_FILE
            elif [ "$i" = "sqladm" ];then
                echo "create user $i@'localhost' identified by \"$(grep ^$i $PASS | awk -F"," '{print $2}')\";" >> $SQL_FILE
                echo "grant insert,update,delete,alter on *.* to $i@'localhost';" >> $SQL_FILE                
            else
                echo "create user $i@'localhost' identified by \"$(grep ^$i $PASS | awk -F"," '{print $2}')\";" >> $SQL_FILE
                echo "grant all on *.* to $i@'localhost';" >> $SQL_FILE
            fi
        done
        chmod 000 $PASS
        #[ $? -eq 0  ] || error_p
        mysql -uroot  < $SQL_FILE --connect-expired-password
        [ $? -eq 0 ] && rm -fr $SQL_FILE|| error_p
    fi

}

function offline(){
    title "Environmental preparation"
    if $flag;then
        prompt "未发现离线安装包"
        exit 2
    fi

    foo "tar xf $TAR -C /opt/"
    if [ $? -eq 0 ];then
        ln -s /opt/$SOFT $BASE
        cd $BASE
        mkdir -p $LOG /var/run/mysqld
        chown -R mysql. $BASE /opt/$SOFT $LOG /var/run/mysqld
        ln -s $BASE/bin/mysql /usr/local/bin
        ln -s $BASE/bin/mysqld /usr/local/bin
        ok_p
    else 
        error_p
    fi
    title "mysql configuration"
    conf
    sed -i '/\[mysqld\]/abasedir='''$BASE'''' /etc/my.cnf
    ok_p
    title "initialization"
    foo "mysqld --initialize --user=mysql --datadir=$DATA --basedir=$BASE"
    if [ $? -eq 0 ];then
        \cp -f  support-files/mysql.server /etc/init.d/mysqld
        ok_p
    else
        error_p
    fi
    title "starting"
    chkconfig  --add mysqld
    systemctl enable mysqld 
    foo "systemctl start mysqld"
    [ $? -eq 0 ] && ok_p || error_p
    title "create mysql user"
    foo "yum install libncurses* -y"
    user
    ok_p
}


function online(){
    title "yum repo install"
    grep "sslverify=false" /etc/yum.conf || echo "sslverify=false" >>/etc/yum.conf
    rpm -qa |grep mysql.*-release.* &>/dev/null
    if [ $? -ne 0 ];then
        local status=$(curl -s -o /dev/null -s -w %{http_code} -m 5  --connect-timeout 10   http://repo.mysql.com/yum/)
        if [ $status -ne 200 ];then
            prompt "http://repo.mysql.com/yum/不可达，请检查网络！！"
        fi
        
        
        if [ $VERSION -eq 22 -o $VERSION -eq 8 ];then
            foo "rpm -ivh https://repo.mysql.com//mysql80-community-release-el8-4.noarch.rpm"
            [ $? -eq 0 ] || error_p && ok_p

        elif [ $VERSION -eq 7 ];then
            foo "yum remove -y mariadb-libs"
            foo "rpm -ivh https://repo.mysql.com//mysql80-community-release-el7-7.noarch.rpm"
            [ $? -eq 0 ] || error_p && ok_p    
        fi
    else
        prompt "skip "
    fi

    title "yum install mysql $1"
    
    if [ "$1" = "5.7"   ];then
        if [ $VERSION -eq 22 -o $VERSION -eq 8 ];then
            prompt "${OS}-${VERSION}不支持mysql5.7在线安装。"
            exit 2
        else
            sed -ir '/mysql57-community/,/^$/s/enabled=0/enabled=1/' /etc/yum.repos.d/mysql-community.repo
            sed -ir '/mysql80-community/,/^$/s/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo
            foo "yum install   mysql-community-server-5.7.23 -y"
                    [ $? -eq 0 ] || error_p && ok_p
        fi
    elif [ "$1" = "8.0" ];then
       foo "yum install mysql-community-server-8.0.27 -y"
            [ $? -eq 0 ] || error_p && ok_p

    else
        prompt "An unsupported version "
        exit 2
    fi

    title "mysql configuration"
    conf
    ok_p
    mkdir -p $LOG
    chown -R mysql.  $LOG
    title "starting"
    systemctl enable mysqld
    foo "systemctl restart mysqld"
    [ $? -eq 0 ] || error_p && ok_p
    title "create mysql user"
    user
    ok_p
}

function menu(){
    cat <<EOF
        bash mysql.sh 
                offline 
                    Offline installation (default version 5.7.22)
                    离线安装（默认版本5.7.22）
                online  [5.7|8.0]
                    Online installation 
EOF
}

environment(){
    title "Environment"
        cat <<eof
    mysql user :          $USER
    mysql data :          $DATA
    mysql conf :          /etc/my.cnf
    mysql log  :          $LOGFILE
    mysql repo :          $REPO_NAME
    mysql password file : $PASS
    mysql status:         systemctl start|stop mysqld

eof

}

case $1 in 

    offline)
        
        check
        offline
        environment
    ;;

    online)
        shift 
        check
        online $1
        environment
    ;;

    *)
        menu

    ;;

esac

