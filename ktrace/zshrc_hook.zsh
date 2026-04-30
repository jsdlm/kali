#!/bin/zsh
# Hook de journalisation des terminaux pour ktrace.
# Sourcé automatiquement par .zshrc — ne pas exécuter directement.

_ktrace_start_session() {
    [[ -n "$KTRACE_SESSION" ]] && return
    systemctl --user is-active --quiet ktrace.service 2>/dev/null || return

    local logdir="/opt/ktrace/terminals/$(date +%Y-%m-%d)"
    mkdir -p "$logdir" 2>/dev/null || return

    local tty_id
    tty_id=$(tty 2>/dev/null | tr '/' '_') || tty_id="notty"
    export KTRACE_SESSION=1
    export KTRACE_LOG="$logdir/$(date +%H%M%S)${tty_id}_$$.log"
    export KTRACE_CMD_LOG="$logdir/commands.log"
}
_ktrace_start_session
unset -f _ktrace_start_session

if [[ -n "$KTRACE_SESSION" ]]; then
    # Programmes TTY-aware : pas de capture (ils ont besoin d'un vrai terminal sur fd1)
    typeset -ga _KTRACE_SKIP
    _KTRACE_SKIP=(vim vi nano emacs less more man htop top mysql psql
                  python3 python ruby irb node ssh msfconsole tmux screen)

    _ktrace_preexec() {
        # Extraire la commande réelle (gère sudo, env, time, etc.)
        local -a words=(${(z)1})
        local cmd="${words[1]}"
        if [[ "$cmd" == (sudo|env|nice|time|command) ]]; then
            local i=2
            while (( i <= ${#words} )) && [[ "${words[i]}" == -* || "${words[i]}" == *=* ]]; do
                (( i++ ))
            done
            (( i <= ${#words} )) && cmd="${words[i]}"
        fi
        (( ${_KTRACE_SKIP[(I)$cmd]} )) && return

        local ts="$(date '+%Y-%m-%d %H:%M:%S')"

        # En-tête écrit directement dans le journal (bypass terminal)
        printf '%s\n$ %s\n' "$ts" "$1" >> "$KTRACE_LOG"
        printf '%s [%s] %s\n' "$ts" "${TTY##*/}" "$1" >> "$KTRACE_CMD_LOG"

        # Redirection stdout/stderr : tee vers terminal + sed ANSI-strip vers journal
        exec {_KTRACE_FD1}>&1 {_KTRACE_FD2}>&2
        exec 1> >(tee /dev/fd/${_KTRACE_FD1} | \
            sed -e 's/\x1b\[[0-9;:?]*[a-zA-Z]//g' \
                -e 's/\x1b][^\x07]*\x07//g' \
                -e 's/\r//g' \
            >> "$KTRACE_LOG") 2>&1
        _KTRACE_PID=$!
    }

    _ktrace_precmd() {
        [[ -n "$_KTRACE_FD1" ]] || return
        exec 1>&${_KTRACE_FD1} 2>&${_KTRACE_FD2}
        exec {_KTRACE_FD1}>&- {_KTRACE_FD2}>&-
        wait $_KTRACE_PID 2>/dev/null
        printf -- '---------------------------------------------------\n\n' >> "$KTRACE_LOG"
        unset _KTRACE_FD1 _KTRACE_FD2 _KTRACE_PID
    }

    autoload -Uz add-zsh-hook
    add-zsh-hook preexec _ktrace_preexec
    add-zsh-hook precmd _ktrace_precmd
fi
