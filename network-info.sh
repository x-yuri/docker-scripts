#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

main() {
    local networks=$(exd docker network ls \
        --format '{{.ID}}|{{.Name}}|{{.Driver}}|{{.Scope}}' \
        || true)
    networks=$(printf '%s\n' "$networks" | while IFS= read -r; do
        network_line=$REPLY
        IFS='|' read -r id rest <<< "$network_line"
        network_line_2=$(exd docker network inspect --format '
            {{- with .IPAM.Config}}{{range $i, $el := .}}
                {{- if $i}}!{{end}}
                {{- print "subnet: " .Subnet}}
                {{- print "  gateway: " .Gateway}}
            {{- end}}{{end -}}
            |{{.Ingress -}}
            |{{index .Options "com.docker.network.bridge.default_bridge" -}}
            |{{index .Options "com.docker.network.bridge.enable_icc" -}}
            |{{index .Options "com.docker.network.bridge.enable_ip_masquerade" -}}
            |{{- range $k, $el := .Containers}}
                {{- "!"}}
                {{- .Name}}
                {{- printf " (%.12s)" $k}}
                {{- print " " .IPv4Address}}
            {{- end -}}
            |{{range $i, $el := .Peers}}
                {{- if $i}}!{{end}}
                {{- print .Name " " .IP}}
            {{- end -}}
        ' -- "$id" \
        || true)
        printf "%s|%s\n" "$network_line" "$network_line_2"
    done)
# echo "'$networks'"
    local ml_name=$(max_len "$networks" 2)
    local ml_driver=$(max_len "$networks" 3)
    echo "$networks" | while IFS= read -r; do
        IFS='|' read -r id name driver scope config ingress default_bridge \
            icc ip_masq containers peers\
            <<< "$REPLY"
        printf "(%s) %-*s %-*s %s %s\n" \
            "$id" "$ml_name" "$name" "$ml_driver" "$driver" "$scope"

        flags=()
        if [[ $ingress == true ]]; then
            flags+=(ingress)
        fi
        if [[ $default_bridge == true ]]; then
            flags+=(default_bridge)
        fi
        if [[ $icc == true ]]; then
            flags+=(icc)
        fi
        if [[ $ip_masq == true ]]; then
            flags+=(ip_masq)
        fi
        if (( ${#flags[@]} )); then
            printf "    %s\n" "$(join_by ', ' "${flags[@]}")"
        fi

        if [[ $config ]]; then
            echo "$config" | tr '!' $'\n' | while IFS= read -r; do
                printf "    %s\n" "$REPLY"
            done
        fi

        if [[ $containers ]]; then
            printf "    containers:\n"
            echo "${containers:1}" | tr '!' $'\n' | while IFS= read -r; do
                printf "        %s\n" "$REPLY"
            done
        fi

        if [[ $peers ]]; then
            printf "    peers:\n"
            echo "$peers" | tr '!' $'\n' | while IFS= read -r; do
                printf "        %s\n" "$REPLY"
            done
        fi
    done
}

if [ -t 0 ]; then
    main | less
else
    main
fi
