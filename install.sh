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
SYSUTILS_DIR="/opt/sysutils"
SHARE_DIR="/mnt/_share"
BACKGROUNDS_DIR="/usr/share/backgrounds"
CUSTOM_BACKGROUNDS_DIR="$BACKGROUNDS_DIR/custom"
BLOODHOUND_DIR="$TOOLS_DIR/bloodhound"
NESSUS_DIR="$TOOLS_DIR/nessus"
PENTESTER_USER="pentester"
PENTESTER_HOME="/home/$PENTESTER_USER"
ABS_DIR="$(realpath "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$ABS_DIR")"
FSTAB_LINE=".host:/_share  /mnt/_share  fuse.vmhgfs-fuse  allow_other,defaults  0  0"
# sudo /usr/bin/vmhgfs-fuse .host:/_share /mnt/_share -o subtype=vmhgfs-fuse,allow_other

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------
# Logging Functions
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
# Function: Base System Setup
# ---------------------------------------
setup_base_system() {
    header "Base System Packages"
    log INFO "Updating APT index..."
    apt update -yqq
    apt upgrade -yqq

    log INFO "Installing base system packages..."
    apt install -yqq build-essential python3-dev ca-certificates curl \
        vim git gcc rsync
}

# ---------------------------------------
# Function: Desktop and Environment Customization
# ---------------------------------------
apply_customizations() {
    header "Applying System Customizations"

    log INFO "Creating system directories..."
    mkdir -p "$TOOLS_DIR"
    mkdir -p "$SHARE_DIR" 2>/dev/null || log WARN "Impossible de créer /mnt/_share (déjà monté ou inaccessible)"

    log INFO "Configuration du montage automatique de /mnt/_share"
    if ! grep -Fxq "$FSTAB_LINE" /etc/fstab; then
        echo "$FSTAB_LINE" >> /etc/fstab
        log SUCCESS "Entrée ajoutée dans /etc/fstab"
    else
        log INFO "Entrée déjà présente dans /etc/fstab"
    fi

    log INFO "Installing sysutils to /opt..."
    cp -R "$WORK_DIR/sysutils" "/opt"
    chmod -R +x "$SYSUTILS_DIR"
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$SYSUTILS_DIR"

    log INFO "Installing custom wallpapers..."
    mkdir -p "$CUSTOM_BACKGROUNDS_DIR"
    cp -R "$WORK_DIR/backgrounds/"* "$CUSTOM_BACKGROUNDS_DIR/"

    log INFO "Setting login background image..."
    ln -sf "$CUSTOM_BACKGROUNDS_DIR/deb.png" /usr/share/desktop-base/kali-theme/login/background

    log INFO "Applying XFCE configuration..."
    rsync -av --inplace --checksum "$WORK_DIR/xfce4/" "$PENTESTER_HOME/.config/xfce4/"

    log INFO "Disabling terminal transparency..."
    sed -i 's/^TerminalTransparency=.*/TerminalTransparency=0/' "$PENTESTER_HOME/.config/qterminal.org/qterminal.ini"
    sed -i 's/^ApplicationTransparency=.*/ApplicationTransparency=0/' "$PENTESTER_HOME/.config/qterminal.org/qterminal.ini"
}

# ---------------------------------------
# Function: Ktrace Installation
# ---------------------------------------
install_ktrace() {
    header "Installing ktrace"
    chmod +x $WORK_DIR/ktrace/install.sh
    $WORK_DIR/ktrace/install.sh
}

# ---------------------------------------
# Function: Pentest Tools Installation
# ---------------------------------------
install_pentest_tools() {
    header "Installing Pentest Tools"

    log INFO "Installing common offensive tools..."
    apt install -yqq pipx nmap whatweb nikto sslscan curl gobuster ffuf \
        exploitdb sqlmap hydra tcpdump hashcat responder mitm6 \
        wordlists libimage-exiftool-perl airgeddon

    log INFO "Installing Kerberos development libraries..."
    apt install -yqq libkrb5-dev krb5-config
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

    sudo -u "$PENTESTER_USER" pipx upgrade-all
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
    mkdir -p "$SYSUTILS_DIR"
    mkdir -p "/home/$PENTESTER_USER/.java/.userPrefs/burp"
    mkdir -p "/root/.java/.userPrefs/burp"
    chown "$PENTESTER_USER:$PENTESTER_USER" "/home/$PENTESTER_USER/.java/.userPrefs" -R

    wget "https://portswigger.net/burp/releases/download?product=pro&type=Linux" -O "$SYSUTILS_DIR/burpsuitepro.sh"
    chmod +x "$SYSUTILS_DIR/burpsuitepro.sh"
    bash "$SYSUTILS_DIR/burpsuitepro.sh"

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
    cp "$WORK_DIR/docker/bloodhound.yaml" "$BLOODHOUND_DIR/docker-compose.yml"
    docker compose -f "$BLOODHOUND_DIR/docker-compose.yml" pull
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$BLOODHOUND_DIR"
}

# ---------------------------------------
# Function: Setup Nessus
# ---------------------------------------
setup_nessus() {
    header "Setting up Nessus"
    mkdir -p "$NESSUS_DIR"
    cp "$WORK_DIR/docker/nessus.yaml" "$NESSUS_DIR/docker-compose.yml"
    docker compose -f "$NESSUS_DIR/docker-compose.yml" pull
    chown -R "$PENTESTER_USER:$PENTESTER_USER" "$NESSUS_DIR"

    log INFO "Manual step required:"
    echo "Put Nessus ACTIVATION_CODE in $NESSUS_DIR/docker-compose.yml"
}


# ---------------------------------------
# Main Execution
# ---------------------------------------
setup_base_system
apply_customizations
install_ktrace
install_pentest_tools
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
