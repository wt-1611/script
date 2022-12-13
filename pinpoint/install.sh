#!/bin/bash
##########################################################
#author  : alex                                          #
#date    : 2022-12-02                                    #
#message : auto install of pinpoint                      #
##########################################################

JDK_11_VERSION=jdk-11.0.16.1_linux-x64_bin.tar.gz
JAVA_11_HOME=/opt/jdk-11.0.16.1
PINPOINT_VERSION=2.4.2


HBASE_VERSION=hbase-1.4.6
JAVA_8_VERSION=jdk-8u181-linux-x64.tar.gz
HBASE_USER=hbase
HBASE_DATA=/data/hbase
HBASE_SOFTWARE=/opt/hbase
ZK_DATA=$HBASE_DATA/ZK
JAVA_HOME=/opt/jdk1.8.0_181

PINPOINT_USER=pinpoint

PASS=/root/.Ppass
CREATE_USER_PASS="$HBASE_USER $PINPOINT_USER"

SOFTWARE_BASE=`pwd`/pinpoint

MYSQL_PORT=3306

TTL=259200

INSTALL_LOG=/var/log/install.log

BASE=/opt/pinpoint
COLLECTOR=$BASE/collector
WEB=$BASE/web
BATCH=$BASE/batch



ok_p(){
    echo -e "\033[1;42;37m ok \033[0m"
}

error_p(){
    echo -e "\033[1;41;37m error \033[0m"
    exit 9
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
    spin='-\|/'
    i=0
    while [ `ps axo pid | grep $1 |wc -l` -ne 0 ]
    do
            i=$(( (i+1) %4 ))
            printf "\r[${spin:$i:1}]"
            sleep .1
    done
}



java_a(){
title "Preparing the java8 Environment"
if [ ! -d $JAVA_HOME ];then 
tar xf $SOFTWARE_BASE/$JAVA_8_VERSION -C  /opt && \
cat > /etc/profile.d/java.sh<<eof
export JAVA_HOME=$JAVA_HOME
export PATH=\$PATH:\$JAVA_HOME/bin
eof
source /etc/profile.d/java.sh
else
  foo "jdk8 already exists"
fi
[ $? -eq 0 ] && ok_p ||error_p
}


pass(){
    rm -f $PASS
    for i in $CREATE_USER_PASS;do
        pas=$(openssl rand -base64 16)
        echo "$i,${pas}1" >>$PASS
    done
    chmod 000 $PASS
}



hbase_env(){
  title "hbase Environment Configuration"
    useradd $HBASE_USER
    echo $(grep -w $HBASE_USER $PASS) | passwd --stdin $HBASE_USER
    mkdir -p $HBASE_DATA $ZK_DATA
    if [ ! -d /opt/$HBASE_VERSION ];then
         echo "tar xf $SOFTWARE_BASE/$HBASE_VERSION-bin.tar.gz -C /opt"
         tar xf $SOFTWARE_BASE/$HBASE_VERSION-bin.tar.gz -C /opt || error_p
    fi
    ln -s /opt/$HBASE_VERSION  $HBASE_SOFTWARE || error_p && \
    chown -R ${HBASE_USER}. $HBASE_DATA $ZK_DATA $HBASE_SOFTWARE/
    chmod 700 $HBASE_SOFTWARE/bin/start-hbase.sh $HBASE_SOFTWARE/bin/stop-hbase.sh && \
    ok_p
}


hbase_systemd(){
  title "Start file creation"
cat > /usr/lib/systemd/system/hbase.service<<eof
[Unit]
Description=hc
After=network.target

[Service]
Type=forking
User=hbase
Group=hbase
WorkingDirectory=$HBASE_SOFTWARE
Environment="JAVA_HOME=$JAVA_HOME"
ExecStart=$HBASE_SOFTWARE/bin/start-hbase.sh 
ExecStop=$HBASE_SOFTWARE/bin/stop-hbase.sh 
Restart=on-success
RestartSec=10
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
eof
[ $? -eq 0 ] && ok_p || error_p
}

hbase(){
    hbase_env && \
    hbase_systemd && \
    title "Configuring hbase"
    grep -w `hostname` /etc/hosts &>/dev/null
     if [ $? -ne 0 ];then  
        sed -i "/127.0.0.1/s/$/ `hostname`/" /etc/hosts 
     fi
    echo -ne "export JAVA_HOME=$JAVA_HOME\n" >> $HBASE_SOFTWARE/conf/hbase-env.sh
cat > $HBASE_SOFTWARE/conf/hbase-site.xml<<eof
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
    <name>hbase.rootdir</name>
    <value>file://$HBASE_DATA</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>$ZK_DATA</value>
  </property>
</configuration>
eof
[ $? -eq 0 ] && ok_p || error_p
}

hbase_start(){
    if  [ "`systemctl is-active hbase`" == "active" ];then 
      foo "hbase is running" 
    else
      hbase && \
      title "start hbase"
      systemctl daemon-reload && systemctl enable --now hbase.service && ok_p || error_p
      title "create pinpoint database" 
      #netstat  -tpln | awk -F '/' '{print $NF}' | grep mysqld &>/dev/null && \
      bash $SOFTWARE_BASE/script.sh $TTL $SOFTWARE_BASE/hbase-create.hbase  && \
      nohup $HBASE_SOFTWARE/bin/hbase shell $SOFTWARE_BASE/hbase-create.hbase &>>$INSTALL_LOG & 
      process $!
      echo
      wait $!
      [ $? -eq 0 ] && ok_p || error_p
    fi
}



java_b(){
    title "Preparing the java11 Environment"
    [  -d $JAVA_11_HOME ] && rm -fr $JAVA_11_HOME || tar xf $SOFTWARE_BASE/$JDK_11_VERSION -C /opt
    [ $? -eq 0 ] && ok_p || error_p
    
}

pinpoint_env(){
    title "pinpoint Environment Configuration"
    useradd $PINPOINT_USER

    mkdir -p  $COLLECTOR $WEB $BATCH
    \cp -f $SOFTWARE_BASE/pinpoint-collector-boot-2.4.2.jar $COLLECTOR
    \cp -f $SOFTWARE_BASE/pinpoint-web-boot-2.4.2.jar $WEB
    \cp -f $SOFTWARE_BASE/pinpoint-batch-2.4.2.jar  $BATCH
    #配置文件
    sed  -i 's/jdbc.username=.*/jdbc.username=pinpoint/' $SOFTWARE_BASE/jdbc-root.properties
    p=$(grep mysql_pinpoint /root/.pass |awk -F, '{print $1}')
    sed  -i "s/jdbc.password=.*/jdbc.password=$p/" $SOFTWARE_BASE/jdbc-root.properties
    \cp -f $SOFTWARE_BASE/batch-root.properties  $BATCH
    \cp -f $SOFTWARE_BASE/jdbc-root.properties $BATCH
    \cp -f $SOFTWARE_BASE/jdbc-root.properties $WEB
    \cp -f $SOFTWARE_BASE/{pinpoint-collector-grpc.properties,pinpoint-collector-root.properties,hbase.properties} $COLLECTOR
    \cp -f $SOFTWARE_BASE/{pinpoint-web-root.properties,hbase.properties} $WEB
    chown -R $PINPOINT_USER. $BASE  && ok_p || error_p 

    
}

pinpoint_systemd(){
  title "Create the pinpoint startup file"
cat > /usr/lib/systemd/system/pinpoint_collector.service<<eof
[Unit]
Description=hc
After=network.target hbase.service

[Service]
Type=simple
User=pinpoint
Group=pinpoint
WorkingDirectory=$COLLECTOR
Environment="JAVA_HOME=$JAVA_11_HOME"
ExecStart=$JAVA_11_HOME/bin/java  -jar -Dpinpoint.zookeeper.address=localhost  $COLLECTOR/pinpoint-collector-boot-2.4.2.jar \
  --spring.config.additional-location=$COLLECTOR/pinpoint-collector-grpc.properties,$COLLECTOR/pinpoint-collector-root.properties,$COLLECTOR/hbase.properties
ExecStop=/usr/bin/kill -15 \$MAINPID
RestartSec=10
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
eof

cat > /usr/lib/systemd/system/pinpoint_web.service<<eof
[Unit]
Description=hc
After=network.target hbase.service mysqld.service

[Service]
Type=simple
User=pinpoint
Group=pinpoint
WorkingDirectory=$WEB
Environment="JAVA_HOME=$JAVA_11_HOME"
ExecStart=$JAVA_11_HOME/bin/java  -jar -Dpinpoint.zookeeper.address=localhost  $WEB/pinpoint-web-boot-2.4.2.jar  --spring.config.additional-location=$WEB/jdbc-root.properties,$WEB/pinpoint-web-root.properties,$WEB/hbase.properties
ExecStop=/usr/bin/kill -15 \$MAINPID
RestartSec=10
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
eof

cat > /usr/lib/systemd/system/pinpoint_batch.service<<eof
[Unit]
Description=hc
After=network.target hbase.service mysqld.service

[Service]
Type=simple
User=pinpoint
Group=pinpoint
WorkingDirectory=$BATCH
Environment="JAVA_HOME=$JAVA_11_HOME"
ExecStart=$JAVA_11_HOME/bin/java  -jar -Dpinpoint.zookeeper.address=localhost $BATCH/pinpoint-batch-2.4.2.jar --spring.config.additional-location=$BATCH/jdbc-root.properties,$BATCH/batch-root.properties
ExecStop=/usr/bin/kill -15 \$MAINPID
RestartSec=10
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
eof
ok_p
}

pinpoint_mysql(){
  title "Creating the pinpoint alarm database"
  export MYSQL_PWD=`grep mysql_pinpoint  /root/.pass  | awk -F',' '{print $1}'`
  [ `mysql -upinpoint  -e 'select * from information_schema.SCHEMATA where SCHEMA_NAME = "pinpoint";'|wc -l` -eq 0 ] && \
  mysql -upinpoint < $SOFTWARE_BASE/schema.sql  --connect-expired-password  
  [ $? -eq 0 ] && ok_p || error_p
}



pinpoint_start(){
  
  if [ ! -d $BASE  ];then
    java_b && \
    pinpoint_mysql && \
    pinpoint_env && \
    pinpoint_systemd 
    if [ $? -eq 0 ];then
      title "Start pinpoint"
      systemctl daemon-reload && systemctl enable --now pinpoint_collector.service pinpoint_web.service pinpoint_batch.service && \
      ok_p || error_p
    else 
      error_p
    fi
  else
    foo "pinpoint is running"
  fi
} 

print(){
  title "environment"
  foo "jdk11      :$JAVA_11_HOME"
  foo "jdk8       :$JAVA_HOME"
  foo "pinpoint   :$BASE"
  foo "bhase data :$HBASE_DATA"
  foo "hbase conf :$HBASE_SOFTWARE"
  foo "pinpoint   :$BASE"
  foo "pass       :$PASS"
  foo "数据存活周期:${TTL}s"
  foo "start|stop :systemctl <start|stop> <hbase|pinpoint_web|pinpoint_batch|pinpoint_collector>"
}

#if [ `basename $SOFTWARE_BASE` != 'pinpoint'  ];then 
#   cd pinpoint || error_p 
#   SOFTWARE_BASE=$(pwd)
#   pwd
#fi

os=0
if [ -f /etc/openEuler-release ];then
    rpm -ivh ../tools/net-tools-2.10-1.oe2203.x86_64.rpm
    rpm -ivh ../tools/tar-1.34-1.oe2203.x86_64.rpm
    os=3

fi


[ -f pinpoint.tar.gz ] && tar xf pinpoint.tar.gz || error_p
cd ../mysql/
bash ../mysql/mysql_install.sh offline 
[ $? -eq 87 -o $? -eq 0 ] && \
cd ../pinpoint
java_a  && \
pass  && \
hbase_start && \
pinpoint_start   && print