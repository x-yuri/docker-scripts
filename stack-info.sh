#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

main() {
    printf 'Swarm: %s\n' "$(docker info --format '{{.Swarm.LocalNodeState}}')"
    g_node=$(docker info --format '{{.Name}}')
    if [[ $p_stack ]]; then
        print_stack "$p_stack"
    else
        exd docker stack ls --format '{{.Name}}' | while IFS= read -r; do
            stack=$REPLY
            print_stack "$stack"
        done
    fi
}

print_stack() {
    local stack=$1
    printf "stack: %s\n" "$stack"

    local services=$(exd docker stack services \
        --filter name="$stack" \
        --format '{{.ID}}|{{.Name}}|{{.Image}}' \
        -- "$stack" \
        || true)
    services=$(printf '%s\n' "$services" | while IFS= read -r; do
        svc_line=$REPLY
        IFS='|' read -r svc_id rest <<< "$svc_line"
        svc_line_2=$(exd docker service inspect --format '
            {{- range $i, $el := .Endpoint.VirtualIPs}}
                {{- if $i}}, {{end}}
                {{- .Addr}} ({{printf "%.12s" .NetworkID}})
            {{- end -}}
        ' -- "$svc_id" \
        || true)
        printf "%s|%s\n" "$svc_line" "$svc_line_2"
    done)
    local ml_img=$(max_len "$services" 3)

    local tasks=$(exd docker stack ps \
        --filter desired-state=running \
        --format '{{.ID}}|{{.Name}}|{{.Node}}' \
        -- "$stack" \
        || true)
    if [[ $tasks ]]; then
        tasks=$(printf '%s\n' "$tasks" | while IFS= read -r; do
            task_line=$REPLY
            IFS='|' read -r task_id rest <<< "$task_line"
            task_line_2=$(exd docker inspect --format '
                {{- .ServiceID -}}
                |{{with .Status}}{{if index . "ContainerStatus"}}
                    {{- .ContainerStatus.ContainerID}}
                {{- end}}{{end -}}
                |{{range $i, $el := .NetworksAttachments}}{{with .Network}}
                    {{- if $i}}{{"!"}}{{end}}
                    {{- .Spec.Name}} ({{printf "%.12s" .ID}})
                    {{- with .Spec.DriverConfiguration}}{{- if index . "Name"}}
                        {{- print " " .Name}}
                    {{- end}}{{end}}
                    {{- print " " .Spec.Scope}}
                    {{- with .IPAMOptions}}{{- if index . "Configs"}}
                        {{- range $j, $el2 := .Configs}}
                            {{- if $j}}, {{end}}
                            {{- print " " .Subnet}}
                            {{- print " " .Gateway}}
                        {{- end}}
                    {{- end}}{{end}}
                {{- end}}{{end -}}
            ' -- "$task_id" \
            || true)
            printf "%s|%s\n" "$task_line" "$task_line_2"
        done)
    fi
    local ml_node=$(max_len "$tasks" 3)

    printf '%s\n' "$services" | while IFS= read -r; do
        svc_line=$REPLY
        IFS='|' read -r svc_id svc_name image vips <<< "$svc_line"
        printf "    service: %s (%s)\n" "$svc_name" "$svc_id"
        printf "             image: %-*s\n" "$ml_img" "$image"
        printf "             vips: %s\n" "$vips"
        get_svc_tasks "$svc_id" "$tasks" \
            | while IFS= read -r; do
                task_line=$REPLY
                print_task "$task_line" "$ml_node"
            done
    done
}

get_svc_tasks() {
    local svc_id=$1 tasks=$2
    printf '%s\n' "$tasks" | while IFS= read -r; do
        task_line=$REPLY
        IFS='|' read -r task_id task_name node task_svc_id container_id \
            <<< "$task_line"
        if [[ $task_svc_id == $svc_id* ]]; then
            printf '%s\n' "$task_line"
        fi
    done
}

print_task() {
    local task_line=$1 ml_node=$2
    local task_id task_name node task_svc_id container_id networks
    IFS='|' read -r task_id task_name node task_svc_id container_id networks \
        <<< "$task_line"
    printf "        task: %s (%s)\n" "$task_name" "$task_id"
    printf "              node: %-*s\n" "$ml_node" "$node"
    printf "%s\n" "$networks" | tr '!' $'\n' | while IFS= read -r; do
        printf "              network: %s\n" "$REPLY"
    done

    if [[ $container_id ]] && [[ $node == $g_node ]]; then
        local container_line
        local container_line=$(exd docker container inspect \
            --format '
                {{- .Name -}}
                |{{- range $k, $v := .NetworkSettings.Networks}}
                    {{- "!"}}
                    {{- $k}} ({{printf "%.12s" .NetworkID}})
                    {{- print " " .IPAddress "/" .IPPrefixLen}}
                {{- end -}}
            ' -- "$container_id" \
            || true)
        local container_name networks
        IFS='|' read -r container_name networks <<< "$container_line"
        printf "            container: %s (%s)\n" \
            "$container_name" "${container_id:0:12}"
        printf "%s\n" "${networks:1}" | tr '!' $'\n' | while IFS= read -r; do
            printf "                       network: %s\n" "$REPLY"
        done
    fi
}

eval set -- "$(
    getopt -o s:,h --long stack:,help \
        -n "$(basename -- "$0")" -- "$@"
)"
p_stack=
while true; do
    case "$1" in
        -s|--stack) p_stack=$2
            shift 2
            ;;
        -h|--help) cat <<USAGE
Usage: $(basename -- "$0") [OPTIONS...]
Options:
    -s, --stack NAME
USAGE
            exit
            ;;
        --) shift
            break
            ;;
    esac
done

if [ -t 0 ]; then
    main | less
else
    main
fi
