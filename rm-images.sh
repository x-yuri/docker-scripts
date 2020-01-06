#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

for id in $(docker image ls --filter "reference=${STACK}_*" --format '{{.ID}}'); do
    docker image rm "$id"
done
for id in $(docker image ls --filter "reference=$REGISTRY/${STACK}*" --format '{{.ID}}'); do
    reference=$(docker image inspect "$id" --format '{{index .RepoTags 0}}')
    if [[ $reference == $REGISTRY/$STACK:* ]] \
    || [[ $reference == $REGISTRY/$STACK/* ]]; then
        docker image rm "$id"
    fi
done
exit

ids=("$(docker image ls --filter "reference=$STACK*" --format '{{.ID}}')")
id=${ids[-1]}
while parent_id=$(docker image inspect "$id" --format '{{.Parent}}' \
    | sed -E 's/^sha256://') && [[ $parent_id ]]; do
        ids+=("$parent_id")
        id=${ids[-1]}
done

for id in "${ids[@]}"; do
    docker image rm "$id"
done
