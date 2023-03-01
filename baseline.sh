#!/bin/bash
#Use only Euler and centos7 and above
# [配置备份目录]
BACKUPDIR=/var/log/.backups
if [ ! -d ${BACKUPDIR} ];then  mkdir -vp ${BACKUPDIR}; fi

# [配置记录目录]
HISDIR=/var/log/.history
if [ ! -d ${HISDIR} ];then  mkdir -vp ${HISDIR}; fi

## 名称: err 、info 、warning
## 用途：全局Log信息打印函数
## 参数: $@
log::err() {
  printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[31mERROR: $@ \033[0m\n"
}
log::info() {
  printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[32mINFO: $@ \033[0m\n"
}
log::warning() {
  printf "[$(date +'%Y-%m-%dT%H:%M:%S')]: \033[33mWARNING: $@ \033[0m\n"
}

## 名称: os::Security
## 用途: 操作系统安全加固配置脚本(符合等保要求-三级要求)
## 参数: 无
os::Security () {
    log::info "[-] 用户口令复杂性策略设置 (密码过期周期0~90、到期前15天提示、密码长度至少15、复杂度设置至少有一个大小写、数字、特殊字符、密码三次不能一样、尝试次数为三次)"
    # 相关修改文件备份
    cp /etc/login.defs ${BACKUPDIR}/login.defs.bak;
    cp /etc/pam.d/password-auth ${BACKUPDIR}/password-auth.bak
    cp /etc/pam.d/system-auth ${BACKUPDIR}/system-auth.bak
    egrep -q "^PASS_MIN_DAYS" /etc/login.defs && sed -ri "s/^PASS_MIN_DAYS.*/PASS_MIN_DAYS  0/" /etc/login.defs || echo "PASS_MIN_DAYS  0" >> /etc/login.defs
    egrep -q "^PASS_MAX_DAYS" /etc/login.defs && sed -ri "s/^PASS_MAX_DAYS.*/PASS_MAX_DAYS  90/" /etc/login.defs || echo "PASS_MAX_DAYS  90" >> /etc/login.defs
    egrep -q "^PASS_WARN_AGE" /etc/login.defs && sed -ri "s/^PASS_WARN_AGE.*/PASS_WARN_AGE  15/" /etc/login.defs || echo "PASS_WARN_AGE  15" >> /etc/login.defs
    egrep -q "^PASS_MIN_LEN" /etc/login.defs && sed -ri "s/^PASS_MIN_LEN.*/PASS_MIN_LEN  15/" /etc/login.defs || echo "PASS_MIN_LEN  15" >> /etc/login.defs
    #设置的密码复杂度
    egrep -q "^password.*pam_pwquality.so" /etc/pam.d/password-auth  && sed -ri 's/^password.*pam_pwquality.so.*/password requisite  pam_pwquality.so try_first_pass local_users_only retry=3 minlen=10 minclass=3 enforce_for_root dcredit=-1 lcredit=-1 ucredit=-1 ocredit=-1/' /etc/pam.d/password-auth 
    egrep -q "^password.*pam_pwquality.so" /etc/pam.d/system-auth   && sed -ri 's/^password.*pam_pwquality.so.*/password requisite  pam_pwquality.so try_first_pass local_users_only retry=3 minlen=10 minclass=3 enforce_for_root dcredit=-1 lcredit=-1 ucredit=-1 ocredit=-1/' /etc/pam.d/system-auth 



    log::info "[-] 存储用户密码的文件，其内容经过sha512加密，所以非常注意其权限"
    # 解决首次登录配置密码时提示"passwd: Authentication token manipulation error"
    touch /etc/security/opasswd && chown root:root /etc/security/opasswd && chmod 600 /etc/security/opasswd 

    log::info "[-] 删除潜在威胁文件 "
    find / -maxdepth 3 -name hosts.equiv | xargs rm -rf
    find / -maxdepth 3 -name .netrc | xargs rm -rf
    find / -maxdepth 3 -name .rhosts | xargs rm -rf

    log::info "[-] sshd 服务安全加固设置"
    cp /etc/ssh/sshd_config ${BACKUPDIR}/sshd_config.bak
    sed -i '/^$/d' /etc/ssh/sshd_config 
    sed -i '/^#/d' /etc/ssh/sshd_config 
    # 禁用X11转发以及端口转发
    egrep -q '^X11Forwarding' /etc/ssh/sshd_config && sed -ri "s/^X11Forwarding.*/X11Forwarding no/" /etc/ssh/sshd_config || echo "X11Forwarding no" >> /etc/ssh/sshd_config
    egrep -q '^X11UseLocalhost' /etc/ssh/sshd_config && sed -ri "s/^X11UseLocalhost.*/X11UseLocalhost yes/" /etc/ssh/sshd_config || echo "X11UseLocalhost yes" >> /etc/ssh/sshd_config
    egrep -q '^AllowTcpForwarding' /etc/ssh/sshd_config && sed -ri "s/^AllowTcpForwarding.*/AllowTcpForwarding no/" /etc/ssh/sshd_config || echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config
    egrep -q '^AllowAgentForwarding' /etc/ssh/sshd_config && sed -ri "s/^AllowAgentForwarding.*/AllowAgentForwarding no/" /etc/ssh/sshd_config || echo "AllowAgentForwarding no" >> /etc/ssh/sshd_config

    # 关闭禁用用户的 .rhosts 文件  ~/.ssh/.rhosts 来做为认证: 缺省IgnoreRhosts yes 
    #禁用基于受信主机的无密码登录
    egrep -q "^IgnoreRhosts" /etc/ssh/sshd_config && sed -ri "s/^IgnoreRhosts.*/IgnoreRhosts yes/" /etc/ssh/sshd_config || echo "IgnoreRhosts yes" >> /etc/ssh/sshd_config

    # 禁止root远程登录（推荐配置-根据需求配置）
    egrep -q "^PermitRootLogin" /etc/ssh/sshd_config && sed -ri "s/^PermitRootLogin.*/PermitRootLogin without-password/" /etc/ssh/sshd_config || echo "PermitRootLogin without-password" >> /etc/ssh/sshd_config
    # 登陆前后欢迎提示设置
    egrep -q "^Banner" /etc/ssh/sshd_config && sed -ri "s/^Banner.*/Banner \/etc\/issue/" /etc/ssh/sshd_config || echo "Banner /etc/issue" >> /etc/ssh/sshd_config
    
    #关闭反向解析
    egrep -q "^UseDNS" /etc/ssh/sshd_config && sed -ri 's/^UseDNS.*/UseDNS no/g' /etc/ssh/sshd_config || echo "UseDNS no" >>/etc/ssh/sshd_config 

    #开启公钥
    egrep -q "^PubkeyAuthentication" /etc/ssh/sshd_config && sed -ri 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config || echo "PubkeyAuthentication yes" >>/etc/ssh/sshd_config
    egrep -q "^RSAAuthentication" /etc/ssh/sshd_config && sed -ri 's/^RSAAuthentication.*/RSAAuthentication yes/g' /etc/ssh/sshd_config || echo "RSAAuthentication yes" >>/etc/ssh/sshd_config

    egrep -q "^GSSAPIAuthentication" /etc/ssh/sshd_config &&  sed -ri 's/^GSSAPIAuthentication.*/GSSAPIAuthentication no/g' /etc/ssh/sshd_config || echo "GSSAPIAuthentication no" >>/etc/ssh/sshd_config
    egrep -q "^AllowUsers" /etc/ssh/sshd_config &&  sed -ri 's/^AllowUsers.*/AllowUsers root prtg tomcat/g' /etc/ssh/sshd_config || echo "AllowUsers root prtg tomcat" >>/etc/ssh/sshd_config
    egrep -q "^AuthorizedKeysFile" /etc/ssh/sshd_config &&  sed -ri 's/^AuthorizedKeysFile.*/AuthorizedKeysFile \.ssh\/authorized_keys/g' /etc/ssh/sshd_config || echo "AuthorizedKeysFile .ssh/authorized_keys" >>/etc/ssh/sshd_config

    log::info "[-] 远程SSH登录前后提示警告Banner设置"
    # SSH登录前后提示警告Banner设置
    tee /etc/issue <<'EOF'
****************** [ 安全登陆 (Security Login) ] *****************
Authorized only. All activity will be monitored and reported.By Security Center.

EOF
    # SSH登录后提示Banner
    tee /etc/motd <<'EOF'

################## [ 安全运维 (Security Operation) ] ####################
                      _           _       _ 
                      | |         (_)     (_)
                      | | _   ____ _  ____ _ 
                      | || \ / _  | |/ ___) |
                      | | | ( ( | | ( (___| |
                      |_| |_|\_||_|_|\____)_|
                                                                          
Login success. Please execute the commands and operation data after carefully.

EOF
    #  用户远程登录失败次数与终端超时设置 
    log::info "[-] 用户远程连续登录失败10次锁定帐号5分钟包括root账号"
    cp /etc/pam.d/sshd ${BACKUPDIR}/sshd.bak
    cp /etc/pam.d/login ${BACKUPDIR}/login.bak

    sed -ri '/^auth\s+required\s+pam_tally2.so.*/d'   /etc/pam.d/sshd 
    sed -ri '/^auth\s+required\s+pam_faillock.so.*/d'   /etc/pam.d/sshd     
    sed -ri '2i auth required pam_faillock.so deny=10 unlock_time=300 even_deny_root root_unlock_time=300' /etc/pam.d/sshd

    log::info "[-] 设置登录超时时间为10分钟 "
    egrep -q "^\s*(export|)\s*TMOUT\S\w+.*$" /etc/profile && sed -ri "s/^\s*(export|)\s*TMOUT.\S\w+.*$/export TMOUT=600\nreadonly TMOUT/" /etc/profile || echo -e "export TMOUT=600\nreadonly TMOUT" >> /etc/profile
    egrep -q "^\s*.*ClientAliveInterval\s\w+.*$" /etc/ssh/sshd_config && sed -ri "s/^\s*.*ClientAliveInterval\s\w+.*$/ClientAliveInterval 600/" /etc/ssh/sshd_config || echo "ClientAliveInterval 600" >> /etc/ssh/sshd_config

    log::info "[-] 切换用户日志记录"
    #认证信息服务产生的日志
    egrep -q "^\s*authpriv\.\*\s+.+$" /etc/rsyslog.conf && sed -ri "s/^\s*authpriv\.\*\s+.+$/authpriv.*  \/var\/log\/secure/" /etc/rsyslog.conf || echo "authpriv.*  /var/log/secure" >> /etc/rsyslog.conf
    egrep -q "^(\s*)SULOG_FILE\s+\S*(\s*#.*)?\s*$" /etc/login.defs && sed -ri "s/^(\s*)SULOG_FILE\s+\S*(\s*#.*)?\s*$/\SULOG_FILE  \/var\/log\/.history\/sulog/" /etc/login.defs || echo "SULOG_FILE  /var/log/.history/sulog" >> /etc/login.defs


    log::info "[-] 用户终端执行的历史命令记录 "
    mkdir -p /var/log/.history/
    #chown prtg. /var/log/.history/
    chmod 755 /var/log/.history/
    chattr -R  +a   /var/log/.history/
    cat >/etc/profile.d/env.sh <<EOF
export HISTORY_FILE="/var/log/.history/history_\$(date "+%F")_\$(whoami)"
export HISTTIMEFORMAT="%F_%T $(whoami)@$(who -u am i 2>/dev/null| awk '{print $NF,$2}'|sed -e 's/[()]//g'):"
export PROMPT_COMMAND='{ msg=\$(history 1 | { read x y; echo \$y; });echo \$msg;} >>\$HISTORY_FILE'
EOF
  source /etc/profile.d/env.sh

  log::info "[-] Linux 系统的最大进程数和最大文件打开数限制 "
  egrep -q "^\s*ulimit -HSn\s+\w+.*$" /etc/profile && sed -ri "s/^\s*ulimit -HSn\s+\w+.*$/ulimit -HSn 65535/" /etc/profile || echo "ulimit -HSn 65535" >> /etc/profile
  egrep -q "^\s*ulimit -HSu\s+\w+.*$" /etc/profile && sed -ri "s/^\s*ulimit -HSu\s+\w+.*$/ulimit -HSu 65535/" /etc/profile || echo "ulimit -HSu 65535" >> /etc/profile
  sed -i "/# End/i *  soft  nofile  65535" /etc/security/limits.conf
  sed -i "/# End/i *  hard  nofile  65535" /etc/security/limits.conf
  sed -i "/# End/i *  soft  nproc   65535" /etc/security/limits.conf
  sed -i "/# End/i *  hard  nproc   65535" /etc/security/limits.conf

  log::info "[-] reload ssh"
  systemctl reload sshd
}
os::Security
