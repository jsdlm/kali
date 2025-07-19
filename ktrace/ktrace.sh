#!/bin/bash

KTRACE_DIR="/opt/ktrace"
SCREENSHOT_DIR="$KTRACE_DIR/screenshots"
LOG_FILE="$KTRACE_DIR/log/ktrace.log"
DELAY=5

# Logging
log() {
  local level="$1"
  shift
  local message="$*"
  local log_entry="$(date '+%Y-%m-%d %H:%M:%S') [$level] $message"
  echo "$log_entry"
  echo "$log_entry" >> "$LOG_FILE"
}

# Préparation des répertoires
mkdir -p "$SCREENSHOT_DIR" || { log "ERROR" "Impossible de créer $SCREENSHOT_DIR"; exit 1; }
mkdir -p "$(dirname "$LOG_FILE")" || { log "ERROR" "Impossible de créer $(dirname "$LOG_FILE")"; exit 1; }

# Attente de l'affichage graphique
export DISPLAY=:0
export XAUTHORITY="/home/pentester/.Xauthority"

for i in {1..10}; do
    if xset q >/dev/null 2>&1; then
        break
    fi
    log INFO "Affichage graphique non prêt, tentative $i/10..."
    sleep 5
done

if ! xset q >/dev/null 2>&1; then
    log ERROR "Affichage graphique toujours indisponible après 10 tentatives. Abandon."
    exit 1
fi

# Vérification des dépendances
for cmd in scrot zip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR" "Dépendance manquante : $cmd"
    exit 1
  else
    log "INFO" "Dépendance présente : $cmd"
  fi
done

# Vérifie si un délai est spécifié
if [ "$#" -ge 1 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
  DELAY="$1"
else
  log "INFO" "Aucun délai fourni, valeur par défaut utilisée : $DELAY s"
fi

log "INFO" "Démarrage du service ktrace (intervalle = ${DELAY}s)"

while true; do
  # Compression des dossiers précédents
  for dir in "$SCREENSHOT_DIR"/*/; do
    dir_date=$(basename "$dir")
    if [ "$dir_date" != "$(date '+%Y-%m-%d')" ] && [ -d "$dir" ]; then
      zip_path="$SCREENSHOT_DIR/$dir_date.zip"
      zip -r "$zip_path" "$dir" -x "*.zip" &>/dev/null
      if [ $? -eq 0 ]; then
        rm -rf "$dir"
        log "INFO" "Dossier $dir_date compressé et supprimé."
      else
        log "WARNING" "Échec de la compression du dossier $dir_date."
      fi
    fi
  done

  # Capture dans dossier du jour
  today=$(date '+%Y-%m-%d')
  day_dir="$SCREENSHOT_DIR/$today"
  mkdir -p "$day_dir"

  filename="$day_dir/$(date '+%Y-%m-%d_%Hh%Mm%Ss').png"
  scrot "$filename" 2>/dev/null
  if [ $? -ne 0 ]; then
    log "ERROR" "Échec de la capture avec scrot."
  fi

  sleep "$DELAY"
done

