#   Name: sa_agent_install.sh
#   Author: XHMA
#   Date: 2024-09-04
#   Description: script to install SA agent.
#
#   Changes:
#
#   Date        By      Review          Vers.   Change
#   ==========  ====    ======          =====   ==================================================
#   2024-09-10  XHMA    XXXX            1.0     Intial for SA agent installation
#
#/bin/bash
export PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH
SCRIPT_VERSION="1.0"
# UID check of script
ID=`id -u`
[ $ID -eq 0 ] || { echo "$0 needs root(or sudo to root) permissions to run" ; exit 1 ; }
#OS=$(uname -s | tr A-Z a-z)
# Variables
# ************************************************************
# for Shared customer_id enabel below
# ************************************************************
#OPSW_GW_ADDR=152.73.224.35:3001,152.73.224.36:3001
#OPSW_GW_ADDR=10.226.80.1:3001,10.226.80.2:3001  EBOKS
#OPSW_GW_ADDR=84.225.75.1:3001,84.225.75.2:3001 defaults
# ************************************************************
#
# ************************************************************
# for KMD use below gateway and cusomer
# ************************************************************
OPSW_GW_ADDR=10.226.80.1:3001,10.226.80.2:3001
# ************************************************************
echo "HOSTNAME: $HOSTNAME"
current_datetime=$(date +"%Y-%m-%d %H:%M:%S")
echo "DATETIME : $current_datetime"
echo "USER: $(id -u -n)"
echo "SCRIPT VERSION: $SCRIPT_VERSION"
INSTALL_LOG="/var/tmp/opsware-agent-linux/sa_agent_install.log"
INSTALL_PATH="/var/tmp/opsware-agent-linux/"
INSTALL_WORK="/var/tmp/"
INSTALL_PARAMETERS=" -f -r --force_new_device --force_full_hw_reg --crypto_dir $INSTALL_PATH --logfile $INSTALL_LOG --loglevel info --opsw_gw_addr $OPSW_GW_ADDR --workdir $INSTALL_WORK "
cd $INSTALL_PATH
# INSTALL_PARAMETERS=" -f -r --force_new_device --force_full_hw_reg --crypto_dir $INSTALL_PATH --logfile $INSTALL_LOG --loglevel info --opsw_gw_addr "
AGENT_INSTALLER=""
detect_os() {
	if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
	elif [ "$(uname)" = "AIX" ]; then
        OS="AIX"
        VERSION=$(oslevel)
    else
        OS="Unknown"
        VERSION="Unknown"
    fi
	MAJOR_VERSION=$(echo "$VERSION" | cut -d '.' -f 1)
}
detect_os

######################################################
echo "Detected OS: $OS, Version: $VERSION (Major: $MAJOR_VERSION)"
case "$OS" in
	*Red*Hat*)
		if [ "$MAJOR_VERSION" = "9" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"RHEL9/opsware-agent-90.0.96031.0-linux-RHEL9-X86_64"
		elif [ "$MAJOR_VERSION" = "8" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"RHEL8/opsware-agent-90.0.96031.0-linux-RHEL8-X86_64"
		elif [ "$MAJOR_VERSION" = "7" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"RHEL7/opsware-agent-90.0.96031.0-linux-7SERVER-X86_64"
		elif [ "$MAJOR_VERSION" = "6" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"RHEL6/opsware-agent-90.0.96031.0-linux-6SERVER-X86_64"
		elif [ "$MAJOR_VERSION" = "5" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"RHEL5/opsware-agent-80.0.92926.0-linux-5SERVER-X86_64"
		else
			echo "Unsupported OS or version."
			exit 0
		fi
		;;
	*CentOS*)
		if [ "$MAJOR_VERSION" = "7" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"CentOS7/opsware-agent-90.0.96031.0-linux-CENTOS7-X86_64"
		elif [ "$MAJOR_VERSION" = "6" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"CentOS6/opsware-agent-80.0.92926.0-linux-CENTOS6-X86_64"
		else
			echo "Unsupported OS or version."
			exit 0
		fi
		;;
	*AIX*)
		if [ "$MAJOR_VERSION" = "7" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"AIX7/opsware-agent-90.0.96031.0-AIX7-X86_64"
		elif [ "$MAJOR_VERSION" = "6" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"AIX6/opsware-agent-90.0.96031.0-AIX6-X86_64"
		else
			echo "Unsupported OS or version."
			exit 0
		fi
		;;
	*SLES*)
		if [ "$MAJOR_VERSION" = "15" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"SLESL15/opsware-agent-90.0.96031.0-linux-SLES-15-X86_64"
		elif [ "$MAJOR_VERSION" = "12" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"SLESL12/opsware-agent-90.0.96031.0-linux-SLES-12-X86_64"
		elif [ "$MAJOR_VERSION" = "11" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"SLESL11/opsware-agent-80.0.92926.0-linux-SLES-11-X86_64"
		else
			echo "Unsupported OS or version."
			exit 0
		fi
		;;
	*Oracle*Linux*)
		if [ "$MAJOR_VERSION" = "7" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"OEL7/opsware-agent-80.0.90150.0-linux-OEL7-X86_64"
		else
			echo "Unsupported OS or version."
			exit 0
		fi
		;;
	*Ubuntu*)
		if [ "$MAJOR_VERSION" = "22" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"Ubuntu22.04/opsware-agent-90.0.96031.0-linux-UBUNTU-22.04-X86_64"
		elif [ "$MAJOR_VERSION" = "18" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"Ubuntu18.04/opsware-agent-90.0.96031.0-linux-UBUNTU-18.04-X86_64"
		elif [ "$MAJOR_VERSION" = "16" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"Ubuntu16.04/opsware-agent-90.0.96031.0-linux-UBUNTU-16.04-X86_64"
		elif [ "$MAJOR_VERSION" = "14" ]; then
			export AGENT_INSTALLER=$INSTALL_PATH"Ubuntu14.04/opsware-agent-90.0.96031.0-linux-UBUNTU-14.04-X86_64"
		else
			echo "Unsupported OS or version."
			exit 0
		fi
		;;
	*)
		echo "Unsupported OS or version."
		exit 0
		;;
esac
######################################################

#Check if agent port is already in use
if lsof -Pi :1002 -sTCP:LISTEN -t >/dev/null ; then
    echo "Port 1002 is already in use, either SA agent is already installed or the port is used by some process."
	echo "SA agent can't be installed."
	exit 0
fi
#Check if SA agent is already installed
if [ -f /etc/opt/opsware/agent/mid ]; then
	echo "SA agent is already installed, Fix agent's reachability or uninstall SA agent."
	echo "To uninstall SA agent execute the script at path:"
	echo "/opt/opsware/agent/bin/agent_uninstall.sh --force"
	exit 0
fi

#Install SA agent
if [ -f $AGENT_INSTALLER ]; then
	$AGENT_INSTALLER$INSTALL_PARAMETERS$OPSW_GW_ADDR
	exit 0
fi
