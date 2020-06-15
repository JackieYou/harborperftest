#!/usr/bin/env bash

nodes=$(kubectl get node | grep node | awk '{print $1}')

for node in $nodes
do
    ssh -o "StrictHostKeyChecking no" $node -i /root/new << eof


if [ -f "/etc/systemd/system/docker.service.d/http-proxy.conf" ]; then
    rm -rf /etc/systemd/system/docker.service.d/http-proxy.conf
    systemctl daemon-reload
fi

if [ ! -f "/root/daemon.json.bak.test" ]; then
    echo "set docker------" $node

    if [ -f "/etc/docker/daemon.json" ]; then
        mv -f /etc/docker/daemon.json /root/daemon.json.bak.test
    fi
    cat > daemon.json.harbor << eeooff
{"data-root":"/data/docker","insecure-registries":["10.254.0.0/16","mirror.kce.sdns.ksyun.com", "10.21.1.4"]}
eeooff

    mv daemon.json.harbor /etc/docker/daemon.json

    systemctl restart docker
fi

exit
eof
done