#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...]
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

networks_exist() {
    while IFS= read -r; do
        local network=$REPLY
        if [[ $network == ${p_stack}_* ]]; then
            echo 1
            break
        fi
    done < <(docker network ls --format '{{.Name}}')
}

docker stack rm -- "$p_stack"
while docker stack ps -- "$p_stack" &> /dev/null; do
    sleep 1
done
while [[ $(networks_exist) ]]; do
    sleep 1
done
