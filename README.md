## 1. get perftest binary

```
docker build -t harbortest:latest -f Dockerfile .
docker run --name harbortest harbortest:latest go build
docker cp harbortest:/go/src/perftest/perftest .
```

## 2. test

```
./perftest harbor pullimage –image <testimages> –kubeconfig /root/.kube/config
```

## 3. clear image cache

```
.harbortest/cmd/harbor/script/clear-image-cache.sh <testimages>
```
