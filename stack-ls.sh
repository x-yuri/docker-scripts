#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

exd docker stack ps \
    --filter desired-state=running \
    --format '{{.ID}}' \
    -- "$STACK" \
        | while IFS= read -r; do
            task_id=$REPLY
            task_line=$(exd docker inspect --format '
                {{- .ServiceID -}}
                |{{.Slot -}}
                |{{with .Status}}{{if index . "ContainerStatus"}}
                    {{- .ContainerStatus.ContainerID}}
                {{- end}}{{end -}}
            ' -- "$task_id" \
            || true)
            if ! [[ $task_line ]]; then continue; fi
            IFS='|' read -r task_svc_id task_no container_id <<< "$task_line"

            svc_name=$(exd docker service inspect \
                --format '{{.Spec.Name}}' \
                -- "$task_svc_id" \
                || true)
            svc_name=${svc_name#${STACK}_}

            printf "%s: %s\n" "$svc_name.$task_no" "${container_id:0:12}"
        done
