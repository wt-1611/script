#!/bin/bash

WORK_DIR='/usr/local/rocketmq49'
DATA_DIR='/home/rocketmq/store'
LOG_DIR='/home/rocketmq/logs/rocketmqlogs'
JAVA_DIR='/usr/local/rocketmq49/jdk1.8/'

start_file_namesrv(){
cat > /usr/lib/systemd/system/rmq_namesrv_s.service <<eof
[Unit]
After=network.target

[Service]
Type=simple
User=rocketmq
Environment="JAVA_HOME=$WORK_DIR/jdk1.8"
WorkingDirectory=$WORK_DIR
ExecStart=$WORK_DIR/bin/mqnamesrv
ExecStop=$WORK_DIR/bin/mqshutdown namesrv

[Install]
WantedBy=multi-user.target
eof

}


start_file_broker(){
cat > /usr/lib/systemd/system/rmq_broker_s.service <<eof
[Unit]
After=network.target

[Service]
Type=simple
User=rocketmq
Environment="JAVA_HOME=$WORK_DIR/jdk1.8/"
WorkingDirectory=$WORK_DIR/
ExecStart=$WORK_DIR/bin/mqbroker -c $WORK_DIR/broker.conf
ExecStop=$WORK_DIR/bin/mqshutdown broker

[Install]
WantedBy=multi-user.target
eof
}


configM(){
cat > $WORK_DIR/broker.conf <<eof
flushDiskType=SYNC_FLUSH
namesrvAddr=127.0.0.1:9876
storePathRootDir=$DATA_DIR
eof
}

env_u(){
	useradd rocketmq &>/dev/null
	mkdir -p $DATA_DIR
	mkdir -p /home/rocketmq
	chown -R rocketmq. $WORK_DIR /home/rocketmq
}



start_m(){
	systemctl daemon-reload 
	systemctl enable --now rmq_namesrv_s.service  &>/dev/null
        systemctl enable --now rmq_broker_s.service &>/dev/null
}

check(){
echo -e "\033[1;33mChecking the java program：\033[0m\n"
sleep 3

[ -d $JAVA_DIR ] && $JAVA_DIR/bin/jps -l | grep -v jps 

}

install(){
	start_file_namesrv && \
	start_file_broker && \
	configM	&& \
	env_u && \
	start_m && echo -ne "\033[1;32mInstallation Complete\033[0m\n工作目录：$WORK_DIR\n数据目录：$DATA_DIR\n日志目录：$LOG_DIR\n配置文件路径：$WORK_DIR/rocketmq4.9/broker.conf\nJAVA路径:$JAVA_DIR\n" || \
	echo -e "\033[1;31m错误请检查\033[0m"
#        check
}

main(){
ls $WORK_DIR &>/dev/null
if [ $? -eq 0 ];then
	echo "请手动清理该目录:$WORK_DIR"
else
	echo -e "\033[1;33mWaiting for installation.......\033[0m\n"
	tar xf rocketmq49.tar.gz -C /usr/local
	ps aux  |grep rocketmq | grep -v grep  &>/dev/null

	if [ $? -eq 0 ];then
		echo -e "\033[1;33mrocketmq already exists\033[0m"
		exit 2
	else 
		echo  -e "\033[1;32mrocketmq is being installed!!!\033[0m"
		install
	fi
fi
}


PS3="请输入的您的选择："
select i in "检查java程序" "安装rocketmq" "退出";do
	case $i in 
		"检查java程序")
		check  || echo -e "\033[1;31m未检测到java环境\033[0m"
		;;
		"安装rocketmq")
		main
		;;
		"退出")
		exit 0
		;;
		*)
		echo -e "\033[1;31m无效的选择\033[0m"
	esac
done

