#!/bin/bash
ocfg="/etc/opt/opsware/agent/agent_custom.args"
echo "# Custom configuration values for agent">$ocfg
echo cogbot.tmp_dir: /var/opt/opsware/tmp>>$ocfg
mkdir -p /var/opt/opsware/tmp
chmod 0744 /var/opt/opsware/tmp
cat $ocfg
service opsware-agent restart