#!/bin/bash
KUBE_APISERVER="https://{% if is_mutil_master %}{{ virtual_ip }}{% if ha_proxy_port is defined %}{{ ha_proxy_port }}{% else %}:7443{% endif %}{% else %}{{ master_list[0] }}:6443{% endif %}"

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

## kube-controller-manager.kubeconfig begin ...
KUBE_CONFIG="{{ install_dir }}/kubernetes/conf/kube-controller-manager.kubeconfig"
KUBE_USER="kube-controller-manager"
KUBE_CERT_NAME="kube-controller-manager.pem"
KUBE_KEY_NAME="kube-controller-manager-key.pem"
set_kubeconfig
## kube-controller-manager.kubeconfig end ...

## kube-scheduler.kubeconfig begin ...
KUBE_CONFIG="{{ install_dir }}/kubernetes/conf/kube-scheduler.kubeconfig"
KUBE_USER="kube-scheduler"
KUBE_CERT_NAME="kube-scheduler.pem"
KUBE_KEY_NAME="kube-scheduler-key.pem"
set_kubeconfig
## kube-scheduler.kubeconfig end ...

## admin user kubeconfig begin ...
mkdir $HOME/.kube
KUBE_CONFIG="$HOME/.kube/config"
KUBE_USER="cluster-admin"
KUBE_CERT_NAME="admin.pem"
KUBE_KEY_NAME="admin-key.pem"
set_kubeconfig
## admin user kubeconfig end ...