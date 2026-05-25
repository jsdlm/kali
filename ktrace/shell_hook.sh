#!/bin/sh
if [[ -z "$KTRACE_SESSION" ]] && systemctl --user is-active --quiet ktrace.service 2>/dev/null; then
    export KTRACE_SESSION=1
    _ktrace_dir="/opt/ktrace/terminals/$(date +%Y-%m-%d)"
    mkdir -p "$_ktrace_dir" 2>/dev/null
    exec script -q -f "$_ktrace_dir/$(whoami)_$(date +%Y%m%d_%H%M%S)_$$.log"
fi
