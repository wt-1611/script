#!/bin/bash



WORK_DIR='/usr/local/rocketmq49'
DATA_DIR='/home/rocketmq/store'
LOG_DIR='/home/rocketmq/logs/rocketmqlogs'
JAVA_DIR='/usr/local/rocketmq49/jdk1.8/'


prin(){
	echo -ne "\033[1;37m$1\n \033[0m"
}

prin_ok(){
	echo -ne "\033[1;37;42m OK \033[0m\n"
	 #echo "$(tput setab 2)$(tput setaf 7)$(tput bold) OK $(tput sgr 0)"
}

prin_err(){
	echo -ne "\033[1;37;41m ERROR \033[0m\n"
}

prin_title(){
	 printf "%s\n" "$(tput setaf 3)$(tput bold)============= $1 =============$(tput sgr 0)"
}

start_file_namesrv(){
prin "5. namesrv启动文件创建"
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
	prin "6. broker启动文件创建"
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
	prin "7. broker配置文件创建"
cat > $WORK_DIR/broker.conf <<eof
flushDiskType=SYNC_FLUSH
namesrvAddr=127.0.0.1:9876
storePathRootDir=$DATA_DIR
eof
}

env_u(){
	prin "8. 创建rocket用户和相关目录"
	useradd rocketmq &>/dev/null
	pass=$(openssl rand -base64 16)
	echo $pass | passwd --stdin rocketmq &>/dev/null && echo "rocketmq,$pass" > /root/.pass.csv && printf %.s- {1..30} ;echo -en "\n用户名，密码\n`cat /root/.pass.csv`\n\n";printf %.s- {1..30} ;
	mkdir -p $DATA_DIR
	mkdir -p /home/rocketmq
	chown -R rocketmq. $WORK_DIR /home/rocketmq
}



start_m(){
	echo
	prin "9. 启动namesrv和broker"
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
	start_m && echo -ne "\n\033[1;37;42mInstallation Complete\033[0m\n\n" && printf %.s- {1..30} ;echo -en "\n工作目录：$WORK_DIR\n数据目录：$DATA_DIR\n日志目录：$LOG_DIR\n配置文件：$WORK_DIR/rocketmq4.9/broker.conf\nJAVA路径：$JAVA_DIR\n";printf %.s- {1..30};echo || \
	echo -e "\033[1;31m错误请检查\033[0m"

	# check
}

main(){
prin_title "Software Installation Process"
prin "1.软件环境检测"
ls $WORK_DIR &>/dev/null
if [ $? -eq 0 ];then
	echo "请手动清理该目录:$WORK_DIR 或者输入4" && prin_err 
	#[ $? -eq 0 ] && prin_ok || prin_err
else
	prin_ok

	prin  "2. 解压 or download"
	#prin 1. "解压"
	tar xvf rocketmq49.tar.gz -C /usr/local ##|| curl -sOL https://archive.apache.org/dist/rocketmq/4.9.4/rocketmq-all-4.9.4-bin-release.zip ; unzip rocketmq-all-4.9.4-bin-release.zip 
	[ $? -eq 0 ] && prin_ok || prin_err
	prin "3. 检测是否有残存的rocketmq运行"
	ps aux  |grep rocketmq | grep -v grep  &>/dev/null
	if [ $? -eq 0 ];then
		echo -e "\033[1;33mrocketmq already exists\033[0m" && prin_err
		exit 2
	else 
		prin_ok
		prin "4. rocketmq开始安装"
		install
	fi
fi
}

remove(){
	 prin_title "Uninstall the rocketmq software"
	 prin "1. Close rockermq"
	 systemctl disable --now rmq_namesrv_s.service &>/dev/null
	 systemctl disable --now rmq_broker_s.service  &>/dev/null
	 [ $? -eq 0 ] && prin_ok || prin_err
	 prin "2. Delete program directory"
	 rm -fr $WORK_DIR
	 [ $? -eq 0 ] && prin_ok || prin_err
	 
}



PS3="`echo -ne "\033[1;44m请输入的您的选择:\033[0m "`(退出输入3) "
select i in "检查java程序" "安装rocketmq" "退出" "删除rockermq";do
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
		"删除rockermq")
		remove
		;;
		*)
		echo -e "\033[1;31m无效的选择\033[0m"
	esac
done

