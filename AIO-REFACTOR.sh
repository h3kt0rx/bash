#!/bin/bash

# Constants
NFS_SERVER="192.168.0.21"
NFS_VERSION="4.2"
DOCKER_NETWORK="proxy"
DOCKER_COMPOSE_OPTIONS="-d --force-recreate"

# Define paths
YAML_PATH="/mnt/TrueNAS-01/Docker/YAML-Files"
DOCKER_VOL_PATH_EXTERNAL="/mnt/TrueNAS-02/Docker/docker_vol"
LOGS_PATH_EXTERNAL="/mnt/TrueNAS-02/Docker/docker_vol/ALL_LOGS"

# Define the prompt options
options=("Docker" "Automount YAML" "Automount docker_vol" "Install Coral-TPU" "Cloudflared" "Code-Server" "Flaresolverr" "Frigate" "HomeAssistant" "Homepage" "Hoshinova" "Jellyfin" "Jellyseerr")

# Functions
install_docker() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}You need to run this script with sudo.${ENDCOLOR}"
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
    echo "$nfs_path $mount_point nfs $NFS_VERSION,async,noatime,hard 0 0" | sudo tee -a /etc/fstab
    sudo systemctl daemon-reload
    sudo mount -t nfs "$nfs_path" "$mount_point"
}

deploy_service() {
    local service_name=$1
    local compose_file=$2
    sudo docker network create "$DOCKER_NETWORK"
    sudo docker compose -f "$compose_file" $DOCKER_COMPOSE_OPTIONS
}

# Ensure the directory exists in docker_vol
ensure_docker_vol_directory() {
    local service_name=$1
    local docker_vol_directory="$DOCKER_VOL_PATH_EXTERNAL/$service_name"
    if [ ! -d "$docker_vol_directory" ]; then
        echo -e "${RED}Directory $docker_vol_directory does not exist. Creating it now...${ENDCOLOR}"
        sudo mkdir -p "$docker_vol_directory"
    fi
}

# Ensure the ALL_LOGS directory exists
ensure_logs_directory() {
    local service_name=$1
    local logs_directory="$LOGS_PATH_EXTERNAL/$service_name"
    if [ ! -d "$logs_directory" ]; then
        echo -e "${RED}Directory $logs_directory does not exist. Creating it now...${ENDCOLOR}"
        sudo mkdir -p "$logs_directory"
    fi
}

# Main script execution
echo ""
echo "Please select what you want to install:"

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
            # Ensure the local /docker_vol directory exists before mounting external volumes
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
        "Cloudflared" | "Code-Server" | "Flaresolverr" | "Frigate" | "HomeAssistant" | "Homepage" | "Hoshinova" | "Jellyfin" | "Jellyseerr")
            install_mount_dependencies
            # Mount NFS volumes (in lowercase)
            mount_nfs "/docker_vol/$service_name" "$NFS_SERVER:$DOCKER_VOL_PATH_EXTERNAL/$opt"
            mount_nfs "/docker_vol/ALL_LOGS/$service_name" "$NFS_SERVER:$LOGS_PATH_EXTERNAL/$opt"
            deploy_service "$service_name" "$service_name.yml"
            exit
            ;;
        *)
            echo -e "${RED}Invalid option, please select a valid one.${ENDCOLOR}"
            ;;
    esac
done
