#!/usr/bin/env bash

image=$1
if [ -z "$image" ]; then
    echo 'pls input image'
    exit 1
fi

nodes=$(kubectl get node | grep node | awk '{print $1}')

for node in $nodes
do
    ssh -tt -o "StrictHostKeyChecking no" $node -i /root/new "docker rmi $image"
done