#!/usr/bin/env bash

function create-kube-hollow-node-resources {
  # Create kubemark namespace.
#   if kubectl get ns | grep -Fq "kubemark"; then
#   	 kubectl delete ns kubemark
#   	 while kubectl get ns | grep -Fq "kubemark"
#   	 do
#   	 	sleep 10
#   	 done
#   fi
  kubectl create -f "${RESOURCE_DIRECTORY}/kubemark-ns.json"

  # Create configmap for configuring hollow- kubelet, proxy.
  echo 'content.type' ${TEST_CLUSTER_API_CONTENT_TYPE}
  kubectl create configmap "node-configmap" --namespace="kubemark" \
    --from-literal=content.type="${TEST_CLUSTER_API_CONTENT_TYPE}" \

  # Create secret for passing kubeconfigs to kubelet, kubeproxy.
  kubectl create secret generic "kubeconfig" --type=Opaque --namespace="kubemark" \
    --from-file=kubelet.kubeconfig="${KUBEMARK_KUBELET_KUBECONFIG_PATH}" \
    --from-file=kubeproxy.kubeconfig="${KUBEMARK_KUBEPROXY_KUBECONFIG_PATH}" 

  # Create addon pods.
  # Create the replication controller for hollow-nodes.
  # We allow to override the NUM_REPLICAS when running Cluster Autoscaler.
  NUM_REPLICAS=${NUM_REPLICAS:-${NUM_NODES}}
  sed "s/{{numreplicas}}/${NUM_REPLICAS}/g" "${RESOURCE_DIRECTORY}/hollow-node_template.yaml" > "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  proxy_cpu=20
  if [ "${NUM_NODES}" -gt 1000 ]; then
    proxy_cpu=50
  fi
  proxy_mem_per_node=50
  proxy_mem=$((100 * 1024 + ${proxy_mem_per_node}*${NUM_NODES}))
  sed -i'' -e "s/{{HOLLOW_PROXY_CPU}}/${proxy_cpu}/g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s/{{HOLLOW_PROXY_MEM}}/${proxy_mem}/g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s'{{kubemark_image_registry}}'${KUBEMARK_IMAGE_REGISTRY}'g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s/{{kubemark_image_tag}}/${KUBEMARK_IMAGE_TAG}/g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s/{{master_ip}}/${MASTER_IP}/g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s/{{hollow_kubelet_params}}/${HOLLOW_KUBELET_TEST_ARGS}/g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s/{{hollow_proxy_params}}/${HOLLOW_PROXY_TEST_ARGS}/g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"
  sed -i'' -e "s'{{kubemark_mig_config}}'${KUBEMARK_MIG_CONFIG:-}'g" "${RESOURCE_DIRECTORY}/hollow-node.yaml"

  kubectl apply -f "${RESOURCE_DIRECTORY}/hollow-node.yaml" --namespace="kubemark"
}

# Wait until all hollow-nodes are running or there is a timeout.
function wait-for-hollow-nodes-to-run-or-timeout {
  echo -n "Waiting for all hollow-nodes to become Running"
  start=$(date +%s)
  nodes=$(kubectl --kubeconfig="${KUBEMARK_KUBECONFIG}" get node 2> /dev/null) || true
  ready=$(($(echo "${nodes}" | grep -v "NotReady" | wc -l) - 1))
  
  until [[ "${ready}" -ge "${NUM_REPLICAS}" ]]; do
    echo -n "."
    sleep 1
    now=$(date +%s)
    # Fail it if it already took more than 30 minutes.
    if [ $((now - start)) -gt 1800 ]; then
      echo ""
      echo -e "${color_red} Timeout waiting for all hollow-nodes to become Running. ${color_norm}"
      # Try listing nodes again - if it fails it means that API server is not responding
      if kubectl --kubeconfig="${KUBEMARK_KUBECONFIG}" get node &> /dev/null; then
        echo "Found only ${ready} ready hollow-nodes while waiting for ${NUM_NODES}."
      else
        echo "Got error while trying to list hollow-nodes. Probably API server is down."
      fi
      pods=$(kubectl get pods -l name=hollow-node --namespace=kubemark) || true
      running=$(($(echo "${pods}" | grep "Running" | wc -l)))
      echo "${running} hollow-nodes are reported as 'Running'"
      not_running=$(($(echo "${pods}" | grep -v "Running" | wc -l) - 1))
      echo "${not_running} hollow-nodes are reported as NOT 'Running'"
      echo "${pods}" | grep -v Running
      exit 1
    fi
    nodes=$(kubectl --kubeconfig="${KUBEMARK_KUBECONFIG}" get node 2> /dev/null) || true
    ready=$(($(echo "${nodes}" | grep -v "NotReady" | wc -l) - 1))
  done
  echo -e "${color_green} Done!${color_norm}"
}

function make-node-label {
    echo -n "make node label"
    if [[ "${NUM_REPLICAS}" -eq 0 ]]; then
        return
    fi
    node_names=$(kubectl --kubeconfig="${KUBEMARK_KUBECONFIG}" get node | grep hollow-node | awk '{print $1}' 2> /dev/null) || true
    for node_name in $node_names; do
        echo 'node name' $node_name
        kubectl --kubeconfig="${KUBEMARK_KUBECONFIG}" label --overwrite node $node_name kubernetes.io/role=node
    done
    echo -e "${color_green} Done!${color_norm}"
}



TMP_ROOT="$(dirname "${BASH_SOURCE}")/../.."
KUBE_ROOT=$(readlink -e "${TMP_ROOT}" 2> /dev/null || perl -MCwd -e 'print Cwd::abs_path shift' "${TMP_ROOT}")
KUBEMARK_DIRECTORY="${KUBE_ROOT}/cmd/kubemark"
RESOURCE_DIRECTORY="${KUBEMARK_DIRECTORY}/templates"

source "${KUBE_ROOT}/cmd/kubemark/default_config.sh" 


echo "Creating kube hollow node resources"
create-kube-hollow-node-resources

wait-for-hollow-nodes-to-run-or-timeout

make-node-label

# Celebrate
echo ""
echo -e "${color_blue}SUCCESS${color_norm}"
exit 0