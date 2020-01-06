#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

print_image() {
    local id=$1 l=${2-0}
    local name=$(docker image inspect "$id" --format \
        '{{if gt (len .RepoTags) 0}}
            {{- index .RepoTags 0}}
        {{- end}}')
    local digest=$(docker image inspect "$id" --format \
        '{{if gt (len .RepoDigests) 0}}
            {{- index .RepoDigests 0}}
        {{- end}}' \
        | sed -E 's/@.*//')
    name=${name:-$digest}
    printf "%*s%s%s\n" "$(( l * 2 ))" '' "$id" "${name:+ ($name)}"
}

print_children() {
    local parent_id=$1 l=${2-1}
    local id
    for id in "${!parents[@]}"; do
        if [[ ${parents[$id]} == $parent_id ]]; then
            print_image "$id" "$l"
            print_children "$id" "$(( l + 1 ))"
        fi
    done
}

declare -A parents
ids=($(docker image ls --all --format '{{.ID}}'))
for id in "${ids[@]}"; do
    id=${id:0:12}
    parent_id=$(docker image inspect "$id" --format '{{.Parent}}' \
        | sed -E 's/^sha256://')
    parent_id=${parent_id:0:12}
    parents[$id]=$parent_id
done

for id in "${!parents[@]}"; do
    if ! [[ ${parents[$id]} ]]; then
        print_image "$id"
        print_children "$id"
    fi
done
