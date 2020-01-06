#!/usr/bin/env bash
set -eu

prj_dir=$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")
. "$prj_dir/common.sh"

mkdir -p ~/docker-snapshots
timestamp=$(date +%Y%m%d-%H%M%S)
dir=~/docker-snapshots/$timestamp
mkdir "$dir"

docker info --format '{{json .}}' | jq . > "$dir/docker-info.json"
docker node ls --format '{{json .}}' | jq . > "$dir/docker-node-ls.json"
docker node ls --format '{{.ID}} {{.Hostname}}' \
    | while read -r id hostname; do
        docker node ps "$id" --format '{{json .}}' | jq . > "$dir/docker-node-ps-$hostname.json"
    done
docker container ls --all --format '{{json .}}' | jq . > "$dir/docker-container-ls.json"
docker stack ls --format '{{json .}}' | jq . > "$dir/docker-stack-ls.json"
docker stack ls --format '{{.Name}}' \
    | while IFS= read -r stack; do
        docker stack ps "$stack" --format '{{json .}}' | jq . > "$dir/docker-stack-ps-$stack.json"
    done
docker service ls --format '{{json .}}' | jq . > "$dir/docker-service-ls.json"
docker service ls --format '{{.ID}} {{.Name}}' \
    | while read -r id name; do
        docker service ps "$id" --format '{{json .}}' | jq . > "$dir/docker-service-ps-$name.json"
    done
docker network ls --format '{{json .}}' | jq . > "$dir/docker-network-ls.json"
docker volume ls --format '{{json .}}' | jq . > "$dir/docker-volume-ls.json"
docker image ls --all --format '{{json .}}' | jq . > "$dir/docker-image-ls.json"
ip a > "$dir/ip-a.txt"

mkdir "$dir/containers"
docker container ls --all --format '{{.ID}}' \
    | while IFS= read -r; do
        docker container inspect "$REPLY" > "$dir/containers/$REPLY.json"
    done

mkdir "$dir/tasks"
docker stack ls --format '{{.Name}}' \
    | while IFS= read -r stack; do
        docker stack ps "$stack" --format '{{.ID}}' \
            | while IFS= read -r task_id; do
                docker inspect "$task_id" > "$dir/tasks/$task_id.json"
            done
    done

mkdir "$dir/services"
docker service ls --format '{{.ID}}' \
    | while IFS= read -r svc_id; do
        docker service inspect "$svc_id" > "$dir/services/$svc_id.json"
    done

mkdir "$dir/networks"
docker network ls --format '{{.ID}}' \
    | while IFS= read -r net_id; do
        docker network inspect "$net_id" > "$dir/networks/$net_id.json"
    done

mkdir "$dir/volumes"
docker volume ls --format '{{.Name}}' \
    | while IFS= read -r vol_id; do
        docker volume inspect "$vol_id" > "$dir/volumes/$vol_id.json"
    done
