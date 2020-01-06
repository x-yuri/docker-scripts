#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0")
Options:
    -c, --clean
    -f, --file COMPOSE_FILE
USAGE
}

eval set -- "$(
    getopt -o c,i,f:,h --long clean,with-images,file:,help \
        -n "$(basename -- "$0")" -- "$@"
)"
p_clean=
p_with_images=
p_file=Dockerfile
while true; do
    case "$1" in
        -c|--clean) p_clean=1
            shift
            ;;
        -i|--with-images) p_with_images=1
            shift
            ;;
        -f|--file) p_file=$2
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

if [[ $p_clean ]]; then
    "$prj_dir"/clean.sh ${p_with_images:+--with-images}
fi

files=$(git ls-files)
add_untracked=()
ignore_but=()
for d in "${COPY_DIRS[@]}"; do
    dprev=
    dcur=$d
    q_dcur=$(qe "$dcur")
    while [[ "$dcur" != . ]]; do
        if echo "$files" | egrep "^$q_dcur" &> /dev/null; then
            break
        fi
        if [[ ${dprev-} ]]; then
            ignore_but+=("$(dirname -- "$dprev"):$(basename -- "$dprev")")
        fi
        dprev=$dcur
        dcur=$(dirname -- "$dcur")
        q_dcur=$(qe "$dcur")
    done
    add_untracked+=("$dprev")
done

q_add_untracked=()
for a in "${add_untracked[@]}"; do
    q_add_untracked+=("$(qe "$a")")
done

touch .dockerignore
{ echo .git
git ls-files --others --directory; } \
    | sed -E 's|^|/|; s|/$||' \
    | egrep -v '^/('"$(join_by '|' "${q_add_untracked[@]}")"')$' \
    > .dockerignore
for i in "${IGNORE[@]}"; do
    echo "/$i" >> .dockerignore
done
for i in "${ignore_but[@]}"; do
    IFS=: read -r path but <<<"$i"
    ls -A1 "$path" \
        | while IFS= read -r; do
            if [ "$REPLY" != "$but" ]; then
                echo "/$path/$REPLY" >> .dockerignore
            fi
        done
done

docker build -f "$p_file" \
    -t "$REGISTRY/${IMAGE_NAME-$STACK}${IMAGE_TAG:+:$IMAGE_TAG}" .

n=$(docker create "$REGISTRY/${IMAGE_NAME-$STACK}${IMAGE_TAG:+:$IMAGE_TAG}")
for d in "${COPY_DIRS[@]}"; do
    rm -rf "$d"
    docker cp "$n":/app/"$d" "$d" || true
done
docker container rm "$n"

if [[ $NGINX_IMAGE_NAME ]]; then
    docker build -f nginx/Dockerfile \
        -t "$REGISTRY/${NGINX_IMAGE_NAME-$STACK}${IMAGE_TAG:+:$IMAGE_TAG}" .
fi
