#!/bin/bash

# Function to check if wget is installed, and install it if not
check_dependencies() {
    if ! command -v wget &> /dev/null; then
        echo "wget is not installed. Installing..."
        sudo apt-get install wget
    fi
}
install_droop() {
clear
dropport=222
echo -e "\nPlease input DropBear Port."
printf "Default Port is \e[33m${dropport}\e[0m, let it blank to use this Port: "
read dropporttmp
if [[ -n "${dropporttmp}" ]]; then
    dropport=${dropporttmp}
fi

sudo apt update -y
sudo apt install dropbear -y
cat >  /etc/default/dropbear << ENDOFFILE
NO_START=0
DROPBEAR_PORT=$dropport
DROPBEAR_EXTRA_ARGS=""
DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"
DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"
DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"
DROPBEAR_RECEIVE_WINDOW=65536
ENDOFFILE
sudo ufw allow $dropport
sudo systemctl restart dropbear
sudo systemctl enable dropbear
clear
echo "DROPBEAR Installed As Port : $dropport"
}
#Check installed service
check_installed() {
    if [ -f "/etc/systemd/system/tunnel.service" ]; then
        echo "The service is already installed."
        exit 1
    fi
}

# Function to download and install RTT
install_rtt() {
    wget "https://raw.githubusercontent.com/radkesvat/ReverseTlsTunnel/master/install.sh" -O install.sh && chmod +x install.sh && bash install.sh
}

# Function to configure arguments based on user's choice
configure_arguments() {
    read -p "Which server do you want to use? (Enter '1' for Iran or '2' for Kharej) : " server_choice
    read -p "Please Enter SNI (default : splus.ir): " sni
    sni=${sni:-splus.ir}


    if [ "$server_choice" == "2" ]; then
        read -p "Please Enter (IRAN IP) : " server_ip
        read -p "Please Enter Password (Please choose the same password on both servers): " password
        read -p "Please Enter pool (default : 4): " pool
        pool=${pool:-4}
        read -p "Please Enter iranport (default :443): " iranport
        iranportt=${iranport:-443}
        read -p "Please Enter port config (default :443): " portconfig
        portconfig=${portconfig:-443}
        arguments="--kharej --iran-ip:$server_ip --iran-port:$iranport --toip:127.0.0.1 --toport:$portconfig --password:$password --sni:$sni --terminate:24 --pool:$pool"
    elif [ "$server_choice" == "1" ]; then
        read -p "Please Enter Password (Please choose the same password on both servers): " password
        read -p "Please Enter port lisen (default :443): " portlisen
        portlisen=${portlisen:-443}
        arguments="--iran --lport:$portlisen --sni:$sni --password:$password --terminate:24"
    else
        echo "Invalid choice. Please enter '1' or '2'."
        exit 1
    fi
}

# Function to handle installation
install() {
    check_dependencies
    check_installed
    install_rtt
    # Change directory to /etc/systemd/system
    cd /etc/systemd/system

    configure_arguments

    # Create a new service file named tunnel.service
    cat <<EOL > tunnel.service
[Unit]
Description=my tunnel service

[Service]
User=root
WorkingDirectory=/root
ExecStart=/root/RTT $arguments
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemctl daemon and start the service
    sudo systemctl daemon-reload
    sudo systemctl start tunnel.service
    sudo systemctl enable tunnel.service
}

# Function to handle uninstallation
uninstall() {
    # Check if the service is installed
    if [ ! -f "/etc/systemd/system/tunnel.service" ]; then
        echo "The service is not installed."
        return
    fi

    # Stop and disable the service
    sudo systemctl stop tunnel.service
    sudo systemctl disable tunnel.service

    # Remove service file
    sudo rm /etc/systemd/system/tunnel.service
    sudo systemctl reset-failed
    sudo rm RTT
    sudo rm install.sh

    echo "Uninstallation completed successfully."
}

check_update() {
    # Get the current installed version of RTT
    installed_version=$(./RTT -v 2>&1 | grep -o '"[0-9.]*"')
    

    # Fetch the latest version from GitHub releases
    latest_version=$(curl -s https://api.github.com/repos/radkesvat/ReverseTlsTunnel/releases/latest | grep -o '"tag_name": "[^"]*"' | cut -d":" -f2 | sed 's/["V ]//g' | sed 's/^/"/;s/$/"/')

    # Compare the installed version with the latest version
    if [[ "$latest_version" > "$installed_version" ]]; then
        echo "A new version is available, please reinstall: $latest_version (Installed: $installed_version)."
    else
        echo "You have the latest version ($installed_version)."
    fi
}


#ip & version
myip=$(hostname -I | awk '{print $1}')
po=$(cat /etc/ssh/sshd_config | grep "^Port")
port=$(echo "$po" | sed "s/Port //g")
version=$(./RTT -v 2>&1 | grep -o 'version="[0-9.]*"')

# Main menu
clear
echo "Thanks of RadKesvat  *https://github.com/radkesvat/ReverseTlsTunnel/tree/master*  "
echo "Your IP is: ($myip) "
echo "Server port:($port)"
echo " --------#- Reverse Tls Tunnel -#--------"
echo "1) Install"
echo "2) Uninstall"
echo "3) Check Update"
echo "4) Install drop "
echo "0) Exit"
echo " --------------$version---------------"
read -p "Please choose: " choice

case $choice in
    1)
        install
        ;;
    2)
        uninstall
        ;;
    3) check_update
        ;;
    4)
        install drop
        ;;
    0)
        exit
        ;;
    *)
        echo "Invalid choice. Please try again."
        ;;
esac
