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
    && { [[ $el == -s ]] || [[ $el == --stack ]]; }; then
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

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...] SERVICE [TASK_NO]
Options:
    -s, --stack STACK
USAGE
}

eval set -- "$(
    getopt -o s:,h --long stack:,help \
        -n "$(basename -- "$0")" -- "${p_options[@]}" "${p_args[@]}"
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

if (( $# == 0 )); then
    printerr '%s: %s\n' "no service specified"
    usage
    exit 1
fi
p_svc_name=$1
p_task_no=${2-1}

container_id=$(container_id "$p_stack" "$p_svc_name" "$p_task_no")
docker attach -- "$container_id"
