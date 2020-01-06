#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

docker network ls --format '{{.Name}}' \
    | while IFS= read -r; do
        name=$REPLY
        if [[ $name == ${STACK}_* ]]; then
            docker network rm -- "$name"
        fi
    done
