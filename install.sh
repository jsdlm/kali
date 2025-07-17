#!/bin/bash

# ---------------------------------------
# Fail-Safe and Context Info
# ---------------------------------------
set -eE -o functrace

failure() {
  echo -e "$(date '+%d/%m/%Y %H:%M:%S') -- [ERROR] $(realpath "$0") failed at line $1: $2\n"
  exit 1
}

trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

# ---------------------------------------
# Constants
# ---------------------------------------
TOOLS_DIR="/opt/tools"
BURP_DIR="$TOOLS_DIR/burpsuitepro"
BLOODHOUND_DIR="$TOOLS_DIR/bloodhound"
NESSUS_DIR="$TOOLS_DIR/nessus"
PENTESTER_USER="pentester"
PENTESTER_HOME="/home/$PENTESTER_USER"
ABS_DIR="$(realpath "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$ABS_DIR")"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------
# Logging Functions (NetExec Style)
# ---------------------------------------
log() {
    local level="$1"
    shift
    local message="$*"
    local color_reset="\033[0m"
    local color_info="\033[36m"
    local color_warn="\033[33m"
    local color_error="\033[31m"
    local color_success="\033[32m"

    case "$level" in
        INFO)    echo -e "${color_info}[*] $message${color_reset}" ;;
        WARN)    echo -e "${color_warn}[-] $message${color_reset}" ;;
        ERROR)   echo -e "${color_error}[!] $message${color_reset}" ;;
        SUCCESS) echo -e "${color_success}[+] $message${color_reset}" ;;
        *)       echo "[$level] $message" ;;
    esac
}

header() {
    echo -e "\n\033[1;36m========== $1 ==========\033[0m"
}

# ---------------------------------------
# Function: Post-installation Manual Notes
# ---------------------------------------
post_install_notes() {
    header "Manual Post-install Steps"

    log INFO "Burp Suite Pro preferences:"
    echo "    cp root_prefs.xml -d /root/.java/.userPrefs/burp/prefs.xml"
    echo "    cp pentester_prefs.xml -d /home/pentester/.java/.userPrefs/burp/prefs.xml"

    log INFO "Nessus activation:"
    echo "    Put your ACTIVATION_CODE in /opt/tools/nessus/docker-compose.yml"
}


# ---------------------------------------
# Ensure Script Is Run as Root
# ---------------------------------------
if [ "$EUID" -ne 0 ]; then
    log ERROR "This script must be run as root."
    exit 1
fi

# ---------------------------------------
# Function: Autostart Setup
# ---------------------------------------
setup_startup() {
    header "Autostart Setup"
    mkdir -p $TOOLS_DIR
    mkdir -p /mnt/_share
    mkdir -p $PENTESTER_HOME/.config/autostart
    cp "$WORK_DIR/startup.sh" "$TOOLS_DIR/"
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$TOOLS_DIR"
    cp "$WORK_DIR/startup.sh.desktop" "$PENTESTER_HOME/.config/autostart/"
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$PENTESTER_HOME/.config/autostart/"
}

# ---------------------------------------
# Function: System and Package Setup
# ---------------------------------------
setup_system() {
    header "System Update and Dependencies"
    log INFO "Updating package index..."
    apt update

    log INFO "Installing base packages..."
    apt install -yq build-essential python3-dev ca-certificates curl

    log INFO "Installing pentest tools..."
    apt install -yq pipx nmap whatweb nikto sslscan curl gobuster ffuf \
        exploitdb sqlmap hydra tcpdump git hashcat responder mitm6 \
        wordlists libimage-exiftool-perl airgeddon vim

    log INFO "Installing Kerberos development libraries..."
    apt install -yq libkrb5-dev krb5-config gcc python3-dev
}

# ---------------------------------------
# Function: pipx Tools Setup
# ---------------------------------------
install_pipx_tools() {
    header "Installing pipx Tools (user: $PENTESTER_USER)"
    sudo -u "$PENTESTER_USER" pipx ensurepath || {
        log ERROR "pipx ensurepath failed for $PENTESTER_USER."
        exit 1
    }

    sudo -u "$PENTESTER_USER" pipx install impacket
    sudo -u "$PENTESTER_USER" pipx install adidnsdump
    sudo -u "$PENTESTER_USER" pipx install git+https://github.com/Pennyw0rth/NetExec
    sudo -u "$PENTESTER_USER" pipx install bloodhound-ce
    sudo -u "$PENTESTER_USER" pipx install certipy-ad
    sudo -u "$PENTESTER_USER" pipx install git+https://github.com/EnableSecurity/wafw00f.git
    sudo -u "$PENTESTER_USER" pipx install updog
}

# ---------------------------------------
# Function: Clone Repositories and Create Venvs
# ---------------------------------------
clone_repos() {
    header "Cloning Tools Repositories"
    mkdir -p "$TOOLS_DIR"

    clone_and_venv() {
        local name="$1"
        local repo="$2"
        local path="$TOOLS_DIR/$name"
        if [ ! -d "$path" ]; then
            git clone "$repo" "$path"
            chown -R "$PENTESTER_USER:$PENTESTER_USER" "$path"
        else
            log INFO "$name already cloned, skipping."
        fi
        if [ ! -d "$path/venv-$name" ]; then
            python3 -m venv "$path/venv-$name"
            log SUCCESS "Created venv-$name"
        else
            log INFO "venv-$name already exists, skipping."
        fi
    }

    clone_and_venv "PetitPotam"     "https://github.com/topotam/PetitPotam.git"
    clone_and_venv "PKINITtools"    "https://github.com/dirkjanm/PKINITtools"
    clone_and_venv "krbrelayx"      "https://github.com/dirkjanm/krbrelayx.git"
    clone_and_venv "pywhisker"      "https://github.com/ShutdownRepo/pywhisker.git"
    clone_and_venv "ntlmv1-multi"   "https://github.com/evilmog/ntlmv1-multi.git"

    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$TOOLS_DIR"
}


# ---------------------------------------
# Function: Install Burp Suite Pro
# ---------------------------------------
install_burp() {
    header "Installing Burp Suite Pro"
    if [ -f "/opt/BurpSuitePro/BurpSuitePro" ]; then
        log INFO "Burp Suite Pro already installed, skipping."
        return
    fi
    mkdir -p "$BURP_DIR"
    mkdir -p "/home/$PENTESTER_USER/.java/.userPrefs/burp"
    mkdir -p "/root/.java/.userPrefs/burp"
    chown "$PENTESTER_USER:$PENTESTER_USER" "/home/$PENTESTER_USER/.java/.userPrefs" -R

    wget "https://portswigger.net/burp/releases/download?product=pro&type=Linux" -O "$BURP_DIR/burpsuitepro.sh"
    chmod +x "$BURP_DIR/burpsuitepro.sh"
    bash "$BURP_DIR/burpsuitepro.sh"

    log INFO "Manual step required:"
    echo "    cp root_prefs.xml -d /root/.java/.userPrefs/burp/prefs.xml"
    echo "    cp pentester_prefs.xml -d /home/pentester/.java/.userPrefs/burp/prefs.xml"
}

# ---------------------------------------
# Function: Install and Configure Docker
# ---------------------------------------
install_docker() {
    header "Installing Docker"

    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    else
        log INFO "Docker GPG key already exists, skipping import."
    fi

    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list
    else
        log INFO "Docker APT source already present, skipping."
    fi

    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    groupadd docker 2>/dev/null || true
    usermod -aG docker "$PENTESTER_USER" || true
    log INFO "User '$PENTESTER_USER' was added to 'docker' group. A logout/login may be required."

    mkdir -p "/home/$PENTESTER_USER/.docker"
    chown "$PENTESTER_USER:$PENTESTER_USER" "/home/$PENTESTER_USER/.docker" -R || true
    chmod g+rwx "/home/$PENTESTER_USER/.docker" -R || true
}


# ---------------------------------------
# Function: Setup BloodHound CE
# ---------------------------------------
setup_bloodhound() {
    header "Setting up BloodHound CE"
    mkdir -p "$BLOODHOUND_DIR"

    if [ ! -f "$BLOODHOUND_DIR/docker-compose.yml" ]; then
        wget -O "$BLOODHOUND_DIR/docker-compose.yml" https://raw.githubusercontent.com/SpecterOps/bloodhound/main/examples/docker-compose/docker-compose.yml
    else
        log INFO "BloodHound docker-compose.yml already exists, skipping download."
    fi

    docker compose -f "$BLOODHOUND_DIR/docker-compose.yml" pull
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$BLOODHOUND_DIR"
}

# ---------------------------------------
# Function: Setup Nessus
# ---------------------------------------
setup_nessus() {
    header "Setting up Nessus"
    mkdir -p "$NESSUS_DIR"
    cp "$WORK_DIR/nessus.yaml" "$NESSUS_DIR/docker-compose.yml"
    docker compose -f "$NESSUS_DIR/docker-compose.yml" pull
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$NESSUS_DIR"

    log INFO "Manual step required:"
    echo "Put Nessus ACTIVATION_CODE in $NESSUS_DIR/docker-compose.yml"
}


# ---------------------------------------
# Main Execution
# ---------------------------------------
setup_startup
setup_system
install_pipx_tools
clone_repos
install_burp
install_docker
setup_bloodhound
setup_nessus
post_install_notes

log SUCCESS "Setup completed successfully."
read -p "Appuie sur Entrée pour reboot..."
reboot
