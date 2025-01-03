#!/bin/bash

# Constants
NFS_SERVER="192.168.0.21"
NFS_VERSION="4.2"
DOCKER_NETWORK="proxy"

# Define paths
YAML_PATH="/mnt/TrueNAS-01/Docker/YAML-Files"
DOCKER_VOL_PATH_EXTERNAL="/mnt/TrueNAS-02/Docker/docker_vol"
LOGS_PATH_EXTERNAL="/mnt/TrueNAS-02/Docker/docker_vol/ALL_LOGS"

# Define the prompt options
options=("Docker" "Automount YAML" "Automount docker_vol" "Install Coral-TPU" "Cloudflared" "Code-Server" "Flaresolverr" "Frigate" "HomeAssistant" "Homepage" "Hoshinova" "InvoiceShelf" "Jellyfin" "Jellyseerr" "Lancache" "MineCraft-01" "MineCraft-02" "MQTT" "NetBoot_XYZ" "NextPVR" "PalWorld" "Prowlarr-Gluetun" "qBittorrent" "qBittorrent-Gluetun" "Radarr" "Recyclarr" "Semaphore" "Sonarr" "stirlingPDF" "Traefik" "UptimeKuma" "Vaultwarden" "WallOS" "Watchtower")

# Functions
install_docker() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "You need to run this script with sudo."
        exit 1
    fi
    sudo curl -fsSL https://get.docker.com | sh
}

install_mount_dependencies() {
    # Check if nfs-common is installed
    if ! dpkg -l | grep -q "nfs-common"; then
        echo "nfs-common is not installed. Installing..."
        sudo apt install nfs-common -y
    else
        echo "nfs-common is already installed."
    fi

    # Check if pciutils is installed
    if ! dpkg -l | grep -q "pciutils"; then
        echo "pciutils is not installed. Installing..."
        sudo apt install pciutils -y
    else
        echo "pciutils is already installed."
    fi
}

mount_nfs() {
    local mount_point=$1
    local nfs_path=$2
    sudo mkdir -p "$mount_point"
    echo "$nfs_path $mount_point  nfs      rw,async,noatime,hard,vers=$NFS_VERSION    0    0" | sudo tee -a /etc/fstab
    sudo systemctl daemon-reload
    sudo mount -t nfs "$nfs_path" "$mount_point"
}

deploy_service() {
    local service_name=$1
    local compose_file=$2
    sudo docker network create "$DOCKER_NETWORK"
    sudo docker compose -f "/yaml-files/$compose_file" up -d --force-recreate
}

# Ask for the next action after the main selection
choose_action() {
    echo ""
    echo ""
    echo -e "\033[32mWhat action do you want to do for \033[31m$1\033[31m\033[32m\033[0m?"
    select action in "Mount Directories" "Deploy/Re-Create the Service" "Both"; do
        case $action in
            "Mount Directories")
                mount_nfs "/docker_vol/$1" "$NFS_SERVER:$DOCKER_VOL_PATH_EXTERNAL/$1"
                mount_nfs "/docker_vol/ALL_LOGS/$1" "$NFS_SERVER:$LOGS_PATH_EXTERNAL/$1"
                break
                ;;
            "Deploy/Re-Create the Service")
                deploy_service "$1" "$1.yml"
                break
                ;;
            "Both")
                mount_nfs "/docker_vol/$1" "$NFS_SERVER:$DOCKER_VOL_PATH_EXTERNAL/$1"
                mount_nfs "/docker_vol/ALL_LOGS/$1" "$NFS_SERVER:$LOGS_PATH_EXTERNAL/$1"
                deploy_service "$1" "$1.yml"
                break
                ;;
            *)
                echo "Invalid choice. Please select a valid option."
                ;;
        esac
    done
}

# Main script execution
echo ""
echo ""
echo -e "\033[32mPlease select what you want to install:\033[32m\033[0m"

select opt in "${options[@]}"; do
    # Convert selected option to lowercase
    service_name=$(echo "$opt" | tr '[:upper:]' '[:lower:]')

    case $opt in
        "Docker")
            install_docker
            exit
            ;;
        "Automount YAML")
            install_mount_dependencies
            mount_nfs "/yaml-files" "$NFS_SERVER:$YAML_PATH"
            exit
            ;;
        "Automount docker_vol")
            install_mount_dependencies
            mount_nfs "/docker_vol" "$NFS_SERVER:$DOCKER_VOL_PATH_EXTERNAL"
            exit
            ;;
        "Install Coral-TPU")
            sudo apt-get update -y
            sudo apt-get install gnupg2 -y
            echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | sudo tee /etc/apt/sources.list.d/coral-edgetpu.list
            curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
            sudo apt-get update -y
            sudo apt-get install gasket-dkms libedgetpu1-std -y
            ;;
        "Cloudflared" | "CrowdSec" | "Flaresolverr" | "Frigate" | "HomeAssistant" | "Homepage" | "Hoshinova" | "InvoiceShelf" | "Jellyfin" | "Jellyseerr" | "Lancache" | "MineCraft-01" | "MineCraft-02" | "MQTT" | "NetBoot_XYZ" | "NextPVR" | "PalWorld" | "Prowlarr-Gluetun" | "qBittorrent" | "qBittorrent-Gluetun" | "Radarr" |"Recyclarr" | "Semaphore" | "Sonarr" | "stirlingPDF" | "Traefik" | "UptimeKuma" | "Vaultwarden" | "WallOS" | "Watchtower")
            install_mount_dependencies
            choose_action "$service_name"
            exit
            ;;
        "Code-Server")
            install_mount_dependencies
            mount_nfs "/docker_vol" "$NFS_SERVER:$DOCKER_VOL_PATH_EXTERNAL"
            choose_action "$service_name"
            exit
            ;;
        *)
            echo "Invalid choice. Please select a valid option."
            ;;
    esac
done
#
######### LANCACHE_PREFILL ###########
# sudo docker run -it --rm --net=host \
# --volume /dockermount/lancache/prefill/config:/Config \
# -e TZ="America/Detroit" \
# --name lancache-prefill \
# tpill90/steam-lancache-prefill:latest \
# prefill --unit bytes
######### LABELS - EXAMPLE ###########
    # labels:
    #   - "traefik.enable=true"
    #   - "traefik.http.routers.qbittorrent-vpn.entrypoints=http"
    #   - "traefik.http.routers.qbittorrent-vpn.rule=Host(`qt.local.ortegatalks.net`)"
    #   - "traefik.http.middlewares.qbittorrent-vpn-https-redirect.redirectscheme.scheme=https"
    #   - "traefik.http.routers.qbittorrent-vpn.middlewares=qbittorrent-vpn-https-redirect"
    #   - "traefik.http.routers.qbittorrent-vpn-secure.entrypoints=https"
    #   - "traefik.http.routers.qbittorrent-vpn-secure.tls.certresolver=cloudflare"
    #   - "traefik.http.routers.qbittorrent-vpn-secure.rule=Host(`qt.local.ortegatalks.net`)"
    #   - "traefik.http.routers.qbittorrent-vpn-secure.tls=true"
    #   - "traefik.http.routers.qbittorrent-vpn-secure.service=qbittorrent-vpn"
    #   - "traefik.http.services.qbittorrent-vpn.loadbalancer.server.port=27981"
