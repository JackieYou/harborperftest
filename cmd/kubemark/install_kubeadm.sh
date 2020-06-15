#!/usr/bin/env bash
IINIT_CONTROL_PLANE_IP=10.21.128.15
CONTROL_PLANE_IPS="10.21.128.15 10.21.128.6 10.21.128.22"

# init_kubeadm_config
cat <<EOF > /root/kubeadm-config
apiVersion: kubeadm.k8s.io/v1beta1
kind: ClusterConfiguration
kubernetesVersion: v1.13.4
apiServer:
  certSANs:
  - "10.21.128.15"
  - "10.21.128.6"
  - "10.21.128.22"
  - "10.21.1.3"
controlPlaneEndpoint: "10.21.1.3:6443"
imageRepository: registry.cn-beijing.aliyuncs.com/hsxue
EOF

# install kubernetes.repo
cat <<EOF > /root/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF


for host in ${CONTROL_PLANE_IPS}; do
    echo '---------------------- init node' $host '---------------------------'
    scp -i new /root/kubeadm-config root@$host:/root
    scp -i new /root/kubernetes.repo root@$host:/root
    ssh -i new root@$host "mv /root/kubernetes.repo /etc/yum.repos.d/"
    ssh -i new root@$host "yum install -y yum-utils device-mapper-persistent-data lvm2 && \
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
        yum update -y"
    echo 'install docker'
    ssh -i new root@$host "yum install -y docker-ce docker-ce-cli containerd.io && \
        systemctl start docker && systemctl enable docker"

    echo 'install kubectl'    
    ssh -i new root@$host "yum install -y kubectl-1.13.4"

    echo 'install kubelet'   
    ssh -i new root@$host "yum install -y kubelet-1.13.4"

    echo 'install kubeadm'   
    ssh -i new root@$host "yum install -y kubeadm-1.13.4"
    
    echo 'init net'
    ssh -i new root@$host "echo 1 >> /proc/sys/net/bridge/bridge-nf-call-iptables && \
        echo 1 >> /proc/sys/net/ipv4/ip_forward"
done


# init master
# kubeadm init --config=/root/kubeadm-config --node-name=master

# join master
# kubeadm join 10.21.1.3:6443 --token $TOKEN --discovery-token-ca-cert-hash $HASH --experimental-control-plane --node-name=master


## master 初始化完成后，将证书拷贝到其他待初始节点
function cpcrt {
    USER=root # customizable
    CONTROL_PLANE_IPS="10.21.128.6 10.21.128.22"
    for host in ${CONTROL_PLANE_IPS}; do
        ssh -i new root@$host "mkdir -p /etc/kubernetes/pki/etcd" 

        scp -i new /etc/kubernetes/pki/ca.crt "${USER}"@$host:/etc/kubernetes/pki/
        scp -i new /etc/kubernetes/pki/ca.key "${USER}"@$host:/etc/kubernetes/pki/
        scp -i new /etc/kubernetes/pki/sa.key "${USER}"@$host:/etc/kubernetes/pki/
        scp -i new /etc/kubernetes/pki/sa.pub "${USER}"@$host:/etc/kubernetes/pki/
        scp -i new /etc/kubernetes/pki/front-proxy-ca.crt "${USER}"@$host:/etc/kubernetes/pki/
        scp -i new /etc/kubernetes/pki/front-proxy-ca.key "${USER}"@$host:/etc/kubernetes/pki/
        scp -i new /etc/kubernetes/pki/etcd/ca.crt "${USER}"@$host:/etc/kubernetes/pki/etcd-ca.crt
        scp -i new /etc/kubernetes/pki/etcd/ca.key "${USER}"@$host:/etc/kubernetes/pki/etcd-ca.key
        scp -i new /etc/kubernetes/admin.conf "${USER}"@$host:/etc/kubernetes/pki/
    done
}