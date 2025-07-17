#!/bin/bash
echo "=== Script de démarrage ==="
echo "Vérification de l'adresse IP publique :"
curl ifconfig.me
echo
curl ifconfig.io
echo "Vérifier que l'on est connecté au réseau du lab avant de commencer le pentest"
echo "Vérification de la date pour les screens ktrace"
date
read -p "Appuie sur Entrée pour fermer..."