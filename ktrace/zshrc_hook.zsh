#!/bin/zsh
# Hook de journalisation des terminaux pour ktrace.
# Sourcé automatiquement par .zshrc — ne pas exécuter directement.

_ktrace_start_session() {
    [[ -n "$KTRACE_SESSION" ]] && return
    command -v script >/dev/null 2>&1 || return
    systemctl --user is-active --quiet ktrace.service 2>/dev/null || return

    local logdir="/opt/ktrace/terminals/$(date +%Y-%m-%d)"
    mkdir -p "$logdir" 2>/dev/null || return

    local tty_id
    tty_id=$(tty 2>/dev/null | tr '/' '_') || tty_id="notty"
    export KTRACE_SESSION=1
    exec script -q -f "$logdir/$(date +%H%M%S)${tty_id}_$$.log"
}
_ktrace_start_session
unset -f _ktrace_start_session

# Dans une session ktrace : journalise chaque commande saisie dans commands.log
if [[ -n "$KTRACE_SESSION" ]]; then
    _ktrace_log_cmd() {
        local logdir="/opt/ktrace/terminals/$(date +%Y-%m-%d)"
        [[ -d "$logdir" ]] || return
        printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${TTY##*/}" "$1" \
            >> "$logdir/commands.log"
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook preexec _ktrace_log_cmd
fi
