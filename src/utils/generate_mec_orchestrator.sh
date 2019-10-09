#!/usr/bin/env bash


# INSTALL SNAPD - LXD - DOCKER
# CREATE MEAO/YAKS container (DOCKER)
# CREATE TEST MEC Container (LXD)

# docker swarm init --advertise-addr 192.168.100.134

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--test)
    TEST=true
    shift;;
    -b|--build)
    BUILD=false
    shift;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done

docker image rm fog05/yaks --force
docker image rm fog05/meao --force


if [ $BUILD ]; then
    make -C ocaml/mec_meao_mepmv clean
    make -C ocaml/mec_meao_mepmv
else
    mkdir -p ocaml/mec_meao_mepmv/_build/default/meao
    curl -L -o /tmp/meao.tar.gz https://www.dropbox.com/s/91fw8iromfz3su6/meao.tar.gz
    tar -xzvf /tmp/meao.tar.gz -C ocaml/mec_meao_mepmv/_build/default/meao
    rm -rf /tmp/meao.tar.gz
fi



docker network rm fog05-meaonet
docker network create -d overlay --attachable fog05-meaonet


sg docker -c "docker build . -f ./docker/Dockerfile-yaks -t fog05/yaks --no-cache"
sg docker -c "docker build . -f ./docker/Dockerfile-meao -t fog05/meao --no-cache"

docker stack deploy -c ./docker/meao/docker-compose.yaml meao


if [ $TEST ]; then
    if [ $BUILD ]; then
        make -C ocaml/mec_platform clean
        make -C ocaml/mec_platform
    else
        mkdir -p ocaml/mec_platform/_build/default/me_platform
        curl -L -o /tmp/mecp.tar.gz https://www.dropbox.com/s/gx32gnr1y4gcm2w/mecp.tar.gz
        tar -xzvf /tmp/mecp.tar.gz -C ocaml/mec_platform/_build/default/me_platform
        rm -rf /tmp/mecp.tar.gz
    fi
    ./generate_mec_platform.sh
    MEC_IP=$(lxc list -c4 --format json plat |  jq -r '.[0].state.network.eth0.addresses[0].address')
    PL="{\"platformId\":\"testp\", \"endpoint\":{\"uris\":[\"/exampleAPI/mm5/v1\"], \"alternative\":{},\"addresses\":[{\"host\":\"$MEC_IP\",\"port\":8091}]}}"
    curl -X POST http://127.0.1:8071/exampleAPI/mm1/v1/platforms -d "$PL"
fi


sleep 5

echo "Done!"
