#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0")
Options:
    -i, --with-images
USAGE
}

eval set -- "$(
    getopt -o i,h --long with-images,help \
        -n "$(basename -- "$0")" -- "$@"
)"
p_with_images=
while true; do
    case "$1" in
        -i|--with-images) p_with_images=1
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

if [[ -e docker-compose.yml ]]; then
    docker-compose down
fi
"$prj_dir"/stack-stop.sh -s "$STACK"
docker container prune --force
"$prj_dir"/rm-volumes.sh
docker image prune --force ${p_with_images:+--all}
"$prj_dir"/rm-images.sh
for d in "${COPY_DIRS[@]}" "${CLEAN_DIRS[@]}"; do
    sudo chown -R yuri: "$d" || true
    rm -rf "$d"
done
