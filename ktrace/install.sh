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
USERNAME="${USERNAME:-pentester}"
USER_HOME="/home/$USERNAME"
SERVICE_DIR="$USER_HOME/.config/systemd/user"
SCRIPT_NAME="ktrace.sh"
SERVICE_NAME="ktrace.service"

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
mkdir -p "$INSTALL_DIR/terminals"

# Copie du script principal et du hook zsh
log INFO "Copie de $SCRIPT_NAME dans $INSTALL_DIR"
cp "$(dirname "$0")/$SCRIPT_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

log INFO "Copie du hook terminal dans $INSTALL_DIR"
cp "$(dirname "$0")/shell_hook.sh" "$INSTALL_DIR/shell_hook.sh"
chmod 644 "$INSTALL_DIR/shell_hook.sh"

# Préparation du service utilisateur
log INFO "Installation du service systemd --user"
mkdir -p "$SERVICE_DIR"
cp "$(dirname "$0")/$SERVICE_NAME" "$SERVICE_DIR/$SERVICE_NAME"
chown -R "$USERNAME:$USERNAME" "$SERVICE_DIR"

# Attribution des droits sur le dossier ktrace
log INFO "Attribution des droits à l'utilisateur $USERNAME"
chown -R "$USERNAME:$USERNAME" "$INSTALL_DIR"

# Ajout des alias dans .zshrc s'ils n'existent pas
ALIASES=(
    "alias ktrace-start='systemctl --user start ktrace.service'"
    "alias ktrace-stop='systemctl --user stop ktrace.service'"
    "alias ktrace-restart='systemctl --user restart ktrace.service'"
    "alias ktrace-status='systemctl --user status ktrace.service'"
    "alias ktrace-enable='systemctl --user enable ktrace'"
    "alias ktrace-disable='systemctl --user disable ktrace'"
)

for RC_FILE in "$USER_HOME/.zshrc" "$USER_HOME/.bashrc"; do
    log INFO "Ajout des alias dans $RC_FILE (si absents)"
    for alias in "${ALIASES[@]}"; do
        grep -qxF "$alias" "$RC_FILE" || echo "$alias" >> "$RC_FILE"
    done
    chown "$USERNAME:$USERNAME" "$RC_FILE"
done

# Ajout du hook de journalisation terminal dans .zshrc et .bashrc (si absent)
HOOK_LINE="[[ -f /opt/ktrace/shell_hook.sh ]] && source /opt/ktrace/shell_hook.sh"
for RC_FILE in "$USER_HOME/.zshrc" "$USER_HOME/.bashrc"; do
    grep -qF "shell_hook.sh" "$RC_FILE" || echo "$HOOK_LINE" >> "$RC_FILE"
    chown "$USERNAME:$USERNAME" "$RC_FILE"
done

# Ending
log SUCCESS "Installation terminée."
log INFO "Connectez-vous en tant que $USERNAME et exécutez :"
log INFO "    systemctl --user daemon-reload"
log INFO "    systemctl --user enable ktrace.service"
log INFO "    systemctl --user start ktrace.service"
