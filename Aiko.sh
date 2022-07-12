#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Lỗi: ${plain} Tập lệnh này phải được chạy với tư cách người dùng root!\n" && exit 1

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
    echo -e "${red}Phiên bản hệ thống không được phát hiện, vui lòng liên hệ với AikoCute để được fix sớm nhất ${plain}\n" && exit 1
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
        echo -e "${red}Vui lòng sử dụng CentOS 7 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Vui lòng sử dụng Ubuntu 16 trở lên！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Vui lòng sử dụng Debian 8 trở lên！${plain}\n" && exit 1
    fi
fi

confirm() {
    if [[ $# > 1 ]]; then
        echo && read -p "$1 [y or n$2]: " temp
        if [[ x"${temp}" == x"" ]]; then
            temp=$2
        fi
    else
        read -p "$1 [y/n]: " temp
    fi
    if [[ x"${temp}" == x"y" || x"${temp}" == x"Y" ]]; then
        return 0
    else
        return 1
    fi
}

confirm_restart() {
    confirm "Có khởi động lại Aiko không" "y"
    if [[ $? == 0 ]]; then
        restart
    else
        show_menu
    fi
}

before_show_menu() {
    echo && echo -n -e "${yellow}Nhấn enter để quay lại menu chính: ${plain}" && read temp
    show_menu
}

install() {
    bash <(curl -Ls https://raw.githubusercontent.com/Aiko-Project/Aiko-install/master/install.sh)
    if [[ $? == 0 ]]; then
        if [[ $# == 0 ]]; then
            start
        else
            start 0
        fi
    fi
}

update() {
    if [[ $# == 0 ]]; then
        echo && echo -n -e "Nhập phiên bản được chỉ định (phiên bản mới nhất mặc định): " && read version
    else
        version=$2
    fi
#    confirm "Chức năng này sẽ buộc cài đặt lại phiên bản mới nhất và dữ liệu sẽ không bị mất. Bạn có muốn tiếp tục không?" "n"
#    if [[ $? != 0 ]]; then
#        echo -e "${red}Đã hủy${plain}"
#        if [[ $1 != 0 ]]; then
#            before_show_menu
#        fi
#        return 0
#    fi
    bash <(curl -Ls https://raw.githubusercontent.com/Aiko-Project/Aiko-install/master/Aiko.sh) $version
    if [[ $? == 0 ]]; then
        echo -e "${green}Cập nhật hoàn tất, Aiko đã được khởi động lại tự động, vui lòng sử dụng Aiko logs dể xem thành quả${plain}"
        exit
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

config() {
    echo "Aiko sẽ tự động khởi động lại sau khi sửa đổi cấu hình"
    nano /etc/Aiko/aiko.yml
    sleep 2
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko: ${green}đã được chạy${plain}"
            ;;
        1)
            echo -e "Nó được phát hiện rằng bạn không khởi động Aiko hoặc Aiko không tự khởi động lại, hãy kiểm tra nhật ký？[Y/n]" && echo
            read -e -p "(yes or no):" yn
            [[ -z ${yn} ]] && yn="y"
            if [[ ${yn} == [Yy] ]]; then
               show_log
            fi
            ;;
        2)
            echo -e "Trạng thái Aiko: ${red}Chưa cài đặt${plain}"
    esac
}

uninstall() {
    confirm "Bạn có chắc chắn muốn gỡ cài đặt Aiko không?" "n"
    if [[ $? != 0 ]]; then
        if [[ $# == 0 ]]; then
            show_menu
        fi
        return 0
    fi
    systemctl stop Aiko
    systemctl disable Aiko
    rm /etc/systemd/system/Aiko.service -f
    systemctl daemon-reload
    systemctl reset-failed
    rm /etc/Aiko/ -rf
    rm /usr/local/Aiko/ -rf
    rm /usr/bin/Aiko -f

    echo ""
    echo -e "${green}Gỡ cài đặt thành công, Đã gỡ cài đặt toàn bộ ra khỏi hệ thống${plain}"
    echo ""

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

start() {
    check_status
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}Aiko đã chạy rồi, Muốn reset thì chạy lệnh : Aiko restart ${plain}"
    else
        systemctl start Aiko
        sleep 2
        check_status
        if [[ $? == 0 ]]; then
            echo -e "${green} Aiko đã khởi động thành công <AikoCuteHotMe>${plain}"
        else
            echo -e "${red}Aiko có thể không khởi động được, Sài Aiko logs để check lỗi ${plain}"
        fi
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

stop() {
    systemctl stop Aiko
    sleep 2
    check_status
    if [[ $? == 1 ]]; then
        echo -e "${green}Aiko đã Stop thành công < Cute hotme >${plain}"
    else
        echo -e "${red}Aiko không Stop được, có thể do thời gian dừng vượt quá hai giây, vui lòng kiểm tra Logs để xem nguyên nhân ${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

restart() {
    systemctl restart Aiko
    sleep 2
    check_status
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko đã khởi động lại thành công, vui lòng sử dụng Aiko Logs để xem nhật ký đang chạy${plain}"
    else
        echo -e "${red}Aiko có thể không khởi động được, vui lòng sử dụng Aiko Logs để xem thông tin nhật ký sau này${plain}"
    fi
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

status() {
    systemctl status Aiko --no-pager -l
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

enable() {
    systemctl enable Aiko
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko được thiết lập để khởi động thành công${plain}"
    else
        echo -e "${red}Thiết lập Aiko không thể tự động khởi động khi khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

disable() {
    systemctl disable Aiko
    if [[ $? == 0 ]]; then
        echo -e "${green}Aiko đã hủy khởi động tự động khởi động thành công${plain}"
    else
        echo -e "${red}Aiko không thể hủy tự động khởi động khởi động${plain}"
    fi

    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_log() {
    journalctl -u Aiko.service -e --no-pager -f
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

install_bbr() {
    bash <(curl -L -s https://raw.githubusercontent.com/AikoCute/BBR/aiko/tcp.sh)
    #if [[ $? == 0 ]]; then
    #    echo ""
    #    echo -e "${green}Quá trình cài đặt bbr thành công, vui lòng khởi động lại máy chủ${plain}"
    #else
    #    echo ""
    #    echo -e "${red}Không thể tải xuống tập lệnh cài đặt bbr, vui lòng kiểm tra xem máy tính của bạn có thể kết nối với Github không${plain}"
    #fi

    #before_show_menu
}

update_shell() {
    wget -O /usr/bin/Aiko -N --no-check-certificate https://raw.githubusercontent.com/Aiko-Project/Aiko-install/master/Aiko.sh
    if [[ $? != 0 ]]; then
        echo ""
        echo -e "${red}Không tải được script xuống, vui lòng kiểm tra xem máy có thể kết nối với Github không${plain}"
        before_show_menu
    else
        chmod +x /usr/bin/Aiko
        echo -e "${green}Tập lệnh nâng cấp thành công, vui lòng chạy lại tập lệnh${plain}" && exit 0
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

check_enabled() {
    temp=$(systemctl is-enabled Aiko)
    if [[ x"${temp}" == x"enabled" ]]; then
        return 0
    else
        return 1;
    fi
}

check_uninstall() {
    check_status
    if [[ $? != 2 ]]; then
        echo ""
        echo -e "${red}Aiko đã được cài đặt, vui lòng không cài đặt lại${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

check_install() {
    check_status
    if [[ $? == 2 ]]; then
        echo ""
        echo -e "${red}Vui lòng cài đặt Aiko trước${plain}"
        if [[ $# == 0 ]]; then
            before_show_menu
        fi
        return 1
    else
        return 0
    fi
}

show_status() {
    check_status
    case $? in
        0)
            echo -e "Trạng thái Aiko: ${green}đã được chạy${plain}"
            show_enable_status
            ;;
        1)
            echo -e "Trạng thái Aiko: ${yellow}không chạy${plain}"
            show_enable_status
            ;;
        2)
            echo -e "Trạng thái Aiko: ${red}Chưa cài đặt${plain}"
    esac
}

show_enable_status() {
    check_enabled
    if [[ $? == 0 ]]; then
        echo -e "Có tự động bắt đầu không: ${green}Đúng${plain}"
    else
        echo -e "Có tự động bắt đầu không: ${red}Không${plain}"
    fi
}

show_Aiko_version() {
    echo -n "Phiên bản Aiko："
    /usr/local/Aiko/Aiko -version
    echo ""
    if [[ $# == 0 ]]; then
        before_show_menu
    fi
}

show_usage() {
    echo -e ""
    echo "  Cách sử dụng tập lệnh quản lý Aiko     " 
    echo "------------------------------------------"
    echo "           Aiko   - Show admin menu      "
    echo "         AikoAiko - Aiko by AikoCute    "
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}Aiko Các tập lệnh quản lý phụ trợ，${plain}${red}không hoạt động với docker${plain}
--- https://github.com/Aiko-project/Aiko ---
  ${green}0.${plain} Setting Config
————————————————
  ${green}1.${plain} Cài đặt Aiko
  ${green}2.${plain} Cập nhật Aiko
  ${green}3.${plain} Gỡ cài đặt Aiko
————————————————
  ${green}4.${plain} Khởi động Aiko
  ${green}5.${plain} Dừng Aiko
  ${green}6.${plain} Khởi động lại Aiko
  ${green}7.${plain} Xem trạng thái Aiko
  ${green}8.${plain} Xem nhật ký Aiko
————————————————
  ${green}9.${plain} Đặt Aiko để bắt đầu tự động
 ${green}10.${plain} Hủy tự động khởi động Aiko
————————————————
 ${green}11.${plain} Một cú nhấp chuột cài đặt bbr (hạt nhân mới nhất)
 ${green}12.${plain} Xem các phiên bản Aiko 
 ${green}13.${plain} Nâng cấp Tập lệnh Bảo trì
 "
 # Cập nhật tiếp theo có thể được thêm vào chuỗi trên
    show_status
    echo && read -p "Vui lòng nhập một lựa chọn [0-13]: " num

    case "${num}" in
        0) config
        ;;
        1) check_uninstall && install
        ;;
        2) check_install && update
        ;;
        3) check_install && uninstall
        ;;
        4) check_install && start
        ;;
        5) check_install && stop
        ;;
        6) check_install && restart
        ;;
        7) check_install && status
        ;;
        8) check_install && show_log
        ;;
        9) check_install && enable
        ;;
        10) check_install && disable
        ;;
        11) install_bbr
        ;;
        12) check_install && show_Aiko_version
        ;;
        13) update_shell
        ;;
        14) update_aiko
        ;;
        *) echo -e "${red}Vui lòng nhập số chính xác [0-12]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0 $2
        ;;
        "config") config $*
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_Aiko_version 0
        ;;
        "update_shell") update_shell
        ;;
        *) show_usage
    esac
else
    show_menu
fi
