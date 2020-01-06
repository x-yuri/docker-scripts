#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

main() {
    local follow=$1
    shift
    local log_args=("$@")
    [[ $p_all ]] \
        && local filter=() \
        || local filter=(--filter desired-state=running)
    exd docker stack ps \
        "${filter[@]}" \
        --format='{{.ID}}' \
        -- "$p_stack" \
            | while IFS= read -r; do
                task_id=$REPLY
                task_line=$(exd docker inspect \
                    --format '
                        {{- .ServiceID -}}
                        |{{.Slot -}}
                        |{{with .Status}}{{if index . "ContainerStatus"}}
                            {{- .ContainerStatus.ContainerID}}
                        {{- end}}{{end -}}
                    ' \
                    -- "$task_id" \
                    || true)
                if ! [[ $task_line ]]; then continue; fi
                IFS='|' read -r task_svc_id task_no container_id \
                    <<< "$task_line"

                svc_name=$(exd docker service inspect \
                    --format '{{.Spec.Name}}' \
                    -- "$task_svc_id" \
                    || true)
                svc_name=${svc_name#${p_stack}_}

                if [[ $container_id ]] \
                && { ! [[ $p_svc_name ]] \
                    || [[ $svc_name == $p_svc_name ]]; } \
                && { ! [[ $p_task_no ]] \
                    || [[ $task_no == $p_task_no ]]; }; then
                        if ! [[ $follow ]]; then
                            hr "$svc_name.$task_no"
                        fi
                        docker logs "${log_args[@]}" -- "$container_id" 2>&1 \
                            || true
                fi
            done
}

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
p_log_options=("$@")

usage() {
    cat >&2 <<USAGE
Usage: $(basename -- "$0") [OPTIONS...] [SERVICE] [TASK_NO] [LOG_OPTIONS...]
Options:
    -a, --all
    -s, --stack STACK
USAGE
}

eval set -- "$(
    getopt -o a,s:,h --long all,stack:,help \
        -n "$(basename -- "$0")" -- "${p_options[@]}" "${p_args[@]}"
)"
p_all=
p_stack=$STACK
while true; do
    case "$1" in
        -a|--all) p_all=1
            shift
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

p_svc_name=${1-}
p_task_no=${2-}

{ [[ $(in_array -f "${p_log_options[@]}") ]] \
    || [[ $(in_array --follow "${p_log_options[@]}") ]]; } \
        && follow=1 \
        || follow=
if [ -t 0 ] && ! [[ $follow ]]; then
    main "$follow" "${p_log_options[@]}" | less
else
    main "$follow" "${p_log_options[@]}"
fi
