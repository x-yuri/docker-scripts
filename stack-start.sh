#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...]
Options:
    -c, --compose-file FILE
    -s, --stack STACK
USAGE
}

eval set -- "$(
    getopt -o c:,s:,h --long compose-file:,stack:,help \
        -n "$(basename -- "$0")" -- "$@"
)"
p_docker_stack_yml=$DOCKER_STACK_YML
p_stack=$STACK
while true; do
    case "$1" in
        -c|--compose-file) p_docker_stack_yml=$2
            shift 2
            ;;
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

set -a
for f in "${ENV_FILES[@]}"; do
    . "$f"
done
set +a

docker stack deploy --prune --with-registry-auth \
    --compose-file "$p_docker_stack_yml" "$p_stack"

while docker stack ps \
--filter desired-state=running \
--format '{{.CurrentState}}' "$p_stack" \
| egrep -v '^Running' &> /dev/null; do
    sleep 5
done
