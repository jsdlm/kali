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
trap 'passwd -u root 2>/dev/null || true' EXIT

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
USERNAME=""
USER_HOME=""
ABS_DIR="$(realpath "${BASH_SOURCE[0]}")"
WORK_DIR="$(dirname "$ABS_DIR")"
FSTAB_LINE=".host:/_share  /mnt/_share  fuse.vmhgfs-fuse  allow_other,defaults,nofail  0  0"
# sudo /usr/bin/vmhgfs-fuse .host:/_share /mnt/_share -o subtype=vmhgfs-fuse,allow_other

# ---------------------------------------
# Argument Parsing
# ---------------------------------------
INSTALL_MODE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--user) USERNAME="$2"; shift 2 ;;
        -m|--mode) INSTALL_MODE="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [ -z "$USERNAME" ]; then
    read -rp "Nom du user [pentester]: " USERNAME
    USERNAME="${USERNAME:-pentester}"
fi

if [ -z "$INSTALL_MODE" ]; then
    echo ""
    echo "Choisir le mode d'installation :"
    PS3="> "
    select INSTALL_MODE in "full" "oscp"; do
        case "$INSTALL_MODE" in
            full|oscp) break ;;
            *) echo "Choix invalide, entrer 1 ou 2." ;;
        esac
    done
fi

case "$INSTALL_MODE" in
    full|oscp) ;;
    *) echo "Mode inconnu : '$INSTALL_MODE'. Valeurs valides : full, oscp."; exit 1 ;;
esac

USER_HOME="/home/$USERNAME"

export USERNAME
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
        vim git gcc rsync golang apt-transport-https gnupg freerdp3-x11
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
    chown -R "$USERNAME:$USERNAME" "$SYSUTILS_DIR"

    log INFO "Installing custom wallpapers..."
    mkdir -p "$CUSTOM_BACKGROUNDS_DIR"
    if [ -n "$(ls -A "$WORK_DIR/backgrounds/" 2>/dev/null)" ]; then
        cp -R "$WORK_DIR/backgrounds/." "$CUSTOM_BACKGROUNDS_DIR/"
    else
        log WARN "backgrounds/ is empty or missing, skipping."
    fi

    log INFO "Setting login background image..."
    ln -sf "$CUSTOM_BACKGROUNDS_DIR/deb.png" /usr/share/desktop-base/kali-theme/login/background

    log INFO "Disabling terminal transparency..."
    local qterminal_conf="$USER_HOME/.config/qterminal.org/qterminal.ini"
    if [ -f "$qterminal_conf" ]; then
        sed -i 's/^TerminalTransparency=.*/TerminalTransparency=0/' "$qterminal_conf"
        sed -i 's/^ApplicationTransparency=.*/ApplicationTransparency=0/' "$qterminal_conf"
    else
        log WARN "qterminal.ini not found, skipping transparency config."
    fi
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
        wordlists libimage-exiftool-perl airgeddon testssl.sh whois \
        gitleaks dnsrecon dnsenum powershell-empire webshells \
        metasploit-framework mingw-w64 tftp-hpa snmp onesixtyone \
        webshells

    # log INFO "Installing Kerberos development libraries..."
    # apt install -yqq libkrb5-dev krb5-config
}

# ---------------------------------------
# Function: pipx Tools Setup
# ---------------------------------------
install_pipx_tools() {
    header "Installing pipx Tools (user: $USERNAME)"
    sudo -u "$USERNAME" pipx ensurepath || {
        log ERROR "pipx ensurepath failed for $USERNAME."
        exit 1
    }

    apt-get remove --purge -y \
        impacket-scripts python3-impacket \
        netexec \
        bloodhound \
        certipy-ad \
        sslyze \
        2>/dev/null || true
    apt-get autoremove -y 2>/dev/null || true

    sudo -u "$USERNAME" pipx install impacket
    sudo -u "$USERNAME" pipx install adidnsdump
    sudo -u "$USERNAME" pipx install git+https://github.com/Pennyw0rth/NetExec
    sudo -u "$USERNAME" pipx install bloodhound-ce
    sudo -u "$USERNAME" pipx install certipy-ad
    sudo -u "$USERNAME" pipx install updog
    sudo -u "$USERNAME" pipx install sslyze
    sudo -u "$USERNAME" pipx install prowler
    sudo -u "$USERNAME" pipx install scoutsuite

    sudo -u "$USERNAME" pipx upgrade-all
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
            chown -R "$USERNAME:$USERNAME" "$path"
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

    chown -R "$USERNAME:$USERNAME" "$TOOLS_DIR"
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
    mkdir -p "/home/$USERNAME/.java/.userPrefs/burp"
    mkdir -p "/root/.java/.userPrefs/burp"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.java/.userPrefs" -R

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
    usermod -aG docker "$USERNAME" || true
    log INFO "User '$USERNAME' was added to 'docker' group. A logout/login may be required."

    mkdir -p "/home/$USERNAME/.docker"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME/.docker" -R || true
    chmod g+rwx "/home/$USERNAME/.docker" -R || true
}


# ---------------------------------------
# Function: Setup BloodHound CE
# ---------------------------------------
setup_bloodhound() {
    header "Setting up BloodHound CE"
    mkdir -p "$BLOODHOUND_DIR"
    curl -fsSL "https://raw.githubusercontent.com/SpecterOps/bloodhound/main/examples/docker-compose/docker-compose.yml" \
        -o "$BLOODHOUND_DIR/docker-compose.yml"
    cp "$WORK_DIR/docker/bloodhound.env" "$BLOODHOUND_DIR/.env"
    chown -R "$USERNAME:$USERNAME" "$BLOODHOUND_DIR"
}

# ---------------------------------------
# Function: Setup Nessus
# ---------------------------------------
setup_nessus() {
    header "Setting up Nessus"
    mkdir -p "$NESSUS_DIR"
    cp "$WORK_DIR/docker/nessus.yaml" "$NESSUS_DIR/docker-compose.yml"
    # docker compose -f "$NESSUS_DIR/docker-compose.yml" pull
    chown -R "$USERNAME:$USERNAME" "$NESSUS_DIR"

    log INFO "Manual step required:"
    echo "Put Nessus ACTIVATION_CODE in $NESSUS_DIR/docker-compose.yml"
}


# ---------------------------------------
# Main Execution
# ---------------------------------------
id "$USERNAME" &>/dev/null || { log ERROR "User '$USERNAME' does not exist. Aborting."; exit 1; }

log INFO "Mode : $INSTALL_MODE | User : $USERNAME"

case "$INSTALL_MODE" in
    base)
        setup_base_system
        apply_customizations
        install_ktrace
        clone_repos
        install_docker
        install_pipx_tools
        setup_bloodhound
        install_burp
        setup_nessus
        post_install_notes
        ;;
    oscp)
        install_ktrace
        clone_repos
        install_docker
        setup_bloodhound
        ;;
    full)
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
        ;;
esac

passwd -u root 2>/dev/null || true
log SUCCESS "Setup completed successfully."
read -p "Appuie sur Entrée pour reboot..."
reboot
