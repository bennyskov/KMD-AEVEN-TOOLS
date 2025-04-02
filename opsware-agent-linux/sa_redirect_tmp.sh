#!/bin/bash
ocfg="/etc/opt/opsware/agent/agent_custom.args"
echo "# Custom configuration values for agent">$ocfg
echo cogbot.tmp_dir: /var/opt/opsware/tmp>>$ocfg
mkdir -p /var/opt/opsware/tmp
chmod 0744 /var/opt/opsware/tmp
cat $ocfg
[ -f /sbin/service ] && /sbin/service opsware-agent restart
[ -f /etc/rc.d/init.d/opsware-agent ] && /etc/rc.d/init.d/opsware-agent restart
echo opsware_sa_redirect_tmp completed.