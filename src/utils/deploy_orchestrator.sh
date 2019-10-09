#!/usr/bin/env bash


# INSTALL SNAPD - LXD - DOCKER - JQ
# CREATE MEAO/YAKS container (DOCKER)
# CREATE TEST MEC Container (LXD)

# docker swarm init --advertise-addr <one of machine address>
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--test)
    TEST=true
    shift;;
    *)
    POSITIONAL+=("$1")
    shift
    ;;
esac
done

docker image rm fog05/yaks:5gcity --force
docker image rm fog05/meao --force

docker network rm fog05-meaonet
docker network create -d overlay --attachable fog05-meaonet


docker stack deploy -c ./docker/meao/docker-compose.yaml meao


if [ $TEST ]; then


    curl -L -o /tmp/plat.tar.gz https://www.dropbox.com/s/5fleutve5550oi6/plat.tar.gz
    lxc image import /tmp/plat.tar.gz --alias plat
    rm /tmp/plat.tar.gz
    sudo ip link del mecbuildbr
    sudo ip link add mecbuildbr type bridge
    sudo ip link set mecbuildbr up



    lxc profile copy default mecp
    lxc profile device add mecp eth1 nic nictype=bridged parent=mecbuildbr
    lxc launch plat plat -p mecp

    sleep 2

    lxc file push ./ocaml/mec_platform/etc/ip_replace.sh plat/tmp/
    lxc exec plat --  /tmp/ip_replace.sh
    lxc exec plat -- systemctl restart nginx
    lxc exec plat -- touch /tmp/dynhosts
    lxc exec plat -- chmod 0666 /tmp/dynhosts

    sleep 5


    MEC_IP=$(lxc list -c4 --format json plat |  jq -r '.[0].state.network.eth0.addresses[0].address')
    PL="{\"platformId\":\"testp\", \"endpoint\":{\"uris\":[\"/exampleAPI/mm5/v1\"], \"alternative\":{},\"addresses\":[{\"host\":\"$MEC_IP\",\"port\":8091}]}}"
    curl -X POST http://127.0.1:8071/exampleAPI/mm1/v1/platforms -d "$PL"
fi

echo "Done!"
