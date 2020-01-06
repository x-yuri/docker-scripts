#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...] SERVICE [TASK_NO]
Options:
    -s, --stack STACK
USAGE
}

eval set -- "$(
    getopt -o s:,h --long stack:,help \
        -n "$(basename -- "$0")" -- "$@"
)"
p_stack=$STACK
while true; do
    case "$1" in
        -s|--stack) p_stack=$2
            shift 2
            ;;
        -h|--help) usage
            exit
            ;;
        --) shift
            break
            ;;
    esac
done

p_svc_name=${1-}
p_task_no=${2-1}

container_id "$p_stack" "$p_svc_name" "$p_task_no"
