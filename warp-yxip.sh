#!/bin/bash

# Environment variables used to set noninteractive installation mode in Debian or Ubuntu operating systems

export DEBIAN_FRONTEND=noninteractive

# colored text
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN='\033[0m'

red() {
    echo -e "\033[31m\033[01m$1\033[0m"
}

green() {
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow() {
    echo -e "\033[33m\033[01m$1\033[0m"
}

# Multiple ways to determine the operating system. If it is not a supported operating system, exit the script.
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "alpine")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Alpine")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "apk update -f")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install" "apk add -f")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "apk del -f")

[[ $EUID -ne 0 ]] && red "Note: Please run the script under the root user" && exit 1

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && red "The current VPS system is not supported, please use a mainstream operating system" && exit 1

# Some systems do not come with curl, detect and install it.
if [[ -z $(type -P curl) ]]; then
    if [[ ! $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_UPDATE[int]}
    fi
    ${PACKAGE_INSTALL[int]} curl
fi

# Check system kernel version
main=$(uname -r | awk -F . '{print $1}')
minor=$(uname -r | awk -F . '{print $2}')
# Get the system version number
OSID=$(grep -i version_id /etc/os-release | cut -d \" -f2 | cut -d . -f1)
# Check VPS virtualization
VIRT=$(systemd-detect-virt)

# Delete the listening IP in the WGCF default configuration file
wg1="sed -i '/0\.0\.0\.0\/0/d' /etc/wireguard/wgcf.conf" # IPv4
wg2="sed -i '/\:\:\/0/d' /etc/wireguard/wgcf.conf"       # IPv6

#Set DNS server for WGCF configuration file
wg3="sed -i 's/1.1.1.1/1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844/g' /etc/wireguard/wgcf.conf"
wg4="sed -i 's/1.1.1.1/2606:4700:4700::1111,2606:4700:4700::1001,2001:4860:4860::8888,2001:4860:4860::8844,1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4/g' /etc/wireguard/wgcf.conf"

#Set to allow external IP access
wg5='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'                                                                                                                                                                                                                                                                                                                    # IPv4
wg6='sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf'                                                                                                                                                                                                                                                                                          # IPv6
wg7='sed -i "7 s/^/PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf && sed -i "7 s/^/PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP '"'src \K\S+') lookup main\n/"'" /etc/wireguard/wgcf.conf' # 双栈

# Set the listening IP of the WARP-GO configuration file
wgo1='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0#g" /opt/warp-go/warp.conf'      # IPv4
wgo2='sed -i "s#.*AllowedIPs.*#AllowedIPs = ::/0#g" /opt/warp-go/warp.conf'           # IPv6
wgo3='sed -i "s#.*AllowedIPs.*#AllowedIPs = 0.0.0.0/0,::/0#g" /opt/warp-go/warp.conf' #Dual stack

#Set to allow external IP access
wgo4='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf'                                                                                                                                                                                                                                                                                                                      # IPv4
wgo5='sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf'                                                                                                                                                                                                                                                                                            # IPv6
wgo6='sed -i "/\[Script\]/a PostUp = ip -4 rule add from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -4 rule delete from $(ip route get 1.1.1.1 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostUp = ip -6 rule add from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf && sed -i "/\[Script\]/a PostDown = ip -6 rule delete from $(ip route get 2606:4700:4700::1111 | grep -oP "src \K\S+") lookup main\n" /opt/warp-go/warp.conf' # 双栈

# Detect VPS processor architecture
archAffix() {
    case "$(uname -m)" in
        i386 | i686) echo '386' ;;
        x86_64 | amd64) echo 'amd64' ;;
        armv8 | arm64 | aarch64) echo 'arm64' ;;
        s390x) echo 's390x' ;;
        *) red "Unsupported CPU architecture!" && exit 1 ;;
    esac
}

# Detect the outbound IP of the VPS
check_ip() {
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)
}

# Detect the IP form of VPS
check_stack() {
    lan4=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    lan6=$(ip route get 2606:4700:4700::1111 2>/dev/null | grep -oP 'src \K\S+')
    if [[ "$lan4" =~ ^([0-9]{1,3}\.){3} ]]; then
        ping -c2 -W3 1.1.1.1 >/dev/null 2>&1 && out4=1
    fi
    if [[ "$lan6" != "::1" && "$lan6" =~ ^([a-f0-9]{1,4}:){2,4}[a-f0-9]{ 1,4} ]]; then
        ping6 -c2 -w10 2606:4700:4700::1111 >/dev/null 2>&1 && out6=1
    fi
}

# Check the WARP status of VPS
check_warp() {
    warp_v4=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    warp_v6=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
}

# Detect WARP+ account traffic
check_quota() {
    if [[ "$CHECK_TYPE" = 1 ]]; then
        # If it is WARP-Cli, use its own interface to obtain traffic
        QUOTA=$(warp-cli --accept-tos account 2>/dev/null | grep -oP 'Quota: \K\d+')
    else
        # Determine whether it is WGCF or WARP-GO, and extract it from the corresponding configuration file of the client.
        if [[ -e "/opt/warp-go/warp-go" ]]; then
            ACCESS_TOKEN=$(grep 'Token' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
            DEVICE_ID=$(grep 'Device' /opt/warp-go/warp.conf | cut -d= -f2 | sed 's# ##g')
        fi
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            ACCESS_TOKEN=$(grep 'access_token' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
            DEVICE_ID=$(grep 'device_id' /etc/wireguard/wgcf-account.toml | cut -d \' -f2)
        fi

        # Use API to obtain traffic information
        API=$(curl -s "https://api.cloudflareclient.com/v0a884/reg/$DEVICE_ID" -H "User-Agent: okhttp/3.12.1" -H "Authorization: Bearer $ACCESS_TOKEN")
        QUOTA=$(grep -oP '"quota":\K\d+' <<<$API)
    fi

    # Flow unit conversion
    [[ $QUOTA -gt 10000000000000 ]] && QUOTA="$(echo "scale=2; $QUOTA/1000000000000" | bc) TB" || QUOTA="$(echo "scale=2; $QUOTA/1000000000" | bc)GB"
}

# Check whether the TUN module is enabled
check_tun() {
    TUN=$(cat /dev/net/tun 2>&1 | tr '[:upper:]' '[:lower:]')
    if [[ ! $TUN =~ "in bad state"|"ist in schlechter Verfassung" ]]; then
        if [[ $VIRT == lxc ]]; then
            if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]]; then
                red "It is detected that the TUN module is not enabled on the current VPS. Please go to the backend control panel to enable it."
                exit 1
            else
                return 0
            fi
        elif [[ $VIRT == "openvz" ]]; then
            wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/tun.sh && bash tun.sh
        else
            red "It is detected that the TUN module is not enabled on the current VPS. Please go to the backend control panel to enable it."
            exit 1
        fi
    fi
}

# Modify IPv4 / IPv6 priority settings
stack_priority() {
    [[ -e /etc/gai.conf ]] && sed -i '/^precedence \:\:ffff\:0\:0/d;/^label 2002\:\:\/16/d' /etc /gai.conf

    yellow "Select IPv4 / IPv6 priority"
    echo ""
    echo -e "${GREEN}1.${PLAIN} IPv4 first"
    echo -e "${GREEN}2.${PLAIN} IPv6 first"
    echo -e "${GREEN}3.${PLAIN} default priority ${YELLOW}(default)${PLAIN}"
    echo ""
    read -rp "Please select option [1-3]:" priority
    case $priority in
        1) echo "precedence ::ffff:0:0/96 100" >>/etc/gai.conf ;;
        2) echo "label 2002::/16 2" >>/etc/gai.conf ;;
        *) yellow "The VPS default IP priority will be used" ;;
    esac
}

# Check the best MTU value for VPS
check_mtu() {
    yellow "Detecting and setting the optimal MTU value, please wait..."
    check_ip
    MTUy=1500
    MTUc=10
    if [[ -n ${ipv6} && -z ${ipv4} ]]; then
        ping='ping6'
        IP1='2606:4700:4700::1001'
        IP2='2001:4860:4860::8888'
    else
        ping='ping'
        IP1='1.1.1.1'
        IP2='8.8.8.8'
    fi
    while true; do
        if ${ping} -c1 -W1 -s$((${MTUy} - 28)) -Mdo ${IP1} >/dev/null 2>&1 || ${ping} -c1 -W1 -s$( (${MTUy} - 28)) -Mdo ${IP2} >/dev/null 2>&1; then
            MTUc=1
            MTUy=$((${MTUy} + ${MTUc}))
        else
            MTUy=$((${MTUy} - ${MTUc}))
            if [[ ${MTUc} = 1 ]]; then
                break
            fi
        fi
        if [[ ${MTUy} -le 1360 ]]; then
            MTUy='1360'
            break
        fi
    done
    # Place the optimal MTU value into the MTU variable for later use
    MTU=$((${MTUy} - 80))

    green "MTU optimal value = $MTU has been set!"
}

# Check the best Endpoint IP address for VPS
check_endpoint() {
    yellow "Detecting and setting the best Endpoint IP, please wait, it will take about 1-2 minutes..."

    # Download the preferred tool software, thanks to an anonymous netizen for sharing the preferred tool
    wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-yxip/warp-linux-$(archAffix) -O warp >/dev/null 2>&1

    # Based on the outbound IP of the VPS, generate the corresponding preferred Endpoint IP segment list
    check_ip

    # Generate preferred Endpoint IP file
    if [[ -n $ipv4 ]]; then
        n=0
        iplist=100
        while true; do
            temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 162.159.204.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
        done
        while true; do
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.192.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.193.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.195.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 162.159.204.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.96.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.97.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.98.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo 188.114.99.$(($RANDOM % 256)))
                n=$(($n + 1))
            fi
        done
    else
        n=0
        iplist=100
        while true; do
            temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
            temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
            n=$(($n + 1))
            if [ $n -ge $iplist ]; then
                break
            fi
        done
        while true; do
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo [2606:4700:d0::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
                n=$(($n + 1))
            fi
            if [ $(echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u | wc -l) -ge $iplist ]; then
                break
            else
                temp[$n]=$(echo [2606:4700:d1::$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2))):$(printf '%x\n' $(($RANDOM * 2 + $RANDOM % 2)))])
                n=$(($n + 1))
            fi
        done
    fi

# Put the generated IP segment list into ip.txt and wait for program optimization
    echo ${temp[@]} | sed -e 's/ /\n/g' | sort -u >ip.txt

    # Cancel the thread limit that comes with Linux to generate the preferred Endpoint IP
    ulimit -n 102400

    # Start the WARP Endpoint IP optimization tool
    chmod +x warp && ./warp >/dev/null 2>&1

    # Extract the preferred Endpoint IP from the result.csv file and place it in the best_endpoint variable for later use.
    best_endpoint=$(cat result.csv | sed -n 2p | awk -F ',' '{print $1}')

    # Check whether the loss of the selected Endpoint IP is 100.00%. If so, replace it with the default Endpoint IP
    endpoint_loss=$(cat result.csv | sed -n 2p | awk -F ',' '{print $2}')
    if [[ $endpoint_loss == "100.00%" ]]; then
        # Check the outbound IP status of VPS
        check_ip

        # If there is no IPv4, use the Endpoint IP of IPv6. If there is IPv4, use the IPv4 Endpoint IP.
        if [[ -z $ipv4 ]]; then
            best_endpoint="[2606:4700:4700::1111]:2408"
        else
            best_endpoint="162.159.193.10:2408"
        fi
    fi

    # Delete the WARP Endpoint IP preferred tool and its accompanying files
    rm -f warp ip.txt result.csv

    green "Best Endpoint IP = $best_endpoint has been set!"
}

# Select WGCF installation/switch mode
select_wgcf() {
    yellow "Please select the WGCF installation/switching mode"
    echo ""
    echo -e "${GREEN}1.${PLAIN} Install/Switch WGCF-WARP single stack mode ${YELLOW}(IPv4)${PLAIN}"
    echo -e "${GREEN}2.${PLAIN} Install/Switch WGCF-WARP single stack mode ${YELLOW}(IPv6)${PLAIN}"
    echo -e "${GREEN}3.${PLAIN} install/switch WGCF-WARP dual-stack mode"
    echo ""
    read -p "Please enter options [1-3]: " wgcf_mode
    if [ "$wgcf_mode" = "1" ]; then
        install_wgcf_ipv4
    elif [ "$wgcf_mode" = "2" ]; then
        install_wgcf_ipv6
    elif [ "$wgcf_mode" = "3" ]; then
        install_wgcf_dual
    else
        red "Input error, please re-enter"
        select_wgcf
    fi
}

install_wgcf_ipv4() {
    # Check WARP status
    check_warp

    # If WARP is enabled, disable it
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Because WGCF conflicts with WARP-GO, the installation is interrupted after detecting WARP-GO.
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO has been installed, please uninstall WARP-GO first"
        exit 1
    fi

    # Check the IP form of VPS
    check_stack

    # According to the detection results, select the appropriate mode for installation
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg2 && wgcf2=$wg3 && wgcf3=$wg5
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg2 && wgcf2=$wg4
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        #Dual stack
        wgcf1=$wg2 && wgcf2=$wg3 && wgcf3=$wg5
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg2 && wgcf2=$wg4 && wgcf3=$wg5
    fi

    # Check whether WGCF is installed. If installed, switch the configuration file. Otherwise perform the installation operation
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

install_wgcf_ipv6() {
    # Check WARP status
    check_warp

    # If WARP is enabled, disable it
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Because WGCF conflicts with WARP-GO, the installation is interrupted after detecting WARP-GO.
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO has been installed, please uninstall WARP-GO first"
        exit 1
    fi

    # Check the IP form of VPS
    check_stack

    # According to the detection results, select the appropriate mode for installation
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg1 && wgcf2=$wg3
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg1 && wgcf2=$wg4 && wgcf3=$wg6
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        #Dual stack
        wgcf1=$wg1 && wgcf2=$wg3 && wgcf3=$wg6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg1 && wgcf2=$wg4 && wgcf3=$wg6
    fi

    # Check whether WGCF is installed. If installed, switch the configuration file. Otherwise perform the installation operation
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

install_wgcf_dual() {
    # Check WARP status
    check_warp

    # If WARP is enabled, disable it
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Because WGCF conflicts with WARP-GO, the installation is interrupted after detecting WARP-GO.
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        red "WARP-GO has been installed, please uninstall WARP-GO first"
        exit 1
    fi

    # Check the IP form of VPS
    check_stack

    # According to the detection results, select the appropriate mode for installation
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wgcf1=$wg3 && wgcf2=$wg5
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wgcf1=$wg4 && wgcf2=$wg6
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        #Dual stack
        wgcf1=$wg3 && wgcf2=$wg7
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wgcf1=$wg4 && wgcf2=$wg6
    fi

    # Check whether WGCF is installed. If installed, switch the configuration file. Otherwise perform the installation operation
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        switch_wgcf_conf
    else
        install_wgcf
    fi
}

# Download WGCF
init_wgcf() {
    wget --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wgcf/wgcf-latest-linux-$(archAffix) -O /usr/local /bin/wgcf
    chmod +x /usr/local/bin/wgcf
}

# Use WGCF to register a CloudFlare WARP account
register_wgcf() {
    if [[ $country4 == "Russia" || $country6 == "Russia" ]]; then
        # Download WARP API tool
        wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-api/main-linux-$(archAffix)
        chmod +x main-linux-$(archAffix)

        # Run WARP API
        arch=$(archAffix)
        result_output=$(./main-linux-$arch)

        # Get device ID, private key and WARP TOKEN
        device_id=$(echo "$result_output" | awk -F ': ' '/device_id/{print $2}')
        private_key=$(echo "$result_output" | awk -F ': ' '/private_key/{print $2}')
        warp_token=$(echo "$result_output" | awk -F ': ' '/token/{print $2}')
        license_key=$(echo "$result_output" | awk -F ': ' '/license/{print $2}')

        #Write WGCF configuration file
        cat << EOF > wgcf-account.toml
access_token = '$warp_token'
device_id = '$device_id'
license_key = '$license_key'
private_key = '$private_key'
EOF

        # Delete WARP API tool
        rm -f main-linux-$(archAffix)

        # Generate WireGuard configuration file
        wgcf generate && chmod +x wgcf-profile.conf
    else
        # If a WARP account has been registered, it will be automatically pulled. Avoid burdening CloudFlare servers
        if [[ -f /etc/wireguard/wgcf-account.toml ]]; then
            cp -f /etc/wireguard/wgcf-account.toml /root/wgcf-account.toml
        fi

        # Register a WARP account until the registration is successful
        until [[ -e wgcf-account.toml ]]; do
            yellow "Registering an account with CloudFlare WARP. If a 429 Too Many Requests error is displayed, please wait patiently for the script to retry the registration."
            wgcf register --accept-tos
            sleep 5
        done
        chmod +x wgcf-account.toml

        # Generate WireGuard configuration file
        wgcf generate && chmod +x wgcf-profile.conf
    fi
}

# Configure WGCF’s WireGuard configuration file
conf_wgcf() {
    echo $wgcf1 | sh
    echo $wgcf2 | sh
    echo $wgcf3 | sh
}

# Check whether WGCF is started successfully. If it is not started successfully, prompt
check_wgcf() {
    yellow "Starting WGCF-WARP"
    i=0
    while [ $i -le 4 ]; do
        let i++
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl start wg-quick@wgcf >/dev/null 2>&1
        check_warp
        if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
            green "WGCF-WARP has been started successfully!"
            systemctl enable wg-quick@wgcf >/dev/null 2>&1
            echo ""
            red "The following is the advertisement for Chafan:"
            yellow "Reimu Airport"
            green "Dedicated line node acceleration, support for streaming media unlocking, support for ChatGPT, 4k seconds to open during evening peak, most of them are x0.5 times nodes, all this for only 9.9 yuan"
            yellow "Discounts are available at: https://reimu.work/auth/register?code=aKKj"
            yellow "TG group: https://t.me/ReimuCloudGrup"
            echo ""
            before_showinfo && show_info
            break
        else
            red "WGCF-WARP startup failed!"
        fi
        check_warp
        if [[ ! $warp_v4 =~ on|plus && ! $warp_v6 =~ on|plus ]]; then
            wg-quick down wgcf 2>/dev/null
            systemctl stop wg-quick@wgcf >/dev/null 2>&1
            systemctl disable wg-quick@wgcf >/dev/null 2>&1
            red "Failed to install WGCF-WARP!"
            green "Suggestions are as follows:"
            yellow "1. It is strongly recommended to use official sources to upgrade the system and kernel acceleration! If you have used third-party sources and kernel acceleration, please be sure to update to the latest version, or reset to the official sources"
            yellow "2. Some VPS systems are extremely streamlined, and related dependencies need to be installed by yourself before trying again"
            yellow "3. Check https://www.cloudflarestatus.com/, the area near your current VPS may be in yellow [Re-routed] status"
            yellow "4. WGCF is officially banned by CloudFlare in Hong Kong and Western US regions. Please uninstall WGCF and try again using WARP-GO"
            yellow "5. The script may not keep up with the times. It is recommended to post screenshots to GitLab Issues or TG group for inquiry."
            exit 1
        fi
    done
}

install_wgcf() {
    # Detect system requirements and interrupt the installation if the requirements are not met.
    [[ $SYSTEM == "CentOS" ]] && [[ ${OSID} -lt 7 ]] && yellow "Current system version: ${CMD} \nWGCF-WARP mode only supports CentOS/Almalinux/Rocky/Oracle Linux 7 and above version of the system" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ${OSID} -lt 10 ]] && yellow "Current system version: ${CMD} \nWGCF-WARP mode only supports Debian 10 and above systems" && exit 1
    [[ $SYSTEM == "Fedora" ]] && [[ ${OSID} -lt 29 ]] && yellow "Current system version: ${CMD} \nWGCF-WARP mode only supports Fedora 29 and above systems" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ${OSID} -lt 18 ]] && yellow "Current system version: ${CMD} \nWGCF-WARP mode only supports Ubuntu 16.04 and above systems" && exit 1

    # Check whether the TUN module is enabled
    check_tun

    # Set IPv4 / IPv6 priority
    stack_priority

    #Install WGCF required dependencies
    if [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep net-tools iproute2 openresolv openrc iptables ip6tables wireguard-tools
    fi
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
        if [[ $OSID == 9 ]] && [[ -z $(type -P resolvconf) ]]; then
            wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/resolvconf -O /usr/sbin/resolvconf
            chmod +x /usr/sbin/resolvconf
        fi
    fi
    if [[ $SYSTEM == "Fedora" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip iproute net-tools wireguard-tools iptables bc htop screen python3 iputils qrencode
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo wget curl unzip lsb-release bc htop screen python3 inetutils-ping qrencode
        echo "deb http://deb.debian.org/debian $(lsb_release -sc)-backports main" | tee /etc/apt/sources.list.d/backports.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget unzip lsb-release bc htop screen python3 inetutils-ping qrencode
        ${PACKAGE_INSTALL[int]} --no-install-recommends net-tools iproute2 openresolv dnsutils wireguard-tools iptables
    fi

    # If the Linux system kernel version is < 5.6, or it is a VPS with OpenVZ / LXC virtualization architecture, install Wireguard-GO
    if [[ $main -lt 5 ]] || [[ $minor -lt 6 ]] || [[ $VIRT =~ lxc|openvz ]]; then
        wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wireguard-go/wireguard-go-$(archAffix) -O /usr /bin/wireguard-go
        chmod +x /usr/bin/wireguard-go
    fi

    # IPv4 only VPS Enable IPv6 support
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} | grep 'disable_ipv6.*=.*1') ] ]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*}
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
    fi

    # Download and install WGCF
    init_wgcf

    # Register an account with WGCF
    register_wgcf

    # Check whether the /etc/wireguard folder is created, if not created, create one
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi

    # Move the corresponding configuration file to prevent users from deleting it
    cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    # Set up WGCF’s WireGuard configuration file
    conf_wgcf

    # Check optimal MTU value and apply to WGCF configuration file
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /etc/wireguard/wgcf.conf

    # Prefer EndPoint IP and apply to WGCF configuration file
    check_endpoint
    sed -i "s/engage.cloudflareclient.com:2408/$best_endpoint/g" /etc/wireguard/wgcf.conf

    # Start WGCF and check whether WGCF starts successfully
    check_wgcf
}

switch_wgcf_conf() {
    # Close WGCF
    wg-quick down wgcf 2>/dev/null
    systemctl stop wg-quick@wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null

    # Delete the configured WGCF WireGuard configuration file and pull it from wgcf-profile.conf again
    rm -rf /etc/wireguard/wgcf.conf
    cp -f /etc/wireguard/wgcf-profile.conf /etc/wireguard/wgcf.conf >/dev/null 2>&1

    # Set up WGCF’s WireGuard configuration file
    conf_wgcf

    # Check optimal MTU value and apply to WGCF configuration file
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /etc/wireguard/wgcf.conf

    # Prefer EndPoint IP and apply to WGCF configuration file
    check_endpoint
    sed -i "s/engage.cloudflareclient.com:2408/$best_endpoint/g" /etc/wireguard/wgcf.conf

    # Start WGCF and check whether WGCF starts successfully
    check_wgcf
}

# Uninstall WGCF
uninstall_wgcf() {
    # Close WGCF
    wg-quick down wgcf 2>/dev/null
    systemctl stop wg-quick@wgcf 2>/dev/null
    systemctl disable wg-quick@wgcf 2>/dev/null

    # Uninstall WireGuard dependency
    ${PACKAGE_UNINSTALL[int]} wireguard-tools

    # Because WireProxy needs to rely on WGCF, if it is not detected, the account information file will be deleted.
    if [[ -z $(type -P wireproxy) ]]; then
        rm -f /usr/local/bin/wgcf
        rm -f /etc/wireguard/wgcf-profile.toml
        rm -f /etc/wireguard/wgcf-account.toml
    fi

    # Delete WGCF WireGuard configuration file
    rm -f /etc/wireguard/wgcf.conf

    # If there is WireGuard-GO, delete it
    rm -f /usr/bin/wireguard-go

    # Restore VPS default outbound rules
    if [[ -e /etc/gai.conf ]]; then
        sed -i '/^precedence[ ]*::ffff:0:0\/96[ ]*100/d' /etc/gai.conf
    fi

    green "WGCF-WARP has been completely uninstalled successfully!"
    before_showinfo && show_info
}

# Set up WARP-GO configuration file
conf_wpgo() {
    echo $wpgo1 | sh
    echo $wpgo2 | sh
}

# Use WARP API to register a WARP free version account and apply it to WARP-GO
register_wpgo(){
    # Download WARP API tool
    wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-api/main-linux-$(archAffix)
    chmod +x main-linux-$(archAffix)

    # Run WARP API
    arch=$(archAffix)
    result_output=$(./main-linux-$arch)

    # Get device ID, private key and WARP TOKEN
    device_id=$(echo "$result_output" | awk -F ': ' '/device_id/{print $2}')
    private_key=$(echo "$result_output" | awk -F ': ' '/private_key/{print $2}')
    warp_token=$(echo "$result_output" | awk -F ': ' '/token/{print $2}')

    #Write WARP-GO configuration file
    cat << EOF > /opt/warp-go/warp.conf
[Account]
Device = $device_id
PrivateKey = $private_key
Token = $warp_token
Type = free
Name=WARP
MTU = 1280

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
Endpoint = 162.159.193.10:1701
# AllowedIPs = 0.0.0.0/0
# AllowedIPs = ::/0
KeepAlive=30
EOF
    
    sed -i '0,/AllowedIPs/{/AllowedIPs/d;}' /opt/warp-go/warp.conf
    sed -i '/KeepAlive/a [Script]' /opt/warp-go/warp.conf

    # Delete WARP API tool
    rm -f main-linux-$(archAffix)
}

# Check whether WARP-GO is running normally
check_wpgo() {
    yellow "Starting WARP-GO"
    i=0
    while [ $i -le 4 ]; do
        let i++
        kill -15 $(pgrep warp-go) >/dev/null 2>&1
        sleep 2
        systemctl stop warp-go
        systemctl disable warp-go >/dev/null 2>&1
        systemctl start warp-go
        systemctl enable warp-go >/dev/null 2>&1
        check_warp
        sleep 2
        if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
            green "WARP-GO has started successfully!"
            echo ""
            red "The following is the advertisement for Chafan:"
            yellow "Reimu Airport"
            green "Dedicated line node acceleration, support for streaming media unlocking, support for ChatGPT, 4k seconds to open during evening peak, most of them are x0.5 times nodes, all this for only 9.9 yuan"
            yellow "Discounts are available at: https://reimu.work/auth/register?code=aKKj"
            yellow "TG group: https://t.me/ReimuCloudGrup"
            echo ""
            before_showinfo && show_info
            break
        else
            red "WARP-GO failed to start!"
        fi

        check_warp
        if [[ ! $warp_v4 =~ on|plus && ! $warp_v6 =~ on|plus ]]; then
            systemctl stop warp-go
            systemctl disable warp-go >/dev/null 2>&1
            red "Failed to install WARP-GO!"
            green "Suggestions are as follows:"
            yellow "1. It is strongly recommended to use official sources to upgrade the system and kernel acceleration! If you have used third-party sources and kernel acceleration, please be sure to update to the latest version, or reset to the official sources"
            yellow "2. Some VPS systems are extremely streamlined, and related dependencies need to be installed by yourself before trying again"
            yellow "3. The script may not keep up with the times. It is recommended to post screenshots to GitLab Issues or TG group for inquiry."
            exit 1
        fi
    done
}

# Select WARP-GO installation/switch mode
select_wpgo() {
    yellow "Please select the WARP-GO installation/switching mode"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} Install/Switch WARP-GO single stack mode ${YELLOW}(IPv4)${PLAIN}"
    echo -e "${GREEN}2.${PLAIN} Install/Switch WARP-GO single stack mode ${YELLOW}(IPv6)${PLAIN}"
    echo -e "${GREEN}3.${PLAIN} install/switch WARP-GO dual stack mode"
    echo ""
    read -p "Please enter options [1-3]: " wpgo_mode
    if [ "$wpgo_mode" = "1" ]; then
        install_wpgo_ipv4
    elif [ "$wpgo_mode" = "2" ]; then
        install_wpgo_ipv6
    elif [ "$wpgo_mode" = "3" ]; then
        install_wpgo_dual
    else
        red "Input error, please re-enter"
        select_wpgo
    fi
}

install_wpgo_ipv4() {
    # Check WARP status
    check_warp

    # If WARP is enabled, disable it
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Because WARP-GO conflicts with WGCF, the installation is interrupted after detecting WGCF.
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "WGCF-WARP has been installed, please uninstall WGCF-WARP first"
        exit 1
    fi

    # Check the IP form of VPS
    check_stack

    # According to the detection results, select the appropriate mode for installation
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wpgo1=$wgo1 && wpgo2=$wgo4
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wpgo1=$wgo1 && wpgo2=$wgo5
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        #Dual stack
        wpgo1=$wgo1 && wpgo2=$wgo6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wpgo1=$wgo1 && wpgo2=$wgo6
    fi

    # Check whether WARP-GO is installed. If installed, switch the configuration file. Otherwise perform the installation operation
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        switch_wpgo_conf
    else
        install_wpgo
    fi
}

install_wpgo_ipv6() {
    # Check WARP status
    check_warp

    # If WARP is enabled, disable it
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Because WARP-GO conflicts with WGCF, the installation is interrupted after detecting WGCF.
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "WGCF-WARP has been installed, please uninstall WGCF-WARP first"
        exit 1
    fi

    # Check the IP form of VPS
    check_stack

    # According to the detection results, select the appropriate mode for installation
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wpgo1=$wgo2 && wpgo2=$wgo4
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wpgo1=$wgo2 && wpgo2=$wgo5
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        #Dual stack
        wpgo1=$wgo2 && wpgo2=$wgo6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wpgo1=$wgo2 && wpgo2=$wgo6
    fi

    # Check whether WARP-GO is installed. If installed, switch the configuration file. Otherwise perform the installation operation
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        switch_wpgo_conf
    else
        install_wpgo
    fi
}

install_wpgo_dual() {
    # Check WARP status
    check_warp

    # If WARP is enabled, disable it
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Because WARP-GO conflicts with WGCF, the installation is interrupted after detecting WGCF.
    if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        red "WGCF-WARP has been installed, please uninstall WGCF-WARP first"
        exit 1
    fi

    # Check the IP form of VPS
    check_stack

    # According to the detection results, select the appropriate mode for installation
    if [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]]; then
        # IPv4 Only
        wpgo1=$wgo3 && wpgo2=$wgo4
    elif [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # IPv6 Only
        wpgo1=$wgo3 && wpgo2=$wgo5
    elif [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]]; then
        #Dual stack
        wpgo1=$wgo3 && wpgo2=$wgo6
    elif [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        # NAT IPv4 + IPv6
        wpgo1=$wgo3 && wpgo2=$wgo6
    fi

    # Check whether WARP-GO is installed. If installed, switch the configuration file. Otherwise perform the installation operation
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        switch_wpgo_conf
    else
        install_wpgo
    fi
}

install_wpgo() {
    # Check whether the TUN module is enabled
    check_tun

    # Set IPv4 / IPv6 priority
    stack_priority

    # Install WARP-GO required dependencies
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop iputils screen python3 qrencode
    elif [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep bc htop iputils screen python3 qrencode
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop inetutils-ping screen python3 qrencode
    fi

# IPv4 only VPS Enable IPv6 support
    if [[ $(sysctl -a | grep 'disable_ipv6.*=.*1') || $(cat /etc/sysctl.{conf,d/*} | grep 'disable_ipv6.*=.*1') ] ]; then
        sed -i '/disable_ipv6/d' /etc/sysctl.{conf,d/*}
        echo 'net.ipv6.conf.all.disable_ipv6 = 0' >/etc/sysctl.d/ipv6.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=0
    fi

    # Download WARP-GO
    mkdir -p /opt/warp-go/
    wget -O /opt/warp-go/warp-go https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/warp-go/warp-go-latest-linux-$ (archAffix)
    chmod +x /opt/warp-go/warp-go

    # Use WARP API to register a free WARP account
    register_wpgo

    # Set up the configuration file of WARP-GO
    conf_wpgo

    # Check optimal MTU value and apply to WARP-GO profile
    check_mtu
    sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

    # Prefer EndPoint IP and apply to WARP-GO configuration file
    check_endpoint
    sed -i "/Endpoint/s/.*/Endpoint = "$best_endpoint"/" /opt/warp-go/warp.conf

    # Set up WARP-GO system service
    cat << EOF > /lib/systemd/system/warp-go.service
[Unit]
Description=warp-go service
After=network.target
Documentation=https://gitlab.com/Misaka-blog/warp-script
Documentation=https://gitlab.com/ProjectWARP/warp-go

[Service]
WorkingDirectory=/opt/warp-go/
ExecStart=/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf
Environment="LOG_LEVEL=verbose"
RemainAfterExit=yes
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # Start WARP-GO and check whether WARP-GO is running normally
    check_wpgo
}

switch_wpgo_conf() {
    # Close WARP-GO
    systemctl stop warp-go
    systemctl disable warp-go

    # Modify configuration file content
    conf_wpgo

    # Check whether WARP-GO is running normally
    check_wpgo
}
uninstall_wpgo() {
    # Close WARP-GO
    systemctl stop warp-go
    systemctl disable --now warp-go >/dev/null 2>&1

    # Check whether the WARP-GO residual process is running, and kill it if it is running.
    kill -15 $(pgrep warp-go) >/dev/null 2>&1

    # Log out the account and delete the configuration file
    /opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --remove >/dev/null 2>&1

    # Delete WARP-GO program and log files
    rm -rf /opt/warp-go /tmp/warp-go* /lib/systemd/system/warp-go.service

    green "WARP-GO has been completely uninstalled successfully!"
}
check_warp_cli(){
    warp-cli --accept-tos connect >/dev/null 2>&1
    warp-cli --accept-tos enable-always-on >/dev/null 2>&1
    sleep 2
    if [[ ! $(ss -nltp) =~ 'warp-svc' ]]; then
        red "WARP-Cli agent mode installation failed"
        green "Suggestions are as follows:"
        yellow "1. It is recommended to use the system's official source to upgrade the system and kernel acceleration! If you have used third-party sources and kernel acceleration, please be sure to update to the latest version, or reset to the system's official source!"
        yellow "2. Some VPS systems are too streamlined, and related dependencies need to be installed by yourself before trying again"
        yellow "3. The script may not keep up with the times. It is recommended to post screenshots to GitLab Issues or TG group for inquiry."
        exit 1
    else
        green "WARP-Cli proxy mode has been started successfully!"
        echo ""
        red "The following is the advertisement for Chafan:"
        yellow "Reimu Airport"
        green "Dedicated line node acceleration, support for streaming media unlocking, support for ChatGPT, 4k seconds to open during evening peak, most of them are x0.5 times nodes, all this for only 9.9 yuan"
        yellow "Discounts are available at: https://reimu.work/auth/register?code=aKKj"
        yellow "TG group: https://t.me/ReimuCloudGrup"
        echo ""
        before_showinfo && show_info
    fi
}

install_warp_cli() {
    # Detect system requirements and interrupt the installation if the requirements are not met.
    [[ $SYSTEM == "CentOS" ]] && [[ ! ${OSID} =~ 8|9 ]] && yellow "Current system version: ${CMD} \nWARP-Cli proxy mode only supports CentOS/Almalinux/Rocky /Oracle Linux 8/9 system" && exit 1
    [[ $SYSTEM == "Debian" ]] && [[ ! ${OSID} =~ 9|10|11 ]] && yellow "Current system version: ${CMD} \nWARP-Cli proxy mode only supports Debian 9- 11system" && exit 1
    [[ $SYSTEM == "Fedora" ]] && yellow "Current system version: ${CMD} \nWARP-Cli does not support Fedora system temporarily" && exit 1
    [[ $SYSTEM == "Ubuntu" ]] && [[ ! ${OSID} =~ 16|18|20|22 ]] && yellow "Current system version: ${CMD} \nWARP-Cli proxy mode only supports Ubuntu 16.04/18.04/20.04/22.04 system" && exit 1

    [[ ! $(archAffix) == "amd64" ]] && red "WARP-Cli does not currently support the current CPU architecture of VPS, please use a VPS with a CPU architecture of amd64" && exit 1

    # Check whether the TUN module is enabled
    check_tun

    # Since the CloudFlare WARP client currently only supports the AMD64 CPU architecture, if other architectures are detected, the installation will be interrupted.
    if [[ ! $(archAffix) == "amd64" ]]; then
        red "WARP-Cli currently does not support the CPU architecture of the current VPS, please use a VPS with a CPU architecture of amd64" && exit 1
        exit 1
    fi

    # Detect the IP form of the VPS. If it is an IPv6 Only VPS, interrupt the installation (when will CloudFlare make some efforts to support it without looking like a mother)
    check_stack
    if [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]]; then
        red "WARP-Cli currently does not support IPv6 Only VPS, please use a VPS with IPv4 network" && exit 1
    fi

    # Install WARP-Cli and its dependencies
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} epel-release
        ${PACKAGE_INSTALL[int]} sudo curl wget net-tools bc htop iputils screen python3 qrencode
        rpm -ivh http://pkg.cloudflareclient.com/cloudflare-release-el8.rpm
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    if [[ $SYSTEM == "Debian" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3 qrencode
        [[ -z $(type -P gpg 2>/dev/null) ]] && ${PACKAGE_INSTALL[int]} gnupg
        [[ -z $(apt list 2>/dev/null | grep apt-transport-https | grep installed) ]] && ${PACKAGE_INSTALL[int]} apt-transport-https
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi
    if [[ $SYSTEM == "Ubuntu" ]]; then
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget lsb-release bc htop inetutils-ping screen python3 qrencode
        curl https://pkg.cloudflareclient.com/pubkey.gpg | apt-key add -
        echo "deb http://pkg.cloudflareclient.com/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} cloudflare-warp
    fi

    #Ask the user for the port used by WARP-Cli proxy mode. If it is occupied, it will prompt to change it.
    read -rp "Please enter the port used by WARP-Cli proxy mode (default random port):" port
    [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                yellow "The port you set is currently occupied, please re-enter the port"
                read -rp "Please enter the port used by WARP-Cli proxy mode (default random port):" port
            fi
        done
    fi

    # Register an account with CloudFlare WARP
    warp-cli --accept-tos register >/dev/null 2>&1

    # Set proxy mode and socks5 port in WARP-Cli
    warp-cli --accept-tos set-mode proxy >/dev/null 2>&1
    warp-cli --accept-tos set-proxy-port "$port" >/dev/null 2>&1

    # Prefer EndPoint IP and apply to WARP-Cli
    check_endpoint
    warp-cli --accept-tos set-custom-endpoint "$best_endpoint" >/dev/null 2>&1

    # Start WARP-Cli and check if it is running normally
    check_warp_cli
}

uninstall_warp_cli() {
    # Close WARP-Cli
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos disable-always-on >/dev/null 2>&1
    warp-cli --accept-tos delete >/dev/null 2>&1
    systemctl disable --now warp-svc >/dev/null 2>&1

    # Uninstall WARP-Cli
    ${PACKAGE_UNINSTALL[int]} cloudflare-warp

    green "WARP-Cli client has been completely uninstalled successfully!"
    before_showinfo && show_info
}
check_wireproxy(){
    yellow "Starting WireProxy-WARP proxy mode"
    systemctl start wireproxy-warp
    wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
    sleep 2
    retry_time=0
    until [[ $wireproxy_status =~ on|plus ]]; do
        retry_time=$((${retry_time} + 1))
        red "Failed to start WireProxy-WARP proxy mode, trying to restart, number of retries: $retry_time"
        systemctl stop wireproxy-warp
        systemctl start wireproxy-warp
        wireproxy_status=$(curl -sx socks5h://localhost:$port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        if [[ $retry_time == 6 ]]; then
            echo ""
            red "Failed to install WireProxy-WARP proxy mode!"
            green "Suggestions are as follows:"
            yellow "1. It is strongly recommended to use official sources to upgrade the system and kernel acceleration! If you have used third-party sources and kernel acceleration, please be sure to update to the latest version, or reset to the official sources"
            yellow "2. Some VPS systems are extremely streamlined, and related dependencies need to be installed by yourself before trying again"
            yellow "3. Check https://www.cloudflarestatus.com/, the area near your current VPS may be in yellow [Re-routed] status"
            yellow "4. WGCF has been officially banned by CloudFlare in Hong Kong and Western United States"
            yellow "5. The script may not keep up with the times. It is recommended to post screenshots to GitLab Issues or TG group for inquiry."
            exit 1
        fi
        sleep 8
    done
    sleep 5
    systemctl enable wireproxy-warp >/dev/null 2>&1
    green "WireProxy-WARP proxy mode has been started successfully!"
    echo ""
    red "The following is the advertisement for Chafan:"
    yellow "Reimu Airport"
    green "Dedicated line node acceleration, support for streaming media unlocking, support for ChatGPT, 4k seconds to open during evening peak, most of them are x0.5 times nodes, all this for only 9.9 yuan"
    yellow "Discounts are available at: https://reimu.work/auth/register?code=aKKj"
    yellow "TG group: https://t.me/ReimuCloudGrup"
    echo ""
    before_showinfo && show_info
}

install_wireproxy() {
    #Install WireProxy dependencies
    if [[ $SYSTEM == "CentOS" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop iputils screen python3 qrencode wireguard-tools
    elif [[ $SYSTEM == "Alpine" ]]; then
        ${PACKAGE_INSTALL[int]} sudo curl wget bash grep bc htop iputils screen python3 qrencode wireguard-tools
    else
        ${PACKAGE_UPDATE[int]}
        ${PACKAGE_INSTALL[int]} sudo curl wget bc htop inetutils-ping screen python3 qrencode wireguard-tools
    fi

    # Download WireProxy
    wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wireproxy/wireproxy-latest-linux-$(archAffix) -O /usr/local/bin/wireproxy
    chmod +x /usr/local/bin/wireproxy

    #Ask the user for the port used by WireProxy. If it is occupied, prompt to change it.
    read -rp "Please enter the port used by WireProxy-WARP proxy mode (default random port):" port
    [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
    if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
        until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
            if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                yellow "The port you set is currently occupied, please re-enter the port"
                read -rp "Please enter the port used by WireProxy-WARP proxy mode (default random port):" port
            fi
        done
    fi

    # Download and install WGCF
    init_wgcf

    # Use WGCF to register an account with CloudFlare WARP
    register_wgcf

    # Extract the public and private keys of the WGCF configuration file
    public_key=$(grep PublicKey wgcf-profile.conf | sed "s/PublicKey = //g")
    private_key=$(grep PrivateKey wgcf-profile.conf | sed "s/PrivateKey = //g")

    # Check whether the /etc/wireguard folder is created, if not created, create one
    if [[ ! -d "/etc/wireguard" ]]; then
        mkdir /etc/wireguard
    fi

    # Turn off WGCF or WARP-GO (if any) first, so as not to affect the check of the best MTU value and preferred EndPoint IP
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl stop warp-go
        systemctl disable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf
    fi

    # Check optimal MTU value
    check_mtu

    # Preferred EndPoint IP
    check_endpoint

    # Start WGCF or WARP-GO (if available)
    if [[ -f "/opt/warp-go/warp-go" ]]; then
        systemctl start warp-go
        systemctl enable warp-go
    elif [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
        wg-quick up wgcf >/dev/null 2>&1
        systemctl enable wg-quick@wgcf
    fi

    #Apply the WireProxy configuration file and move the WGCF configuration file to the /etc/wireguard folder in preparation for installing WGCF-WARP
    cat << EOF > /etc/wireguard/proxy.conf
[Interface]
Address = 172.16.0.2/32
MTU = $MTU
PrivateKey = $private_key
DNS = 1.1.1.1,1.0.0.1,8.8.8.8,8.8.4.4,2606:4700:4700::1001,2606:4700:4700::1111,2001:4860:4860::8888,2001:4860:4860 ::8844
[Peer]
PublicKey = $public_key
Endpoint = $best_endpoint
[Socks5]
BindAddress = 127.0.0.1:$port
EOF
    mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
    mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

    # Set up WireProxy system service
    cat <<'TEXT' >/etc/systemd/system/wireproxy-warp.service
[Unit]
Description=CloudFlare WARP Socks5 proxy mode based for WireProxy, script by Misaka-blog
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=simple
WorkingDirectory=/root
ExecStart=/usr/local/bin/wireproxy -c /etc/wireguard/proxy.conf
Restart=always
TEXT

    # Start WireProxy and check if it is running normally
    check_wireproxy
}

uninstall_wireproxy() {
    # Close WireProxy
    systemctl stop wireproxy-warp
    systemctl disable wireproxy-warp

    # Uninstall WireGuard dependency
    ${PACKAGE_UNINSTALL[int]} wireguard-tools

    # Delete WireProxy program files
    rm -f /etc/systemd/system/wireproxy-warp.service /usr/local/bin/wireproxy /etc/wireguard/proxy.conf

    # If WGCF-WARP is not installed, delete the WGCF account information and configuration files
    if [[ ! -f /etc/wireguard/wgcf.conf ]]; then
        rm -f /usr/local/bin/wgcf /etc/wireguard/wgcf-account.toml
    fi

    green "WireProxy-WARP proxy mode has been completely uninstalled successfully!"
    before_showinfo && show_info
}

change_warp_port() {
    yellow "Please select the WARP client that needs to modify the port"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP-Cli"
    echo -e " ${GREEN}2.${PLAIN} WireProxy"
    echo ""
    read -p "Please enter options [1-2]: " chport_mode
    if [[ $chport_mode == 1 ]]; then
        # If WARP-Cli is starting, shut down
        if [[ $(warp-cli --accept-tos status) =~ Connected ]]; then
            warp-cli --accept-tos disconnect >/dev/null 2>&1
        fi

        #Ask the user for the port used by WARP-Cli proxy mode. If it is occupied, it will prompt to change it.
        read -rp "Please enter the port used by WARP-Cli proxy mode (default random port):" port
        [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
            until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
                if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                    yellow "The port you set is currently occupied, please re-enter the port"
                    read -rp "Please enter the port used by WARP-Cli proxy mode (default random port):" port
                fi
            done
        fi

        #Set the port used by WARP-Cli proxy mode
        warp-cli --accept-tos set-proxy-port "$port" >/dev/null 2>&1

        # Start WARP-Cli and check if it is running normally
        check_warp_cli
    elif [[ $chport_mode == 2 ]]; then
        # If WireProxy is starting, close it
        if [[ -n $(ss -nltp | grep wireproxy) ]]; then
            systemctl stop wireproxy-warp
        fi

        #Ask the user for the port used by WireProxy. If it is occupied, prompt to change it.
        read -rp "Please enter the port used by WireProxy-WARP proxy mode (default random port):" port
        [[ -z $port ]] && port=$(shuf -i 1000-65535 -n 1)
        if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
            until [[ -z $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; do
                if [[ -n $(ss -ntlp | awk '{print $4}' | grep -w "$port") ]]; then
                    yellow "The port you set is currently occupied, please re-enter the port"
                    read -rp "Please enter the port used by WireProxy-WARP proxy mode (default random port):" port
                fi
            done
        fi

        # Get the socks5 port of the current WireProxy
        current_port=$(grep BindAddress /etc/wireguard/proxy.conf)
        sed -i "s/$current_port/BindAddress = 127.0.0.1:$port/g" /etc/wireguard/proxy.conf

        # Start WireProxy and check if it is running normally
        check_wireproxy
    else
        red "Input error, please re-enter"
        change_warp_port
    fi
}

switch_warp() {
    yellow "Please select the WARP client that needs to modify the port"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} Start WGCF-WARP"
    echo -e " ${GREEN}2.${PLAIN} Close WGCF-WARP"
    echo -e " ${GREEN}3.${PLAIN} Restart WGCF-WARP"
    echo -e " ${GREEN}4.${PLAIN} Start WARP-GO"
    echo -e "${GREEN}5.${PLAIN} turn off WARP-GO"
    echo -e " ${GREEN}6.${PLAIN} Restart WARP-GO"
    echo -e "${GREEN}7.${PLAIN} start WARP-Cli"
    echo -e "${GREEN}8.${PLAIN} close WARP-Cli"
    echo -e "${GREEN}9.${PLAIN} restart WARP-Cli"
    echo -e " ${GREEN}10.${PLAIN} Start WireProxy-WARP"
    echo -e " ${GREEN}11.${PLAIN} Close WireProxy-WARP"
    echo -e " ${GREEN}12.${PLAIN} Restart WireProxy-WARP"
    echo ""
    read -rp "Please enter options [0-12]: " switch_input
    case $switch_input in
        1)
            systemctl start wg-quick@wgcf >/dev/null 2>&1
            systemctl enable wg-quick@wgcf >/dev/null 2>&1
            ;;
        2)
            wg-quick down wgcf 2>/dev/null
            systemctl stop wg-quick@wgcf >/dev/null 2>&1
            systemctl disable wg-quick@wgcf >/dev/null 2>&1
            ;;
        3)
            wg-quick down wgcf 2>/dev/null
            systemctl stop wg-quick@wgcf >/dev/null 2>&1
            systemctl disable wg-quick@wgcf >/dev/null 2>&1
            systemctl start wg-quick@wgcf >/dev/null 2>&1
            systemctl enable wg-quick@wgcf >/dev/null 2>&1
            ;;
        4)
            systemctl start warp-go
            systemctl enable warp-go >/dev/null 2>&1
            ;;
        5)
            systemctl stop warp-go
            systemctl disable warp-go >/dev/null 2>&1
            ;;
        6)
            systemctl stop warp-go
            systemctl disable warp-go >/dev/null 2>&1
            systemctl start warp-go
            systemctl enable warp-go >/dev/null 2>&1
            ;;
        7)
            warp-cli --accept-tos connect >/dev/null 2>&1
            warp-cli --accept-tos enable-always-on >/dev/null 2>&1
            ;;
        8) warp-cli --accept-tos disconnect >/dev/null 2>&1 ;;
        9)
            warp-cli --accept-tos disconnect >/dev/null 2>&1
            warp-cli --accept-tos connect >/dev/null 2>&1
            warp-cli --accept-tos enable-always-on >/dev/null 2>&1
            ;;
        10)
            systemctl start wireproxy-warp
            systemctl enable wireproxy-warp
            ;;
        11)
            systemctl stop wireproxy-warp
            systemctl disable wireproxy-warp
            ;;
        12)
            systemctl stop wireproxy-warp
            systemctl disable wireproxy-warp
            systemctl start wireproxy-warp
            systemctl enable wireproxy-warp
            ;;
        *) exit 1 ;;
    esac
}

wireguard_profile() {
    yellow "Please select which WARP client you need to generate the WireGuard configuration file from"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP-GO"
    echo -e "${GREEN}2.${PLAIN} WGCF"
    echo ""
    read -p "Please enter options [1-2]: " profile_mode
    if [[ $profile_mode == 1 ]]; then
        # Call the WARP-GO interface to generate the WireGuard configuration file and determine the generation status
        result=$(/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --export-wireguard=/root/warpgo-proxy.conf) && sleep 5
        if [[ ! $result == "Success" ]]; then
            red "WARP-GO's WireGuard configuration file generation failed!"
            exit 1
        fi

        # Call the WARP-GO interface to generate the Sing-box configuration file and determine the generation status
        result=$(/opt/warp-go/warp-go --config=/opt/warp-go/warp.conf --export-singbox=/root/warpgo-sing-box.json) && sleep 5
        if [[ ! $result == "Success" ]]; then
            red "WARP-GO's Sing-box configuration file generation failed!"
            exit 1
        fi

        # User echo and generate QR code
        green "WARP-GO's WireGuard configuration file has been extracted successfully!"
        yellow "The file content is as follows and has been saved to:/root/warpgo-proxy.conf"
        red "$(cat /root/warpgo-proxy.conf)"
        echo ""
        yellow "The node configuration QR code is as follows:"
        qrencode -t ansiutf8 </root/warpgo-proxy.conf
        echo ""
        echo ""
        green "WARP-GO's Sing-box configuration file has been extracted successfully!"
        yellow "The file content is as follows and has been saved to:/root/warpgo-sing-box.json"
        red "$(cat /root/warpgo-sing-box.json)"
        yellow "Reserved value: $(grep -o '"reserved":\[[^]]*\]' /root/warpgo-sing-box.json)"
        echo ""
        yellow "Please use this method locally: https://blog.misaka.rest/2023/03/12/cf-warp-yxip/ Prefer the available Endpoint IP"
    elif [[ $profile_mode == 2 ]]; then
        #Copy WGCF configuration file
        cp -f /etc/wireguard/wgcf-profile.conf /root/wgcf-proxy.conf

        # User echo and generate QR code
        green "WGCF-WARP's WireGuard configuration file has been extracted successfully!"
        yellow "The file content is as follows and has been saved to:/root/wgcf-proxy.conf"
        red "$(cat /root/wgcf-proxy.conf)"
        echo ""
        yellow "The node configuration QR code is as follows:"
        qrencode -t ansiutf8 </root/wgcf-proxy.conf
        echo ""
        yellow "Please use this method locally: https://blog.misaka.rest/2023/03/12/cf-warp-yxip/ Prefer the available Endpoint IP"
    else
        red "Input error, please re-enter"
        wireguard_profile
    fi
}

warp_traffic() {
    if [[ -z $(type -P screen) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} screen
    fi

    yellow "How to get your own CloudFlare WARP account information: "
    green "PC: Download and install CloudFlare WARP → Settings → Preferences → Copy the device ID into the script"
    green "Mobile phone: Download and install 1.1.1.1 APP → Menu → Advanced → Diagnosis → Copy the device ID into the script"
    echo ""
    yellow "Please follow the instructions below to enter your CloudFlare WARP account information:"
    read -rp "Please enter your WARP device ID (36 characters): " license
    until [[ $license =~ ^[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A- F0-9a-f]{4}-[A-F0-9a-f]{12}$ ]]; do
        red "The device ID input format is incorrect, please re-enter!"
        read -rp "Please enter your WARP device ID (36 characters): " license
    done

    wget -N --no-check-certificate https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/wp-plus.py
    sed -i "27 s/[(][^)]*[)]//g" wp-plus.py && sed -i "27 s/input/'$license'/" wp-plus.py

    read -rp "Please enter Screen session name (default is wp-plus): " screenname
    [[ -z $screenname ]] && screenname="wp-plus"
    screen -UdmS $screenname bash -c '/usr/bin/python3 /root/wp-plus.py'

    green "Create the task of brushing WARP+ traffic successfully! Screen session name is: $screenname"
}

wgcf_account() {
    yellow "Please select the WARP account type you want to switch"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP Free Account ${YELLOW}(Default)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP+"
    echo -e " ${GREEN}3.${PLAIN} WARP Teams"
    echo ""
    read -p "Please enter options [1-3]: " account_type
    if [[ $account_type == 2 ]]; then
        # Close WGCF
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1
       
        # Enter the /etc/wireguard directory for subsequent operations
        cd /etc/wireguard

        #Ask the user to obtain the WARP account license key and apply it to the WARP account configuration file
        yellow "How to obtain CloudFlare WARP account key information: "
        green "PC: Download and install CloudFlare WARP → Settings → Preferences → Accounts → Copy the key into the script"
        green "Mobile phone: Download and install 1.1.1.1 APP → Menu → Account → Copy the key into the script"
        echo ""
        yellow "Important: Please ensure that the account status of the 1.1.1.1 APP on your mobile phone or computer is WARP+!"
        read -rp "Enter WARP account license key (26 characters): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{ 8}$ ]]; do
            red "WARP account license key format input error, please re-enter!"
            read -rp "Enter WARP account license key (26 characters): " warpkey
        done
        sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml

        # Delete the original WireGuard configuration file
        rm -rf /etc/wireguard/wgcf-profile.conf

        #Ask the user whether to use a custom device name. If not, use the six-digit device name randomly generated by WGCF.
        read -rp "Please enter a custom device name. If not entered, the default random device name will be used: " device_name
        if [[ -n $device_name ]]; then
            wgcf update --name $(echo $device_name | sed s/[[:space:]]/_/g) >/etc/wireguard/info.log 2>&1
        else
            wgcf update >/etc/wireguard/info.log 2>&1
        fi

        # Generate new WireGuard configuration file
        wgcf generate

# Obtain the private key and IPv6 intranet address to replace the corresponding content in the wgcf.conf file
        private_v6=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf
        sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf.conf

        # Start WGCF and check whether WGCF starts successfully
        check_wgcf
    elif [[ $account_type == 3 ]]; then
        # Close WGCF
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1

        yellow "Please choose how to apply for a WARP Teams account"
        echo ""
        echo -e " ${GREEN}1.${PLAIN} using Teams TOKEN ${YELLOW}(default)${PLAIN}"
        echo -e "${GREEN}2.${PLAIN} use the extracted xml configuration file"
        echo ""
        read -p "Please enter options [1-2]: " team_type

        if [[ $team_type == 2 ]]; then
            #Ask the user to obtain the WARP Teams account xml file configuration link, and prompt the acquisition method and upload method
            yellow "How to obtain the WARP Teams account xml configuration file: https://blog.misaka.rest/2023/02/11/wgcfteam-config/"
            yellow "Please upload the extracted xml configuration file to: https://gist.github.com"
            read -rp "Please paste the WARP Teams account configuration file link:" teamconfigurl
            if [[ -n $teamconfigurl ]]; then
                # Filter some characters so that the script can identify the content
                teams_config=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")

                # Obtain the private key and IPv6 intranet address to replace the corresponding content in the wgcf.conf and wgcf-profile.conf files
                private_key=$(expr "$teams_config" : '.*private_key&quot;>\([^<]*\).*')
                private_v6=$(expr "$teams_config" : '.*v6&quot;:&quot;\([^[&]*\).*')
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf
                sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf.conf
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf
                sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf-profile.conf

                # Start WGCF and check whether WGCF starts successfully
                check_wgcf
            else
                red "No WARP Teams account profile link provided, script exited!"
                exit 1
            fi
       else
#Ask the user for WARP Teams account TOKEN and prompt how to obtain it
            yellow "Please get your WARP Teams account TOKEN from this website: https://web--public--warp-team-api--coia-mfs4.code.run/"
            read -rp "Please enter the TOKEN of your WARP Teams account:" teams_token

            if [[ -n $teams_token ]]; then
                # Generate WireGuard public and private keys, WARP device ID and FCM Token
                private_key=$(wg genkey)
                public_key=$(wg pubkey <<< "$private_key")
                install_id=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 22)
                fcm_token="${install_id}:APA91b$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 134)"

                # Use CloudFlare API to request Teams configuration information
                team_result=$(curl --silent --location --tlsv1.3 --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
                    --header 'User-Agent: okhttp/3.12.1' \
                    --header 'CF-Client-Version: a-6.10-2158' \
                    --header 'Content-Type: application/json' \
                    --header "Cf-Access-Jwt-Assertion: ${teams_token}" \
                    --data '{"key":"'${public_key}'","install_id":"'${install_id}'","fcm_token":"'${fcm_token}'","tos":"' $(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"Linux","serial_number":"'${install_id}'", "locale":"zh_CN"}')

                # Extract the WARP IPv6 intranet address to replace the corresponding content in the wgcf.conf and wgcf-profile.conf files
                private_v6=$(expr "$team_result" : '.*"v6":[ ]*"\([^"]*\).*')
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf
                sed -i "s#Address.*128#Address = $private_v6/128#g" /etc/wireguard/wgcf.conf
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf
                sed -i "s#Address.*128#Address = $private_v6/128#g" /etc/wireguard/wgcf-profile.conf

                # Start WGCF and check whether WGCF starts successfully
                check_wgcf
            else
                red "The WARP Teams account TOKEN was not entered, the script exited!"
                exit 1
            fi
        fi
    else
        # Close WGCF
        wg-quick down wgcf 2>/dev/null
        systemctl stop wg-quick@wgcf >/dev/null 2>&1
        systemctl disable wg-quick@wgcf >/dev/null 2>&1

        # Delete the original account and WireGuard configuration file
        rm -f /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf-profile.conf

        # Register an account with WGCF
        register_wgcf

        # Move new account and WireGuard configuration files
        mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
        mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

        # Obtain the private key and IPv6 intranet address to replace the corresponding content in the wgcf.conf file
        private_v6=$(cat /etc/wireguard/wgcf-profile.conf | sed -n 4p | sed "s/Address = //g")
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf.conf
        sed -i "s#Address.*128#Address = $private_v6#g" /etc/wireguard/wgcf.conf

        # Start WGCF and check whether WGCF starts successfully
        check_wgcf
    fi
}

wpgo_account() {
    # Check the IP form of the VPS (if WARP is turned on, turn it off and turn it back on after the detection is completed)
    check_warp
    if [[ $warp_v4 =~ on|plus ]] || [[ $warp_v6 =~ on|plus ]]; then
        systemctl stop warp-go
        check_stack
        systemctl start warp-go
    else
        check_stack
    fi

    # Get and set the IP outbound and allowed external IP information of the current WARP-GO file, for backup
    current_allowips=$(cat /opt/warp-go/warp.conf | grep AllowedIPs)
    [[ -n $lan4 && -n $out4 && -z $lan6 && -z $out6 ]] && current_postip=$wgo4
    [[ -z $lan4 && -z $out4 && -n $lan6 && -n $out6 ]] && current_postip=$wgo5
    [[ -n $lan4 && -n $out4 && -n $lan6 && -n $out6 ]] && current_postip=$wgo6
    [[ -n $lan4 && -z $out4 && -n $lan6 && -n $out6 ]] && current_postip=$wgo6

    yellow "Please select the WARP account type you want to switch"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WARP Free Account ${YELLOW}(Default)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP+"
    echo -e " ${GREEN}3.${PLAIN} WARP Teams"
    echo ""
    read -p "Please enter options [1-3]: " account_type

    if [[ $account_type == 2 ]]; then
        # Close WARP-GO
        systemctl stop warp-go

        # Ask the user to obtain the WARP account license key
        yellow "How to obtain CloudFlare WARP account key information: "
        green "PC: Download and install CloudFlare WARP → Settings → Preferences → Accounts → Copy the key into the script"
        green "Mobile phone: Download and install 1.1.1.1 APP → Menu → Account → Copy the key into the script"
        echo ""
        yellow "Important: Please ensure that the account status of the 1.1.1.1 APP on your mobile phone or computer is WARP+!"
        read -rp "Enter WARP account license key (26 characters): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{ 8}$ ]]; do
            red "WARP account license key format input error, please re-enter!"
            read -rp "Enter WARP account license key (26 characters): " warpkey
        done

#Ask the user whether to use a custom device name. If not, use the six-digit device name randomly generated by WARP-GO.
        read -rp "Please enter a custom device name. If not entered, the default random device name will be used: " device_name
        [[ -z $device_name ]] && device_name=$(date +%s%N | md5sum | cut -c 1-6)

        # Use the WARP+ account key to upgrade the original configuration file
        result=$(/opt/warp-go/warp-go --update --config=/opt/warp-go/warp.conf --license=$warpkey --device-name=$devicename)

        # Determine whether the upgrade is successful, and if it fails, restore the WARP free version account
        if [[ $result == "Success" ]]; then
            # Apply WARP-GO configuration
            sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
            echo $current_postip | sh

            # Check optimal MTU value and apply to WARP-GO profile
            check_mtu
            sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

            # Prefer EndPoint IP and apply to WARP-GO configuration file
            check_endpoint
            sed -i "/Endpoint/s/.*/Endpoint = "$best_endpoint"/" /opt/warp-go/warp.conf

            # Start WARP-GO and check whether WARP-GO is running normally
            check_wpgo
        else
            red "WARP+ account registration failed! Reverting to WARP free account"

            # Close WARP-GO
            systemctl stop warp-go

            # Delete the original configuration file and register again
            rm -f /opt/warp-go/warp.conf

            # Use WARP API to register a free WARP account
            register_wpgo

            # Apply WARP-GO configuration
            sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
            echo $current_postip | sh

            # Check optimal MTU value and apply to WARP-GO profile
            check_mtu
            sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

            # Prefer EndPoint IP and apply to WARP-GO configuration file
            check_endpoint
            sed -i "/Endpoint/s/.*/Endpoint = "$best_endpoint"/" /opt/warp-go/warp.conf

            # Start WARP-GO and check whether WARP-GO is running normally
            check_wpgo
        fi
    elif [[ $account_type == 3 ]]; then
        # Close WARP-GO
        systemctl stop warp-go

        #Ask the user for WARP Teams account TOKEN and prompt how to obtain it
        yellow "Please get your WARP Teams account TOKEN from this website: https://web--public--warp-team-api--coia-mfs4.code.run/"
        read -rp "Please enter the TOKEN of your WARP Teams account:" teams_token

if [[ -n $teams_token ]]; then
            #Ask the user whether to use a custom device name. If not, use the six-digit device name randomly generated by WARP-GO.
            read -rp "Please enter a custom device name. If not entered, the default random device name will be used: " device_name
            [[ -z $device_name ]] && device_name=$(date +%s%N | md5sum | cut -c 1-6)

            # Use Teams TOKEN to upgrade the configuration file
            /opt/warp-go/warp-go --update --config=/opt/warp-go/warp.conf --team-config=$teams_token --device-name=$device_name
            sed -i "s/Type =.*/Type = team/g" /opt/warp-go/warp.conf

            # Apply WARP-GO configuration
            sed -i "s#.*AllowedIPs.*#$current_allowips#g" /opt/warp-go/warp.conf
            echo $current_postip | sh

            # Check optimal MTU value and apply to WARP-GO profile
            check_mtu
            sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

            # Prefer EndPoint IP and apply to WARP-GO configuration file
            check_endpoint
            sed -i "/Endpoint/s/.*/Endpoint = "$best_endpoint"/" /opt/warp-go/warp.conf

            # Start WARP-GO and check whether WARP-GO is running normally
            check_wpgo
        else
            red "The WARP Teams account TOKEN was not entered, the script exited!"
            exit 1
        fi
    else
        # Close WARP-GO
        systemctl stop warp-go

        # Delete the original configuration file and register again
        rm -f /opt/warp-go/warp.conf

        # Use WARP API to register a free WARP account
        register_wpgo

        # Apply WARP-GO configuration
        sed -i "s#.*AllowedIPs.*#${current_allowips}#g" /opt/warp-go/warp.conf
        echo $current_postip | sh

        # Check optimal MTU value and apply to WARP-GO profile
        check_mtu
        sed -i "s/MTU.*/MTU = $MTU/g" /opt/warp-go/warp.conf

        # Prefer EndPoint IP and apply to WARP-GO configuration file
        check_endpoint
        sed -i "/Endpoint/s/.*/Endpoint = "$best_endpoint"/" /opt/warp-go/warp.conf

        # Start WARP-GO and check whether WARP-GO is running normally
        check_wpgo
    fi
}

warp_cli_account() {
    # Close WARP-Cli
    warp-cli --accept-tos disconnect >/dev/null 2>&1
    warp-cli --accept-tos register >/dev/null 2>&1

    # Ask the user to obtain the WARP account license key
    yellow "How to obtain CloudFlare WARP account key information: "
    green "PC: Download and install CloudFlare WARP → Settings → Preferences → Accounts → Copy the key into the script"
    green "Mobile phone: Download and install 1.1.1.1 APP → Menu → Account → Copy the key into the script"
    echo ""
    yellow "Important: Please ensure that the account status of the 1.1.1.1 APP on your mobile phone or computer is WARP+!"
    read -rp "Enter WARP account license key (26 characters): " warpkey
    until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{ 8}$ ]]; do
        red "WARP account license key format input error, please re-enter!"
        read -rp "Enter WARP account license key (26 characters): " warpkey
    done

    # Set WARP account license key and connect
    warp-cli --accept-tos set-license "$warpkey" >/dev/null 2>&1 && sleep 1
    warp-cli --accept-tos connect >/dev/null 2>&1

    # Check whether the account has been upgraded successfully. If not, it will prompt you to use a free account.
    if [[ $(warp-cli --accept-tos account) =~ Limited ]]; then
        green "WARP-Cli account type switched to WARP+ successfully!"
    else
        red "WARP+ account activation failed and has been automatically downgraded to WARP free version account"
    fi
}

wireproxy_account() {
yellow "Please select the WARP account type you want to switch"
     echo ""
     echo -e " ${GREEN}1.${PLAIN} WARP Free Account ${YELLOW}(Default)${PLAIN}"
     echo -e " ${GREEN}2.${PLAIN} WARP+"
     echo -e " ${GREEN}3.${PLAIN} WARP Teams"
     echo ""
     read -p "Please enter options [1-3]: " account_type
     if [[ $account_type == 2 ]]; then
        # Close WireProxy
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp

        # Enter the /etc/wireguard directory for subsequent operations
        cd /etc/wireguard
        #Ask the user to obtain the WARP account license key and apply it to the WARP account configuration file
        yellow "How to obtain CloudFlare WARP account key information: "
        green "PC: Download and install CloudFlare WARP → Settings → Preferences → Accounts → Copy the key into the script"
        green "Mobile phone: Download and install 1.1.1.1 APP → Menu → Account → Copy the key into the script"
        echo ""
        yellow "Important: Please ensure that the account status of the 1.1.1.1 APP on your mobile phone or computer is WARP+!"
        read -rp "Enter WARP account license key (26 characters): " warpkey
        until [[ -z $warpkey || $warpkey =~ ^[A-Z0-9a-z]{8}-[A-Z0-9a-z]{8}-[A-Z0-9a-z]{ 8}$ ]]; do
            red "WARP account license key format input error, please re-enter!"
            read -rp "Enter WARP account license key (26 characters): " warpkey
        done
        sed -i "s/license_key.*/license_key = \"$warpkey\"/g" wgcf-account.toml

        # Delete the original WireGuard configuration file
        rm -rf /etc/wireguard/wgcf-profile.conf

        #Ask the user whether to use a custom device name. If not, use the six-digit device name randomly generated by WGCF.
        read -rp "Please enter a custom device name. If not entered, the default random device name will be used: " device_name
        if [[ -n $device_name ]]; then
            wgcf update --name $(echo $device_name | sed s/[[:space:]]/_/g) >/etc/wireguard/info.log 2>&1
        else
            wgcf update >/etc/wireguard/info.log 2>&1
        fi

        # Generate new WireGuard configuration file
        wgcf generate

        # Obtain the private key and IPv6 intranet address to replace the corresponding content in the proxy.conf file
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf

        # Start WireProxy and check if it is running normally
        check_wireproxy
    elif [[ $account_type == 3 ]]; then
        # Close WireProxy
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
        # Enter the /etc/wireguard directory for subsequent operations
        cd /etc/wireguard

        yellow "Please choose how to apply for a WARP Teams account"
        echo ""
        echo -e " ${GREEN}1.${PLAIN} using Teams TOKEN ${YELLOW}(default)${PLAIN}"
        echo -e "${GREEN}2.${PLAIN} use the extracted xml configuration file"
        echo ""
        read -p "Please enter options [1-2]: " team_type

        if [[ $team_type == 2 ]]; then
            #Ask the user to obtain the WARP Teams account xml file configuration link, and prompt the acquisition method and upload method
            yellow "How to obtain the WARP Teams account xml configuration file: https://blog.misaka.rest/2023/02/11/wgcfteam-config/"
            yellow "Please upload the extracted xml configuration file to: https://gist.github.com"
            read -rp "Please paste the WARP Teams account configuration file link:" teamconfigurl
            if [[ -n $teamconfigurl ]]; then
                # Filter some characters so that the script can identify the content
                teams_config=$(curl -sSL "$teamconfigurl" | sed "s/\"/\&quot;/g")

                # Obtain the private key and IPv6 intranet address to replace the corresponding content in the wgcf.conf and wgcf-profile.conf files
                private_key=$(expr "$teams_config" : '.*private_key&quot;>\([^<]*\).*')
                private_v6=$(expr "$teams_config" : '.*v6&quot;:&quot;\([^[&]*\).*')
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf
                sed -i "s#Address.*128#Address = $private_v6/128#g" /etc/wireguard/wgcf-profile.conf

                # Start WireProxy and check if it is running normally
                check_wireproxy
            else
                red "No WARP Teams account profile link provided, script exited!"
            fi
        else
            #Ask the user for WARP Teams account TOKEN and prompt how to obtain it
            yellow "Please get your WARP Teams account TOKEN from this website: https://web--public--warp-team-api--coia-mfs4.code.run/"
            read -rp "Please enter the TOKEN of your WARP Teams account:" teams_token

            if [[ -n $teams_token ]]; then
                # Generate WireGuard public and private keys, WARP device ID and FCM Token
                private_key=$(wg genkey)
                public_key=$(wg pubkey <<< "$private_key")
                install_id=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 22)
                fcm_token="${install_id}:APA91b$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 134)"

                # Use CloudFlare API to request Teams configuration information
                team_result=$(curl --silent --location --tlsv1.3 --request POST 'https://api.cloudflareclient.com/v0a2158/reg' \
                    --header 'User-Agent: okhttp/3.12.1' \
                    --header 'CF-Client-Version: a-6.10-2158' \
                    --header 'Content-Type: application/json' \
                    --header "Cf-Access-Jwt-Assertion: ${teams_token}" \
                    --data '{"key":"'${public_key}'","install_id":"'${install_id}'","fcm_token":"'${fcm_token}'","tos":"' $(date +"%Y-%m-%dT%H:%M:%S.%3NZ")'","model":"Linux","serial_number":"'${install_id}'", "locale":"zh_CN"}')

                # Extract the WARP IPv6 intranet address to replace the corresponding content in the wgcf.conf and wgcf-profile.conf files
                private_v6=$(expr "$team_result" : '.*"v6":[ ]*"\([^"]*\).*')
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf
                sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/wgcf-profile.conf
                sed -i "s#Address.*128#Address = $private_v6/128#g" /etc/wireguard/wgcf-profile.conf
                # Start WireProxy and check if it is running normally
                check_wireproxy
            else
                red "The WARP Teams account TOKEN was not entered, the script exited!"
                exit 1
            fi
        fi
    else
        # Close WireProxy
        systemctl stop wireproxy-warp
        systemctl disable wireproxy-warp
        # Delete the original account and WireGuard configuration file
        rm -f /etc/wireguard/wgcf-account.toml /etc/wireguard/wgcf-profile.conf

        # Register an account with WGCF
        register_wgcf

        # Move new account and WireGuard configuration files
        mv -f wgcf-profile.conf /etc/wireguard/wgcf-profile.conf
        mv -f wgcf-account.toml /etc/wireguard/wgcf-account.toml

        # Get the private key to replace the corresponding content in the proxy.conf file
        private_key=$(grep PrivateKey /etc/wireguard/wgcf-profile.conf | sed "s/PrivateKey = //g")
        sed -i "s#PrivateKey.*#PrivateKey = $private_key#g" /etc/wireguard/proxy.conf

        # Start WireProxy and check if it is running normally
        check_wireproxy
    fi
}

warp_account() {
    yellow "Please select the WARP client that needs to switch accounts"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} WGCF ${YELLOW}(default)${PLAIN}"
    echo -e " ${GREEN}2.${PLAIN} WARP-GO"
    echo -e " ${GREEN}3.${PLAIN} WARP-Cli ${RED}(only supports upgrade to WARP+)${PLAIN}"
    echo -e " ${GREEN}4.${PLAIN} WireProxy"
    echo ""
    read -p "Please enter options [1-4]: " account_mode
    if [[ $account_mode == 2 ]]; then
        wpgo_account
    elif [[ $account_mode == 3 ]]; then
        warp_cli_account
    elif [[ $account_mode == 4 ]]; then
        wireproxy_account
    else
        wgcf_account
    fi
}

before_showinfo() {
    yellow "Please wait, VPS, WARP and unlocking status are being detected..."

    # Get outbound IPv4/IPv6 address, provider
    check_ip
    country4=$(curl -s4m8 ip.p3terx.com | sed -n 2p | awk -F "/ " '{print $2}')
    country6=$(curl -s6m8 ip.p3terx.com | sed -n 2p | awk -F "/ " '{print $2}')
    provider4=$(curl -s4m8 ip.p3terx.com | sed -n 3p | awk -F "/ " '{print $2}')
    provider6=$(curl -s6m8 ip.p3terx.com | sed -n 3p | awk -F "/ " '{print $2}')

    # Get outbound WARP account status
    check_warp

    # Initialize IPv4/IPv6 device name, default is not set
    device4="${RED} is not set ${PLAIN}"
    device6="${RED} is not set ${PLAIN}"

    # Get the socks5 port of WARP-Cli and WireProxy
    cli_port=$(warp-cli --accept-tos settings 2>/dev/null | grep 'WarpProxy on port' | awk -F "port " '{print $2}')
    wireproxy_port=$(grep BindAddress /etc/wireguard/proxy.conf 2>/dev/null | sed "s/BindAddress = 127.0.0.1://g")

    # If the socks5 port of WARP-Cli and WireProxy is obtained, obtain its IP address, provider, and WARP status information
    if [[ -n $cli_port ]]; then
        account_cli=$(curl -sx socks5h://localhost:$cli_port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        country_cli=$(curl -sx socks5h://localhost:$cli_port ip.p3terx.com -k --connect-timeout 8 | sed -n 2p | awk -F "/ " '{print $2}')
        ip_cli=$(curl -sx socks5h://localhost:$cli_port ip.p3terx.com -k --connect-timeout 8 | sed -n 1p)
        provider_cli=$(curl -sx socks5h://localhost:$cli_port ip.p3terx.com -k --connect-timeout 8 | sed -n 3p | awk -F "/ " '{print $2}')
    fi
    if [[ -n $wireproxy_port ]]; then
        account_wireproxy=$(curl -sx socks5h://localhost:$wireproxy_port https://www.cloudflare.com/cdn-cgi/trace -k --connect-timeout 8 | grep warp | cut -d= -f2)
        country_wireproxy=$(curl -sx socks5h://localhost:$wireproxy_port ip.p3terx.com -k --connect-timeout 8 | sed -n 2p | awk -F "/ " '{print $2}')
        ip_wireproxy=$(curl -sx socks5h://localhost:$wireproxy_port ip.p3terx.com -k --connect-timeout 8 | sed -n 1p)
        provider_wireproxy=$(curl -sx socks5h://localhost:$wireproxy_port ip.p3terx.com -k --connect-timeout 8 | sed -n 3p | awk -F "/ " '{print $2}')
    fi

    # Get the WARP account status, device name and remaining traffic, and return to the user echo
    if [[ $warp_v4 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d4=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            quota4="${GREEN} $QUOTA ${PLAIN}"
            account4="${GREEN}WARP+${PLAIN}"
        elif [[ $(grep -s "Type" /opt/warp-go/warp.conf | cut -d= -f2 | sed "s# ##g") == "plus" ]]; then
            check_quota
            quota4="${GREEN} $QUOTA ${PLAIN}"
            account4="${GREEN}WARP+${PLAIN}"
        else
            quota4="${RED}Unlimited${PLAIN}"
            account4="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $warp_v4 == "on" ]]; then
        quota4="${RED}Unlimited${PLAIN}"
        account4="${YELLOW}WARP Free Account${PLAIN}"
    else
        quota4="${RED}Unlimited${PLAIN}"
        account4="${RED} is not enabled for WARP${PLAIN}"
    fi

if [[ $warp_v6 == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            d6=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            quota6="${GREEN} $QUOTA ${PLAIN}"
            account6="${GREEN}WARP+${PLAIN}"
        elif [[ $(grep -s "Type" /opt/warp-go/warp.conf | cut -d= -f2 | sed "s# ##g") == "plus" ]]; then
            check_quota
            quota6="${GREEN} $QUOTA ${PLAIN}"
            account6="${GREEN}WARP+${PLAIN}"
        else
            quota6="${RED}Unlimited${PLAIN}"
            account6="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $warp_v6 == "on" ]]; then
        quota6="${RED}Unlimited${PLAIN}"
        account6="${YELLOW}WARP Free Account${PLAIN}"
    else
        quota6="${RED}Unlimited${PLAIN}"
        account6="${RED} is not enabled for WARP${PLAIN}"
    fi

    if [[ $account_cli == "plus" ]]; then
        CHECK_TYPE=1
        check_quota
        quota_cli="${GREEN} $QUOTA ${PLAIN}"
        account_cli="${GREEN}WARP+${PLAIN}"
    elif [[ $account_cli == "on" ]]; then
        quota_cli="${RED}Unlimited${PLAIN}"
        account_cli="${YELLOW}WARP Free Account${PLAIN}"
    else
        quota_cli="${RED}Unlimited${PLAIN}"
        account_cli="${RED} is not started ${PLAIN}"
    fi

    if [[ $account_wireproxy == "plus" ]]; then
        if [[ -n $(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }') ]]; then
            device_wireproxy=$(grep -s 'Device name' /etc/wireguard/info.log | awk '{ print $NF }')
            check_quota
            quota_wireproxy="${GREEN} $QUOTA ${PLAIN}"
            account_wireproxy="${GREEN}WARP+${PLAIN}"
        else
            quota_wireproxy="${RED}Unlimited${PLAIN}"
            account_wireproxy="${GREEN}WARP Teams${PLAIN}"
        fi
    elif [[ $account_wireproxy == "on" ]]; then
        quota_wireproxy="${RED}Unlimited${PLAIN}"
        account_wireproxy="${YELLOW}WARP FREE ACCOUNT${PLAIN}"
    else
        quota_wireproxy="${RED}Unlimited${PLAIN}"
        account_wireproxy="${RED} is not started${PLAIN}"
    fi

    # Check whether the Netflix detection script is installed locally. If it is not installed, download and install the detection script. Thanks: https://github.com/sjlleo/netflix-verify
    if [[ ! -f /usr/local/bin/nf ]]; then
        wget https://gitlab.com/Misaka-blog/warp-script/-/raw/main/files/netflix-verify/nf-linux-$(archAffix) -O /usr/local/bin/nf >/dev /null 2>&1
        chmod +x /usr/local/bin/nf
    fi
    # Test Netflix unblocking
    netflix4=$(nf | sed -n 3p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m |K]//g")
    netflix6=$(nf | sed -n 7p | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m |K]//g") && [[ -n $(echo $netflix6 | grep "IP region information recognized by NF") ]] && netflix6=$(nf | sed -n 6p | sed -r "s/ \x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g")
    [[ -n $cli_port ]] && netflix_cli=$(nf -proxy socks5://127.0.0.1:$cli_port | sed -n 3p | sed -r "s/\x1B\[([0-9]{1 ,2}(;[0-9]{1,2})?)?[m|K]//g")
    [[ -n $wireproxy_port ]] && netflix_wireproxy=$(nf -proxy socks5://127.0.0.1:$wireproxy_port | sed -n 3p | sed -r "s/\x1B\[([0-9]{1 ,2}(;[0-9]{1,2})?)?[m|K]//g")

    # Simplify the Netflix detection script output results to facilitate the layout of the output results
    [[ $netflix4 == "Your export IP fully unlocks Netflix and supports the viewing of non-homemade dramas" ]] && netflix4="${GREEN} has unlocked Netflix${PLAIN}"
    [[ $netflix6 == "Your export IP fully unlocks Netflix and supports the viewing of non-homemade dramas" ]] && netflix6="${GREEN} has unlocked Netflix${PLAIN}"
    [[ $netflix4 == "Your export IP can use Netflix, but can only watch Netflix's homemade dramas" ]] && netflix4="${YELLOW}NETFLIX's homemade dramas${PLAIN}"
    [[ $netflix6 == "Your export IP can use Netflix, but can only watch Netflix's homemade dramas" ]] && netflix6="${YELLOW}NETFLIX's homemade dramas${PLAIN}"
    [[ -z $netflix4 ]] || [[ $netflix4 == "Your network may not be properly configured for IPv4, or there may be no IPv4 network access" ]] && netflix4="${RED} cannot detect Netflix status ${PLAIN }"
    [[ -z $netflix6 ]] || [[ $netflix6 == "Your network may not be properly configured for IPv6, or there may be no IPv6 network access" ]] && netflix6="${RED} cannot detect Netflix status ${PLAIN }"
    [[ $netflix4 =~ "NETFLIX does not provide services in the country where your export IP is located"|"NETFLIX provides services in the country where your export IP is located, but your IP is suspected of being a proxy and the service cannot be used normally" ]] && netflix4 ="${RED}cannot unblock Netflix${PLAIN}"
    [[ $netflix6 =~ "NETFLIX does not provide services in the country where your export IP is located"|"NETFLIX provides services in the country where your export IP is located, but your IP is suspected of being a proxy and the service cannot be used normally" ]] && netflix6 ="${RED}cannot unblock Netflix${PLAIN}"
    [[ $netflix_cli == "Your export IP fully unlocks Netflix and supports the viewing of non-homemade dramas" ]] && netflix_cli="${GREEN} has unlocked Netflix${PLAIN}"
    [[ $netflix_wireproxy == "Your export IP fully unlocks Netflix and supports the viewing of non-homemade dramas" ]] && netflix_wireproxy="${GREEN} has unlocked Netflix${PLAIN}"
    [[ $netflix_cli == "Your export IP can use Netflix, but you can only watch Netflix's homemade dramas" ]] && netflix_cli="${YELLOW}NETFLIX's homemade dramas${PLAIN}"
    [[ $netflix_wireproxy == "Your export IP can use Netflix, but you can only watch Netflix's homemade dramas" ]] && netflix_wireproxy="${YELLOW}NETFLIX's homemade dramas${PLAIN}"
    [[ $netflix_cli =~ "NETFLIX does not provide services in the country where your export IP is located"|"NETFLIX provides services in the country where your export IP is located, but your IP is suspected of being a proxy and the service cannot be used normally" ]] && netflix_cli ="${RED}cannot unblock Netflix${PLAIN}"
    [[ $netflix_wireproxy =~ "NETFLIX does not provide services in the country where your export IP is located"|"NETFLIX provides services in the country where your export IP is located, but your IP is suspected of being a proxy and the service cannot be used normally" ]] && netflix_wireproxy ="${RED}cannot unblock Netflix${PLAIN}"
    # Test ChatGPT unlocking situation
    curl -s4m8 https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt4="${RED} cannot access ChatGPT${PLAIN}" || chatgpt4="${GREEN} Support access to ChatGPT${PLAIN}"
    curl -s6m8 https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt6="${RED} cannot access ChatGPT${PLAIN}" || chatgpt6="${GREEN} Support access to ChatGPT${PLAIN}"
    if [[ -n $cli_port ]]; then
        curl -sx socks5h://localhost:$cli_port https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt_cli="${RED} cannot access ChatGPT${PLAIN}" | | chatgpt_cli="${GREEN} supports access to ChatGPT${PLAIN}"
    fi
    if [[ -n $wireproxy_port ]]; then
        curl -sx socks5h://localhost:$wireproxy_port https://chat.openai.com/ | grep -qw "Sorry, you have been blocked" && chatgpt_wireproxy="${RED} cannot access ChatGPT${PLAIN}" | | chatgpt_wireproxy="${GREEN} supports access to ChatGPT${PLAIN}"
    fi
}

show_info() {
    echo "------------------------------------------------ ----------------------------"
    if [[ -n $ipv4 ]]; then
        echo -e "IPv4 address: $ipv4 region: $country4 device name: $device4"
        echo -e "Provider: $provider4 WARP account status: $account4 Remaining traffic: $quota4"
        echo -e "Netflix status: $netflix4 ChatGPT status: $chatgpt4"
    else
        echo -e "IPv4 outbound status: ${RED} is not enabled ${PLAIN}"
    fi
    echo "------------------------------------------------ ----------------------------"
    if [[ -n $ipv6 ]]; then
        echo -e "IPv6 address: $ipv6 region: $country6 device name: $device6"
        echo -e "Provider: $provider6 WARP account status: $account6 Remaining traffic: $quota6"
        echo -e "Netflix status: $netflix6 ChatGPT status: $chatgpt6"
    else
        echo -e "IPv6 outbound status: ${RED} is not enabled ${PLAIN}"
    fi
    echo "------------------------------------------------ ----------------------------"
    if [[ -n $cli_port ]]; then
        echo -e "WARP-Cli proxy port: 127.0.0.1:$cli_port status: $account_cli remaining traffic: $quota_cli"
        if [[ -n $ip_cli ]]; then
            echo -e "IP: $ip_cli Region: $country_cli Provider: $provider_cli"
            echo -e "Netflix status: $netflix_cli ChatGPT status: $chatgpt_cli"
        fi
    else
        echo -e "WARP-Cli outbound status: ${RED} is not installed ${PLAIN}"
    fi
    echo "------------------------------------------------ ----------------------------"
    if [[ -n $wireproxy_port ]]; then
        echo -e "WireProxy-WARP proxy port: 127.0.0.1:$wireproxy_port status: $account_wireproxy remaining traffic: $quota_wireproxy"
        if [[ -n $ip_wireproxy ]]; then
            echo -e "IP: $ip_wireproxy Region: $country_wireproxy Provider: $provider_wireproxy"
            echo -e "Netflix status: $netflix_wireproxy ChatGPT status: $chatgpt_wireproxy"
        fi
    else
        echo -e "WireProxy outbound status: ${RED} is not installed ${PLAIN}"
    fi
    echo "------------------------------------------------ ----------------------------"
}

menu() {
    clear
    echo "############################################## #############"
    echo -e "# ${RED}CloudFlare WARP one-click management script ${PLAIN} #"
    echo -e "# ${GREEN}Author${PLAIN}: MisakaNo の小波站#"
    echo -e "# ${GREEN}blog${PLAIN}: https://blog.misaka.rest #"
    echo -e "# ${GREEN}GitHub project${PLAIN}: https://github.com/Misaka-blog #"
    echo -e "# ${GREEN}GitLab project${PLAIN}: https://gitlab.com/Misaka-blog #"
    echo -e "# ${GREEN}Telegram channel ${PLAIN}: https://t.me/misakanocchannel #"
    echo -e "# ${GREEN}Telegram group ${PLAIN}: https://t.me/misakanoc #"
    echo -e "# ${GREEN}YouTube Channel${PLAIN}: https://www.youtube.com/@misaka-blog #"
    echo "############################################## #############"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} install/switch WGCF-WARP | ${GREEN}3.${PLAIN} install/switch WARP-GO"
    echo -e " ${GREEN}2.${PLAIN} ${RED}Uninstall WGCF-WARP${PLAIN} | ${GREEN}4.${PLAIN} ${RED}Uninstall WARP-GO${PLAIN}"
    echo "------------------------------------------------ -------------"
    echo -e " ${GREEN}5.${PLAIN} install WARP-Cli | ${GREEN}7.${PLAIN} install WireProxy-WARP"
    echo -e " ${GREEN}6.${PLAIN} ${RED}Uninstall WARP-Cli${PLAIN} | ${GREEN}8.${PLAIN} ${RED}Uninstall WireProxy-WARP${PLAIN}"
    echo "------------------------------------------------ -------------"
    echo -e " ${GREEN}9.${PLAIN} Modify WARP-Cli / WireProxy port | ${GREEN}10.${PLAIN} Enable, disable or restart WARP"
    echo -e " ${GREEN}11.${PLAIN} Extract WireGuard configuration file | ${GREEN}12.${PLAIN} WARP+ account brush traffic"
    echo -e " ${GREEN}13.${PLAIN} Switch WARP account type | ${GREEN}14.${PLAIN} Pull the latest script from GitLab"
    echo "------------------------------------------------ -------------"
    echo -e "${GREEN}0.${PLAIN} exit script"
    echo ""
    show_info
    echo ""
    read -rp "Please enter options [0-14]: " menu_input
    case $menu_input in
        1) select_wgcf ;;
        2) uninstall_wgcf ;;
        3) select_wpgo ;;
        4) uninstall_wpgo ;;
        5) install_warp_cli ;;
        6) uninstall_warp_cli ;;
        7) install_wireproxy ;;
        8) uninstall_wireproxy ;;
        9) change_warp_port ;;
        10) switch_warp ;;
        11) wireguard_profile ;;
        12) warp_traffic ;;
        13) warp_account ;;
        14) wget -N https://gitlab.com/Misaka-blog/warp-script/-/raw/main/warp.sh && bash warp.sh ;;
        *) exit 1 ;;
    esac
}

before_showinfo && menu