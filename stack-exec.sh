#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

n_args=2
no_more_options=
with_arg=
p_options=()
p_args=()
for el; do
    if [[ $with_arg ]]; then
        p_options+=("$el")
        shift
        with_arg=
    elif [[ $el == -- ]]; then
        no_more_options=1
        shift
    elif ! (( $no_more_options )) \
    && {
        [[ $el =~ ^-s ]] \
        || [[ $el =~ ^-[^-].*s ]] \
        || [[ $el == --stack ]]
    }; then
        p_options+=("$el")
        shift
        with_arg=1
    elif ! (( $no_more_options )) \
    && [[ $el == -* ]]; then
        p_options+=("$el")
        shift
    else
        if (( ${#p_args[@]} < "$n_args" )); then
            p_args+=("$el")
            shift
        fi
        if (( ${#p_args[@]} == "$n_args" )); then
            break
        fi
    fi
done
p_command=("$@")

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...] SERVICE [TASK_NO] [COMMAND...]
Options:
    -i, --interactive
    -s, --stack STACK
    -t, --tty
USAGE
}

eval set -- "$(
    getopt -o i,s:,t,h --long interactive,stack:,tty,help \
        -n "$(basename -- "$0")" -- "${p_options[@]}" "${p_args[@]}"
)"
p_stack=$STACK
p_options=()
while true; do
    case "$1" in
        -i|--interactive) p_options+=(-i)
            shift
            ;;
        -s|--stack) p_stack=$2
            shift 2
            ;;
        -t|--tty) p_options+=(-t)
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
    printerr '%s: %s\n' "no service specified"
    usage
    exit 1
fi

if ! (( ${#p_command[@]} )); then
    p_command=(bash)
fi

container_id=$(container_id "$p_stack" "${p_args[@]}")
docker exec "${p_options[@]}" -- "$container_id" "${p_command[@]}"
