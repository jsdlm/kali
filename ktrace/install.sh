#!/bin/bash
set -e

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

# Variables
INSTALL_DIR="/opt/ktrace"
USER_HOME="/home/pentester"
SERVICE_DIR="$USER_HOME/.config/systemd/user"
SCRIPT_NAME="ktrace.sh"
SERVICE_NAME="ktrace.service"
ALIAS_FILE="$USER_HOME/.zshrc"

# Vérification des droits
if [ "$EUID" -ne 0 ]; then
  log ERROR "Ce script doit être exécuté en tant que root."
  exit 1
fi

# Installation des dépendances
log INFO "Installation des dépendances : scrot, zip"
apt update -qq
apt install -yq scrot zip > /dev/null

# Création de l'arborescence
log INFO "Création du répertoire $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/log"
mkdir -p "$INSTALL_DIR/screenshots"

# Copie du script principal
log INFO "Copie de $SCRIPT_NAME dans $INSTALL_DIR"
cp "$(dirname "$0")/$SCRIPT_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

# Préparation du service utilisateur
log INFO "Installation du service systemd --user"
mkdir -p "$SERVICE_DIR"
cp "$(dirname "$0")/$SERVICE_NAME" "$SERVICE_DIR/$SERVICE_NAME"
chown -R pentester:pentester "$SERVICE_DIR"

# Attribution des droits sur le dossier ktrace
log INFO "Attribution des droits à l'utilisateur pentester"
chown -R pentester:pentester "$INSTALL_DIR"

# Ajout des alias dans .zshrc s'ils n'existent pas
ALIASES=(
    "alias ktrace-start='systemctl --user start ktrace.service'"
    "alias ktrace-stop='systemctl --user stop ktrace.service'"
    "alias ktrace-restart='systemctl --user restart ktrace.service'"
    "alias ktrace-status='systemctl --user status ktrace.service'"
    "alias ktrace-enable='systemctl --user enable ktrace'"
    "alias ktrace-disable='systemctl --user disable ktrace'"
)

log INFO "Ajout des alias dans $ALIAS_FILE (si absents)"
for alias in "${ALIASES[@]}"; do
    grep -qxF "$alias" "$ALIAS_FILE" || echo "$alias" >> "$ALIAS_FILE"
done
chown pentester:pentester "$ALIAS_FILE"

# Ending
log SUCCESS "Installation terminée."
log INFO "Connectez-vous en tant que pentester et exécutez :"
log INFO "    systemctl --user daemon-reload"
log INFO "    systemctl --user enable ktrace.service"
log INFO "    systemctl --user start ktrace.service"
