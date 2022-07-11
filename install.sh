#!/bin/bash

rm -rf $0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi：${plain} Tập lệnh này phải được chạy với tư cách người dùng root!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với tác giả kịch bản!${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64-v8a"
else
  arch="64"
  echo -e "${red}Không phát hiện được giản đồ, hãy sử dụng lược đồ mặc định: ${arch}${plain}"
fi

echo "Ngành kiến ​​trúc: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "Phần mềm này không hỗ trợ hệ thống 32-bit (x86), vui lòng sử dụng hệ thống 64-bit (x86_64), nếu phát hiện sai, vui lòng liên hệ với tác giả"
    exit 2
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 hoặc cao hơn!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl unzip tar crontabs socat -y
    else
        apt update -y
        apt install wget curl unzip tar cron socat -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/Aiko.service ]]; then
        return 2
    fi
    temp=$(systemctl status Aiko | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_acme() {
    curl https://get.acme.sh | sh
}

install_Aiko() {
    if [[ -e /usr/local/Aiko/ ]]; then
        rm /usr/local/Aiko/ -rf
    fi

    mkdir /usr/local/Aiko/ -p
	cd /usr/local/Aiko/
    
    if  [ $# == 0 ] ;then
        last_version=$(curl -Ls "https://api.github.com/repos/AikoAiko-Project/Aiko/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}Phát hiện phiên bản Aiko không thành công, có thể vượt quá giới hạn GIthub API, vui lòng thử lại sau hoặc chỉ định cài đặt phiên bản Aiko theo cách thủ công${plain}"
            exit 1
        fi
        echo -e "Phiên bản mới nhất của Aiko đã được phát hiện：${last_version}，Bắt đầu cài đặt"
        wget -N --no-check-certificate -O /usr/local/Aiko/Aiko-linux.zip https://github.com/AikoAiko-Project/Aiko/releases/download/1.0.2/Aiko-linux-${arch}.zip
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống Aiko thất bại, hãy chắc chắn rằng máy chủ của bạn có thể tải về các tập tin Github${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/AikoAiko-Project/Aiko/releases/download/1.0.2/Aiko-linux-${arch}.zip"
        echo -e "Bắt đầu cài đặt Aiko v$1"
        wget -N --no-check-certificate -O /usr/local/Aiko/Aiko-linux.zip ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}Tải xuống Aiko v$1 Thất bại, hãy chắc chắn rằng phiên bản này tồn tại${plain}"
            exit 1
        fi
    fi

    unzip Aiko-linux.zip
    rm Aiko-linux.zip -f
    chmod +x Aiko
    mkdir /etc/Aiko/ -p
    rm /etc/systemd/system/Aiko.service -f
    file="https://raw.githubusercontent.com/AikoAiko-Project/AikoAiko-install/main/Aiko.service"
    wget -N --no-check-certificate -O /etc/systemd/system/Aiko.service ${file}
    #cp -f Aiko.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl stop Aiko
    systemctl enable Aiko
    echo -e "${green}Aiko ${last_version}${plain} Quá trình cài đặt hoàn tất, nó đã được thiết lập để bắt đầu tự động"
    cp geoip.dat /etc/Aiko/
    cp geosite.dat /etc/Aiko/ 

    if [[ ! -f /etc/Aiko/config.yml ]]; then
        cp config.yml /etc/Aiko/
        echo -e ""
        echo -e "Cài đặt mới, vui lòng tham khảo hướng dẫn trước：https://github.com/AikoCute/Aiko，Định cấu hình nội dung cần thiết"
    else
        systemctl start Aiko
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}Aiko khởi động lại thành công${plain}"
        else
            echo -e "${red}Aiko Có thể không khởi động được, vui lòng sử dụng sau Aiko log Kiểm tra thông tin nhật ký, nếu không khởi động được, định dạng cấu hình có thể đã bị thay đổi, vui lòng vào wiki để kiểm tra：https://github.com/herotbty/Aiko-Aiko/wiki${plain}"
        fi
    fi

    if [[ ! -f /etc/Aiko/dns.json ]]; then
        cp dns.json /etc/Aiko/
    fi
    if [[ ! -f /etc/Aiko/route.json ]]; then
        cp route.json /etc/Aiko/
    fi
    if [[ ! -f /etc/Aiko/custom_outbound.json ]]; then
        cp custom_outbound.json /etc/Aiko/
    fi
    curl -o /usr/bin/Aiko -Ls https://raw.githubusercontent.com/AikoCute/AikoAiko-install/master/Aiko.sh
    chmod +x /usr/bin/Aiko
    ln -s /usr/bin/Aiko /usr/bin/Aiko # chữ thường tương thích
    chmod +x /usr/bin/Aiko

    echo -e ""
    echo "  Cách sử dụng tập lệnh quản lý Aiko     " 
    echo "------------------------------------------"
    echo "           Aiko   - Show admin menu      "
    echo "         AikoAiko - Aiko by AikoCute    "
    echo "------------------------------------------"
}

echo -e "${green}bắt đầu cài đặt${plain}"
install_base
install_acme
install_Aiko $1