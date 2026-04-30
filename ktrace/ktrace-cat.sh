#!/bin/bash
# Affiche un fichier de session ktrace en supprimant les codes ANSI

if [[ $# -eq 0 ]]; then
    echo "Usage: ktrace-cat <session.log> [session2.log ...]"
    exit 1
fi

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "Fichier introuvable : $file" >&2
        continue
    fi
    sed \
        -e 's/\x1b\[[0-9;:?]*[a-zA-Z]//g' \
        -e 's/\x1b][^\x07]*\x07//g' \
        -e 's/\x1b[()][AB012]//g' \
        -e 's/\r//g' \
        -e '/^Script started/d' \
        -e '/^Script done/d' \
        "$file"
done
