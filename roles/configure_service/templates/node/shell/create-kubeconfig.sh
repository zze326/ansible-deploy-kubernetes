#!/bin/bash
KUBE_APISERVER="https://{% if is_mutil_master %}{{ virtual_ip }}{% if ha_proxy_port is defined %}{{ ha_proxy_port }}{% else %}:7443{% endif %}{% else %}{{ master_list[0] }}:6443{% endif %}"

KUBE_CONFIG="{{ install_dir }}/kubernetes/conf/bootstrap.kubeconfig"
TOKEN="{{ kubelet_bootstrap_token }}"

## kubelet-bootstrap.kubeconfig begin ...
kubectl config set-cluster kubernetes \
  --certificate-authority={{ install_dir }}/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-credentials "kubelet-bootstrap" \
  --token=${TOKEN} \
  --kubeconfig=${KUBE_CONFIG}
kubectl config set-context default \
  --cluster=kubernetes \
  --user="kubelet-bootstrap" \
  --kubeconfig=${KUBE_CONFIG}
kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
## kubelet-bootstrap.kubeconfig end ...

set_kubeconfig(){
  kubectl config set-cluster kubernetes \
    --certificate-authority={{ install_dir }}/kubernetes/ssl/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=${KUBE_CONFIG}
  kubectl config set-credentials ${KUBE_USER} \
    --client-certificate={{ install_dir }}/kubernetes/ssl/${KUBE_CERT_NAME} \
    --client-key={{ install_dir }}/kubernetes/ssl/${KUBE_KEY_NAME} \
    --embed-certs=true \
    --kubeconfig=${KUBE_CONFIG}
  kubectl config set-context default \
    --cluster=kubernetes \
    --user=${KUBE_USER} \
    --kubeconfig=${KUBE_CONFIG}
  kubectl config use-context default --kubeconfig=${KUBE_CONFIG}
}

## kube-proxy.kubeconfig begin ...
KUBE_CONFIG="{{ install_dir }}/kubernetes/conf/kube-proxy.kubeconfig"
KUBE_USER="kube-proxy"
KUBE_CERT_NAME="kube-proxy.pem"
KUBE_KEY_NAME="kube-proxy-key.pem"
set_kubeconfig
## kube-proxy.kubeconfig end ...
