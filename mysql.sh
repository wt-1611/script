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
INSTALL_LOG=/var/log/install.log

useradd mysql &>/dev/null

flag=false


## 名称: err 、info 、warning
## 用途：全局Log信息打印函数
## 参数: $@
log::err() {
  printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[31mERROR: $@ \033[0m\n"
}
log::warning() {
  printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[33mWARNING: $@ \033[0m\n"
}
log:info-1(){
  printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[32mINFO: $@ \033[0m\n"
}
log::info(){
    i=0
    local shu=1
    while [ $shu -gt 0 ];do
            local shu=$(ps axo pid | grep -w $background|wc -l)
            if [ $i -eq 0  ];then
                    printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[32mINFO: %s \033[0m" "$*"
                    local num=$(echo "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[32mINFO: $* \033[0m" | wc -L)
            fi

            printf "."
            sleep 0.2

            i=$(($i+1))
            if [ $i -gt 10  ];then
                printf "\r%$((11+$num))s" " "
                i=0
                printf "\r"
            fi
    done
    echo 
}

#实用的处理函数
function Deal(){
        echo "[$(date '+%F_%T') $1]" >>$INSTALL_LOG
        $1 &>>$INSTALL_LOG &
        background=$!
}
#结束函数
function End(){
        wait $background
        if [ $? -ne 0 ];then 
            log::err "$*"
            exit 2
        fi
}



function check(){
    log:info-1 "MySQL Environment Check"
    #操作系统版本检查
    if [ -f /etc/redhat-release ];then
        OS=rhel
        VERSION=$(awk -F '.' '{print $1}' /etc/redhat-release  |  awk '{print $NF}')
        if [ $VERSION -ne 7 -a $VERSION -ne 8 -a $VERSION -ne 6  ];then
            log::err "不支持的操作系统版本"
            exit 2
        fi
    elif [ -f /etc/openEuler-release ];then
        OS=euler
        VERSION=$(awk -F '.' '{print $1}' /etc/openEuler-release  | awk '{print $NF}')
        Deal "yum install tar net-tools -y"
        log::info "install net-tools"
        End "安装失败"
        
    else
        log:err "不支持的操作系统"
        exit 2
        
    fi

    #mysql安装包检查
    if [ ! -f $DIR/$TAR ];then
        log::warning "离线安装包不存在，请勿使用离线安装"
        log::warning "The offline installation package does not exist. Do not install it offline"
        flag=true #禁用离线安装
    fi

    #mysql环境检查
    ps aux | grep mysql[d] &>/dev/null
    if [ $? -eq 0  ];then
        log::err "mysqld 已经存在"
        log::err "mysql already exists"
        exit 2
    else
        if [ -d $DATA -o -d $BASE ];then
            log::err "$DATA or $BASE directory already exists"
            log::err "$DATA or $BASE 目录已经存在。请删除"
            exit 2
        fi
    fi
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
        log:info-1 "create mysql database user"
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
        
        mysql -uroot  < $SQL_FILE --connect-expired-password
        if [ $? -eq 0 ];then
             rm -fr $SQL_FILE 
        else
            info::err "Description Failed to create a mysql user"
            exit 2
        fi
    fi

}

function offline(){
    log:info-1 "Environmental preparation"
    if $flag;then
        log::err "未发现离线安装包"
        exit 2
    fi

    Deal "tar xvf $TAR -C /opt/"
    log::info "unzip mysql software"
    End "解压失败"
    if [ $background -ne 0 ];then
        log:info-1 "Create a mysql directory"
        ln -s /opt/$SOFT $BASE
        cd $BASE
        mkdir -p $LOG /var/run/mysqld
        chown -R mysql. $BASE /opt/$SOFT $LOG /var/run/mysqld
        ln -s $BASE/bin/mysql /usr/local/bin
        ln -s $BASE/bin/mysqld /usr/local/bin
    fi
    log:info-1 "mysql configuration"
    conf
    sed -i '/\[mysqld\]/abasedir='''$BASE'''' /etc/my.cnf

    
    Deal "mysqld --initialize --user=mysql --datadir=$DATA --basedir=$BASE"
    log::info "initialization mysql data"
    End "初始化失败"
   
    log:info-1 "Create a mysql startup file"
    cd $BASE
    \cp -f  support-files/mysql.server /etc/init.d/mysqld
    chkconfig  --add mysqld &>>$INSTALL_LOG
    

    if [ $VERSION -eq 6 ];then     
    #server mysqld start &>>$INSTALL_LOG
        Deal  "service mysqld start"
    else
        Deal "systemctl start mysqld"
    fi
    log::info "starting mysqld"
    End "启动失败"
   
   
    Deal "yum install libncurses* -y"
    log::info "install tools"
    End "安装失败"
}


function online(){
    log:info-1 "Do not validate ssl"
    grep "sslverify=false" /etc/yum.conf || echo "sslverify=false" >>/etc/yum.conf
    rpm -qa |grep mysql.*-release.* &>/dev/null
    if [ $? -ne 0 ];then
        local status=$(curl -s -o /dev/null -s -w %{http_code} -m 5  --connect-timeout 10   http://repo.mysql.com/yum/)
        if [ $status -ne 200 ];then
            log:info-1 "http://repo.mysql.com/yum/不可达，请检查网络！！"
            exit 2
        fi
        if [ $VERSION -eq 6 ];then
            log::err "6版本不支持离线安装！"
            exit 2
        elif [ $VERSION -eq 22 -o $VERSION -eq 8 ];then
            Deal "rpm -ivh https://repo.mysql.com//mysql80-community-release-el8-4.noarch.rpm"
            log::info "install mysql yum repo"
            End “安装失败”

        elif [ $VERSION -eq 7 ];then
            yum remove -y mariadb-libs &>>$INSTALL_LOG
            Deal "rpm -ivh https://repo.mysql.com//mysql80-community-release-el7-7.noarch.rpm"   
            log::info "install mysql yum repo"
            End "安装失败"
        fi
    else
        log::err "mysql already exists!"
        exit 2
    fi

    #log:info-1 "yum install mysql $1"
    
    if [ "$1" = "5.7"   ];then
        if [ $VERSION -eq 22 -o $VERSION -eq 8 ];then
            log:info-1 "${OS}-${VERSION}不支持mysql5.7在线安装。"
            exit 2
        else
            sed -ir '/mysql57-community/,/^$/s/enabled=0/enabled=1/' /etc/yum.repos.d/mysql-community.repo
            sed -ir '/mysql80-community/,/^$/s/enabled=1/enabled=0/' /etc/yum.repos.d/mysql-community.repo
            Deal "yum install   mysql-community-server-5.7.23 -y"
            log::info "install mysql 5.7.23"
            End "安装失败"
                   
        fi
    elif [ "$1" = "8.0" ];then
        Deal "yum install mysql-community-server-8.0.27 -y"
        log::info "install mysql 8.0.27"
        End "安装失败"

    else
        log::err "an unsupported version "
        exit 2
    fi

    log:info-1 "mysql configuration"
    conf
    log:info-1 "Create a mysql directory"
    mkdir -p $LOG
    chown -R mysql.  $LOG
    title "starting"
    systemctl enable mysqld
    Deal "systemctl restart mysqld"
    log::info "starting mysqld"
    End "启动失败"
    
    
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

function environment(){
    

    log:info-1 "mysql user $USER"
    log:info-1 "mysql data dir $DATA"
    log:info-1 "mysql config /etc/my.cnf"
    log:info-1 "mysql log file  $LOGFILE"
    log:info-1 "mysql password file $PASS"
    log:info-1 "mysql management mode [systemctl start|stop mysqld]"


}

case $1 in 

    offline)
        
        check
        offline
        user
        environment
    ;;

    online)
        shift 
        check
        online $1
        user
        environment
    ;;

    *)
        menu

    ;;

esac
