REGISTRY=
STACK=$(basename -- "`readlink -f -- .`")
IGNORE=()
COPY_DIRS=()
CLEAN_DIRS=()
DOCKER_STACK_YML=docker-stack.yml
ENV_FILES=()
IMAGE_TAG=
IMAGE_NAME=
NGINX_IMAGE_NAME=
if [[ -e .dockerscriptsrc ]]; then
    . .dockerscriptsrc
fi

common_trap() {
    if [[ $(cat "$g_errfile") ]]; then
        echo
        printf '%s errors:\n' --
        cat "$g_errfile"
    fi >&2
    rm "$g_errfile"
}

g_errfile=`mktemp`
g_trap="common_trap; ${g_trap-}"
trap "$g_trap" EXIT

# EXecute Docker command
# traps doesn't work in functions that are executed as part of a pipeline
# unless wrapped in a subshell
# expects $g_errfile to be created
exd() {(
    stderr=`mktemp`
    trap="rm ${stderr@Q}"
    trap "$trap" EXIT

    r=0
    "$@" 2> "$stderr" || r=$?

    if [[ $(cat "$stderr") ]]; then
        echo >> "$g_errfile"
        printf '$ %s\n' "$*" >> "$g_errfile"
        cat "$stderr" >> "$g_errfile"
        if (( $r )); then
            echo exit code: $r >> "$g_errfile"
        fi
    fi
    exit "$r"
)}

container_id() {
    local stack=$1 svc=$2 task_no=${3-1}
    local svc_id=
    while IFS= read -r; do
        local svc_line=$REPLY
        local id name
        IFS='|' read -r id name <<<$svc_line
        if [[ $name == "${stack}_$svc" ]]; then
            svc_id=$id
            break
        fi
    done < <(exd docker stack services --format '{{.ID}}|{{.Name}}' -- "$stack")

    if [[ $svc_id ]]; then
        while IFS= read -r; do
            local task_id=$REPLY
            task_line=$(exd docker inspect \
                --format '
                    {{- .ServiceID -}}
                    |{{.Slot -}}
                    |{{with .Status}}{{if index . "ContainerStatus"}}
                        {{- .ContainerStatus.ContainerID}}
                    {{- end}}{{end -}}
                ' -- "$task_id" \
                || true)
            if ! [[ $task_line ]]; then continue; fi
            IFS='|' read -r task_svc_id cur_task_no container_id \
                <<< "$task_line"

            if [[ $container_id ]] \
            && [[ $task_svc_id == $svc_id* ]] \
            && [[ $cur_task_no == $task_no ]]; then
                break
            fi
        done < <(exd docker stack ps \
            --filter desired-state=running \
            --format '{{.ID}}' \
            -- "$stack")

        echo "$container_id"
    fi
}

hr() {
    local s=$1 screen_width=$(tput cols)
    local str_width=$(printf '%s\n' "$s" | wc -c)
    printf "=%.0s" $(seq "$(echo "$screen_width - $str_width" | bc)")
    printf ' %s\n' "$s"
}

in_array() {
    local v=$1
    shift
    for el; do
        if [[ $el == $v ]]; then
            echo 1
            break
        fi
    done
}

join_by() {
    local d=$1
    shift
    if ! [[ ${1-} ]]; then
        return
    fi
    echo -n "$1"
    shift
    printf "%s" "${@/#/$d}"
}

# quote for Extended Regular Expression
qe() {
    local s=$1 delimiter=${2:-}
    local re='\.|\*|\[|\^|\$|\\|\+|\?|\{|\||\('   # .*[^$\+?{|(
    if [ "$delimiter" ]; then
        re=$re'|\'$delimiter
    fi
    printf "%s\n" "$s" | sed -E 's/'"$re"'/\\&/g'
}

starts_with() {
    local s=$1 prefix=$2
    [[ "$s" == "$prefix"* ]]
}

printerr() {
    local fmt=$1
    shift
    printf "$fmt" "$(basename -- "$0")" "$@" >&2
}

max_len() {
    local output=$1 field=$2
    printf '%s\n' "$output" | cut -d '|' -f "$field" | wc -L
}
