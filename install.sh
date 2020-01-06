#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...] USER@HOST [PORT]
Options:
    -f, --force
    -u, --rm, --uninstall
USAGE
}

eval set -- "$(
    getopt -o f,u,h --long f,rm,uninstall,help \
        -n "$(basename -- "$0")" -- "$@"
)"
p_force=
p_uninstall=
while true; do
    case "$1" in
        -f|--force) p_force=1
            shift
            ;;
        -u|--rm|--uninstall) p_uninstall=1
            shift
            ;;
        -h|--help) usage
            exit
            ;;
        --) shift
            break
            ;;
    esac
done

if (( $# == 0 )); then
    printerr '%s: %s\n' "no destination specified"
    usage
    exit 1
fi
p_user_host=$1
p_port=${2-22}

if [[ $p_uninstall ]]; then
    ssh -p "$p_port" "$p_user_host" rm -rf docker-scripts
else
    if ssh -p "$p_port" "$p_user_host" [ -e docker-scripts ]; then
        if ! [[ $p_force ]]; then
            printerr '%s: %s\n' "docker-scripts dir already exists"
            exit 1
        fi
    fi
    scripts=(
        common.sh
        image-tree.sh
        ls-volumes.sh
        network-info.sh
        snapshot.sh
        stack-attach.sh
        stack-container-id.sh
        stack-exec.sh
        stack-info.sh
        stack-logs.sh
        stack-ls.sh
        stack-restart.sh
        stack-start.sh
        stack-stop.sh
    )
    ssh -p "$p_port" "$p_user_host" mkdir -p docker-scripts
    for s in "${scripts[@]}"; do
        scp -r -P "$p_port" "$prj_dir/$s" "$p_user_host":docker-scripts
    done
fi
