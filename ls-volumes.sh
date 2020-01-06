#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

print_container() {
    local id=$1 l=${2-0}
    local name=$(docker container inspect "$id" --format '{{.Name}}' \
        | sed -E 's/^\///')
    printf '%*s%s (%s)\n' "$(( l * 4 ))" '' "$id" "$name"
}

declare -A volume_dict
for id in $(docker container ls --all --format '{{.ID}}'); do
    volumes=$(docker container inspect "$id" --format '{{range .Mounts}}
        {{- if eq .Type "volume"}}
            {{- .Name}}{{"\n"}}
        {{- end}}
    {{- end}}')
    if [[ $volumes ]]; then
        volume_dict[$id]=$volumes
    fi
done

for id in $(docker volume ls --format '{{.Name}}'); do
    echo "$id"
    for container_id in "${!volume_dict[@]}"; do
        q_id=$(qe "$id")
        if printf '%s\n' "${volume_dict[$container_id]}" \
        | egrep "^$q_id$" &> /dev/null; then
            print_container "$container_id" 1
        fi
    done
done
exit

# group by container

for id in $(docker container ls --all --format '{{.ID}}'); do
    volumes=$(docker container inspect "$id" --format '{{range .Mounts}}
        {{- if eq .Type "volume"}}
            {{- .Name}}{{"\n"}}
        {{- end}}
    {{- end}}')
    name=$(docker container inspect "$id" --format '{{.Name}}' \
        | sed -E 's/^\///')
    if [[ $volumes ]]; then
        printf '%s\n' "$name (${id:0:12})"
        printf '%s\n' "$volumes" | sed -E 's/^/    /'
    fi
done
