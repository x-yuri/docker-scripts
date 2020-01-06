#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

while ! docker push "$REGISTRY/${IMAGE_NAME-$STACK}${IMAGE_TAG:+:$IMAGE_TAG}"; do
    :
done
if [[ $NGINX_IMAGE_NAME ]]; then
    while ! docker push "$REGISTRY/${NGINX_IMAGE_NAME-$STACK}${IMAGE_TAG:+:$IMAGE_TAG}"; do
        :
    done
fi
