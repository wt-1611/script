DATA=/var/lib/mysql
LOG=/var/log/mysql
PASS=/root/.pass
PASSWD_USER="mysql mysql_root mysql_pinpoint" 
LOCATION=`pwd`
INSTALL_LOG=/var/log/install.log

ok_p(){
    echo -e "\033[1;42;37m ok \033[0m"
}

error_p(){
    echo -e "\033[1;41;37m error \033[0m"
    exit 2
}

title(){
    #echo -en "\033[1;33m================== $1 ======================\033[0m\n"
    for i in {1..100};do printf "\033[1;31m%s\033[0m" "=";done;printf "\n"
    printf "\033[1;33m %-20s \033[0m \n" "$1"
    for i in {1..100};do printf "\033[1;31m%s\033[0m" "=";done;printf "\n"
}

foo(){
    echo -en "\033[1;37m$1\033[0m\n"
}


process(){
    process_id=$1
    spin='-\|/'
    i=0
    while [ `ps axo pid | grep $process_id |wc -l` -ne 0 ]
    do
            i=$(( (i+1) %4 ))
            printf "\r[${spin:$i:1}]"
            sleep .1
    done
    echo
}

install(){

    title "install mysql$1"
    if [ $os -eq 3 -a  $n -eq 8 ];then 
        nohup yum install mysql-server -y >>$INSTALL_LOG 2>&1 &
    else
        nohup yum install   mysql-community-server -y >>$INSTALL_LOG 2>&1 &
      
    fi 
    process $!
    wait $!
    [ $? -eq 0 ] && ok_p || error_p
}

repo_m(){
    title "create mysql repo"
    #2是离线，1是在线
    flag=$2
    version=$1
    os=$3
    #echo $flag
    if [ $flag -eq 1 ];then
        mkdir -p  /etc/yum.repos.d/bak ; mv /etc/yum.repos.d/*.repo  /etc/yum.repos.d/bak &>/dev/null

        n=$(echo $version | awk -F'.' '{print $1}')
        if [ $os -eq 3 -a  $n -eq 8 ];then 
            rpm -ivh mysql80-community-release-el8-4.noarch.rpm &>/dev/null
            cp openEuler.repo /etc/yum.repos.d/

        elif [ $os -eq 3 -a $n -eq 5 ];then
            rpm -ivh mysql80-community-release-el7-7.noarch.rpm &>/dev/null
            cp openEuler.repo /etc/yum.repos.d/
            sed -i '/MySQL 5.7 Community Server/{n;n;s/enabled=.*/enabled=1/;}' /etc/yum.repos.d/mysql-community.repo
            sed -i '/MySQL 8.0 Community Server/{n;n;s/enabled=.*/enabled=0/;}' /etc/yum.repos.d/mysql-community.repo

        elif [ $os -eq 0 -a $n -eq 5 ];then
            rpm -ivh mysql80-community-release-el7-7.noarch.rpm &>/dev/null
            sed -i '/MySQL 5.7 Community Server/{n;n;s/enabled=.*/enabled=1/;}' /etc/yum.repos.d/mysql-community.repo
            sed -i '/MySQL 8.0 Community Server/{n;n;s/enabled=.*/enabled=0/;}' /etc/yum.repos.d/mysql-community.repo
        fi


        yum clean all &>/dev/null
        #nohup $SHELL  <<eof &
#yum list --showduplicates  mysql-community-server | awk '{print $2}' | egrep '^'''$version'''' 
#eof
        #yum list --showduplicates  mysql-community-server | awk '{print $2}' | egrep '^'''$version''''
        yum list --showduplicates  mysql-community-server  | awk '{print $2}' | egrep '^'''$version'''' &>$INSTALL_LOG  &
        #yum list --showduplicates  mysql-community-server | awk '{print $2}' | egrep '^'''$version'''' &>$INSTALL_LOG &
        process $!
        wait $!
        [ $? -eq 0  ] && ok_p || error_p
        version1=-${version}*
        install $version1 $version 

    elif [ $flag -eq 2 ];then
        if [ -f mysql_hc_install.tar.gz ];then
            tar xvf mysql_hc_install.tar.gz &>>$INSTALL_LOG && ok_p || error_p
            mkdir -p  /etc/yum.repos.d/bak ; mv /etc/yum.repos.d/*.repo  /etc/yum.repos.d/bak 
            cat >/etc/yum.repos.d/mysql_hc.repo<<eof
[mysql57-community]
name=mysql57-community
enable=1
baseurl=file://$LOCATION/hc/rpm
gpgcheck=0
eof
            install -5.7* 5.7
        else
            echo "please downaload mysql_hc_install.tar.gz!!!"
        fi
    fi
}




m_env(){
    title "Create the mysql installation environment"
    if [ ! -f  $PASS ];then
        for i in $PASSWD_USER;do
        pass=`openssl rand -hex 10`
        echo "${pass}Q@,$i" >> $PASS
        done 
    fi
    chmod 000 $PASS
    #grep -i  '' sed -i '1 i\user,pass,<app of user>' $PASS

    echo "`grep -w mysql $PASS | awk -F"," '{print $1}'`" | passwd --stdin mysql && \
    rpm -qa | grep 'mysql-community-server' && ok_p || error_p
    mkdir -p $LOG $DATA
    chown -R mysql. $LOG  $DATA
}


m_config(){
    title "configuration of mysql"

\cp  -f /etc/my.cnf{,.bak}
cat >/etc/my.cnf<<eof
[client] 
socket=$DATA/mysql.sock
 
[mysql]  
port=3306
no-auto-rehash  
default-character-set=utf8 
 
[mysqld]  
character-set-server=utf8
#####dir#####  
datadir = $DATA
socket=$DATA/mysql.sock
log-error = $LOG/mysqld.log
#慢查询
slow_query_log_file= $LOG/slow.log 
log_timestamps=SYSTEM

######replication#####  
gtid-mode = on 
log-slave-updates=ON 
enforce-gtid-consistency=ON 
master-info-file =$DATA/master.info  
relay-log = $DATA/mysqld-relay-bin  
relay_log_info_file=$DATA/relay-log.info  
relay-log-index = $DATA/mysqld-relay-bin.index  
skip-slave-start 

#####binlog#####  
log-bin = $DATA/mysql-bin  
server_id=1
binlog_cache_size=32K  
binlog_format=ROW  
sync_binlog=0  
expire_logs_days=7 

#####not innodb options #####  
back_log = 200  
max_connections = 1000  
max_allowed_packet = 24M  
max_heap_table_size = 64M  
sort_buffer_size = 2M  
join_buffer_size = 4M  
thread_cache_size=400  
tmp_table_size = 64M  


#####server#####  
default-storage-engine=INNODB  
lower_case_table_names = 1  
long_query_time = 1 
slow_query_log=1  
port = 3306  
# skip-name-resolve  
skip-ssl  
max_connect_errors = 65535  
max_user_connections = 950 
 
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
[ $? -eq 0 ] && ok_p || error_p
}


mysql_start(){
    title "Initialize && Start mysql"
    systemctl enable --now mysqld &>/dev/null
    systemctl start mysqld
    status=`systemctl is-active  mysqld`
    if [ $status != "active" ];then
            sleep 2
    fi
    status=`systemctl is-active  mysqld`
    echo "mysql status: $status"
cat > /root/c.sql<< eof 
alter user root@"localhost" identified by "`grep -w mysql_root $PASS | awk -F"," '{print $1}'`";
create user pinpoint@'%' identified by "`grep -w mysql_pinpoint $PASS | awk -F"," '{print $1}'`";
grant all on *.* to pinpoint@'%';
eof
    export MYSQL_PWD=$(grep password $LOG/mysqld.log | awk '{print $NF}'|head -n1)
    mysql -uroot  < /root/c.sql --connect-expired-password &>> /var/log/install.log && ok_p || error_p
    rm -f /root/c.sql
}

print_m(){
    title "Environment"
    foo "1. config : /etc/my.cnf"
    foo "2. data   : $DATA"
    foo "3. pass   : $PASS"
    foo "4. log    : $LOG"
    foo "5. start|stop : systemctl <start|stop> mysqld"
}



m_main(){
    
    m_env && \
    m_config && \
    mysql_start && \
    echo && \
    print_m
}


menu(){
    cat <<eof
mysql.sh [online|offline] <mysql version>

    online  Online Installation
            option 5.7 or 8.0
    offline Offline Installation
            Only version 5.7 is supported
e,g
    mysql.sh online 8.0
eof
exit 2
}

is_version(){
    echo $1 | egrep '^5\.7|^8\.0' &>/dev/null
    [ $? -eq 0  ] || menu

    version=$(echo $1 | awk -F'.'  '{print $1"."$2}') 
    
    repo_m $version $2 $3

}

os=0
if [ -f /etc/openEuler-release ];then
    rpm -ivh ./net-tools-2.10-1.oe2203.x86_64.rpm
    os=3

fi




case $1 in
    online)
        shift 
        [ "`systemctl is-active mysqld`" == "active" ] && foo "mysql is running" && exit 87  
        is_version $1 1 $os
        m_main && exit 0
    ;;
    offline)
        shift
        [ "`systemctl is-active mysqld`" == "active" ] && foo "mysql is running" && exit 87  
        is_version 5.7 2
        m_main && exit 0

    ;;
    *)
       menu
    ;;
esac