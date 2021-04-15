# Ansible 二进制部署 Kubernetes
## 功能说明

- [x] CNI 插件自动部署；
- [x] Dashboard UI 自动部署；
- [x] Metrics Server 自动部署；
- [x] core DNS 自动部署；
- [x] 一键加入新的 Node；
- [x] Ingress-Controller 自动部署；
- [x] 多 Master 高可用（Keepalived + Nginx）一键部署；
- [x] 透明支持 CentOS 7 和 Ubuntu 16/18；
- [x] 多版本兼容（已通过测试的版本有：`v1.17.x`、`v1.18.x`、`v1.19.x`、`v1.20.x`）；
- [x] 支持自定义 Service 和 Pod 网段；
- [x] 支持 HAProxy Ingress Controller 和 Nginx Ingress Controller 可选部署；
- [x] 支持 CNI 网络插件可选部署（Flannel Or Calico）；
- [x] 支持容器运行时可选部署（Containerd Or Docker）；
- [x] 支持最新 Kubernetes 1.20.x 版本的一键部署；


> 如有疑惑或建议可提 ISSUE 或在 [此链接](https://www.zze.xyz/archives/kubernetes-deploy-binary-mutil-master.html) 下留言。
>
> 这里我在 CentOS 7.8、Ubuntu 16.04 和 Ubuntu 18.04 上进行了测试，完全能够一键跑完。
>
> <font color='blue'>用的顺手可以点一下右上角 Star 哦~~</font>
> 
> 要注意的是，如果你使用的是 Ubuntu，那么需要先在所有节点上装上 python 环境，因为 Ansible 依赖被控端的 python，而 Ubuntu 默认是没有的（CentOS 默认有），执行 `sudo apt install python-minimal` 安装即可。

## 环境准备

### 离线二进制包下载

链接：https://pan.baidu.com/s/1uJwhrINaO-SlTYSjeVOktw  提取码：`q3n1`。

该链接提供的下载目录结构如下：

```bash
├── kubernetes-server-linux-amd64-v1.17.13.tar.gz
├── kubernetes-server-linux-amd64-v1.18.10.tar.gz
├── kubernetes-server-linux-amd64-v1.19.3.tar.gz
├── kubernetes-server-linux-amd64-v1.20.5.tar.gz
└── packages
    ├── cfssl
    │   ├── cfssl-certinfo_linux-amd64
    │   ├── cfssljson_linux-amd64
    │   └── cfssl_linux-amd64
    ├── cni-plugins-linux-amd64-v0.8.7.tgz
    ├── docker-19.03.9.tgz
    └── etcd-v3.4.13-linux-amd64.tar.gz
```

要下载的文件：

- `packages` 目录下都是构建 Kubernetes 集群必需的组件和工具，直接下载该目录；
- `kubernetes-server-linux-amd64-v*.tar.gz` 为对应版本的 Kubernetes 二进制包，选择一个你需要的版本即可，来源于官网未作任何修改，更多版本可[点击此链接](https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG)自行选择合适的版本；

下载好后它们上传到服务器，并将 Kubernetes 二进制包移动到 `packages` 目录下，我这里选择的是 `v1.19.3` 版本的二进制包，所以最终 `packages` 的目录结构如下：

```bash
$ tree packages/
packages/
├── cfssl
│   ├── cfssl-certinfo_linux-amd64
│   ├── cfssljson_linux-amd64
│   └── cfssl_linux-amd64
├── cni-plugins-linux-amd64-v0.8.7.tgz
├── containerd-1.4.4-linux-amd64.tar.gz
├── crictl-v1.20.0-linux-amd64.tar.gz
├── docker-19.03.9.tgz
├── etcd-v3.4.13-linux-amd64.tar.gz
└── kubernetes-server-linux-amd64-v1.20.5.tar.gz

1 directory, 9 files
```

我这里将 `packages` 目录放到服务器的 `/opt` 目录下，所以最终 `packages` 目录的绝对路径为 `/opt/packages` ，这个路径要和后面 `hosts.yml` 中的 `package_dir` 变量值设置的路径对应。

### 安装 Ansible 和 Git
安装 Ansible 和 Git，我这里使用的是 CentOS 7.8 做演示，直接使用 YUM 安装即可：

```bash
$ yum install ansible git -y
```
如果使用的是 Ubuntu，那么此时不能直接使用 `apt` 来安装 Ansible，因为默认的版本太低了，需要执行下面的操作添加源来安装新版本的 Ansible：
```
$ sudo apt update
$ sudo apt-get install software-properties-common
$ sudo apt-add-repository --yes  ppa:ansible/ansible:2.7.6
$ sudo apt update
$ sudo apt-get install ansible
```

取消 Ansible 检查 Key（此步骤如果有疑问可百度或 Google）：
```bash
$ vim /etc/ansible/ansible.cfg
# 取消此行注释
host_key_checking = False
```
## 结构说明
安装完成后 clone 当前 Project：
```bash
$ git clone https://github.com/zze326/kubernetes-deploy-ansible.git
```
克隆完成后目录结构如下：
```bash
$ ls kubernetes-deploy-ansible/
hosts.yml  manifests  README.md  roles  run.yml
```
下面对上述几个文件做一下说明：
- `hosts.yml`：主机清单以及配置；
- `manifests`：存放 Kubernetes 使用的 manifests，如 CoreDNS、Flannel、Dashboard 等，后续所有使用到的 manifests 都将放在这里方便配置改动；
- `roles`：标准的 Ansible 角色目录；
- `run.yml`：此 Ansible 的入口 Playbook；

## 配置说明

为让部署操作简单易懂，我将所有可能修改的配置都放到了 `hosts.yml` 文件中，下面对 `hosts.yml` 配置进行说明：

```yaml
all:
  vars:
    # SSH 用户名
    ansible_user: root
    # SSH 密码
    ansible_ssh_pass: root1234
    # 用户的 sudo 提权密码
    ansible_sudo_pass: root1234
    # 标识是否是多 Master 架构
    is_mutil_master: yes
    # 多 Master 架构时会使用 Nginx 来四层代理多个 Master 中的 APIServer，Nginx 四层代理可能有多个，这多个代理之间使用 Keepalived 提供 VIP 进行高可用，该字段就是用来设置该 VIP
    virtual_ip: 10.0.1.200
    # Keepalived VIP 绑定的网卡，如果多个主机网卡名不同，则可定义在对应的主机变量下
    virtual_ip_device: eth0
    # Service 网络网段，默认为 10.0.0.0/24
    service_net: 10.0.0.0/24
    # Pod 网络网段，默认为 10.244.0.0/16
    pod_net: 10.244.0.0/16
    # 多主架构时 Nginx 代理 APIServer 使用的端口，如果代理和 APIServer 在同一台主机，则不可为 6443，因为 APIServer 的默认端口为 6443
    proxy_master_port: 7443
    # 应用的安装目录，kube-apiserver、kube-controller-manager、kube-scheduler、kubelet、kube-proxy、nginx、cni、docker、keepalived 等这些应用程序的安装目录
    install_dir: /opt/apps/
    # 二进制包的存放目录，就是上面的压缩包 kubernetes-1.19.0-zze-ansible.bin.tar.gz 解压到的目录
    package_dir: /opt/packages/
    # 证书存放目录，kubernetes 和 ETCD 的运行需要一些证书，这里先生成所有证书保存到这个目录，然后从这里分发到各个需要对应证书的节点，要求当前运行 Ansible 的用户拥有该目录的写权限，否则证书无法生成（或者使用 sudo 执行 ansible-playbook）
    tls_dir: /opt/k8s_tls
    # 提供 NTP 时间同步服务的主机，将会添加到定时任务，因为考虑到可能会使用内建的时间服务器，所以把这个地址提取了出来
    ntp_host: ntp1.aliyun.com
    # 是否可以连接到 internet，如果可以，则会自动装 ntpdate 等工具，该字段暂时只有控制联网安装一些软件的功能，主要预留为后续离线部署开关
    have_network: yes
    # 是否修改 yum 源或 apt 源为阿里云，支持 CentOS 7、Ubuntu 16、Ubuntu 18，注意，会清空原有的源配置
    replace_repo: yes
    # API Server 证书预留 IP 列表，默认情况下：
    # - 单 master 只会添加 master 节点 IP 到证书；
    # - 多 master 会添加 master 节点 IP 和 ha_proxy 节点 IP 到证书
    # 所以这里可以放一些将来打算扩展作为 Master 的主机的 IP
    api_server_ext_ip_list:
    - 10.0.1.210
    - 10.0.1.211
    - 10.0.1.212
    # 可信任的 Docker 镜像仓库地址，默认仅允许 HTTPS 仓库，添加后可支持 HTTP，用于渲染 /opt/apps/docker/conf/daemon.json
    docker_insecure_registries:
    - 10.0.1.122
    - 10.0.1.123
    # Docker 镜像仓库加速地址，可选，注释后默认为我的阿里云镜像加速地址
    docker_registry_mirrors: https://7hsct51i.mirror.aliyuncs.com
    # kubelet 用来发送签发证书请求用的 Token，可通过 head -c 16 /dev/urandom | od -An -t x | tr -d ' ' 生成
    kubelet_bootstrap_token: 8fba966b6e3b5d182960a30f6cb94428
    # Kubernetes 使用的 pause 镜像，无需解释
    pause_image: registry.cn-shenzhen.aliyuncs.com/zze/pause:3.2
    # Dashboard Web UI 使用的端口 30000-32767 之间
    dashboard_port: 30001
    # 保存 Dashboard 访问 Token 的文件名，在当前 hosts.yml 同级目录下
    dashboard_token_file: dashboard_token.txt
    # 选择 Ingress Controller 的类型，目前可选 nginx 和 haproxy，可使用在 hosts 节对应主机下添加 ingress: yes 标识仅在该主机上部署 Ingress-Controller，如果没有标识则默认在所有 Node 上部署，注释此变量则不会部署 Ingress Controller
    ingress_controller_type: nginx
    # 选择 CNI 网络插件的类型，目前可选 flannel 和 calico，calico 默认使用 BGP 模式，注释此变量则不会部署 CNI 网络插件
    cni_type: flannel
    # 选择 kubelet 使用的容器运行时，先支持 docker 和 containerd，kubernetes 1.20+ 后推荐使用 containerd，即便设置 containerd 为容器运行时，为方便使用依旧会在所有 node 上部署 docker
    container_runtime: containerd
  # 下面为主机清单配置，只不过是 YAML 格式，每一个 IP 代表一个主机，其下级字段为对应的主机变量，即如下配置有三个主机
  hosts:
    10.0.1.201:
      # 主机名，会自动设置对应节点的主机名为该属性值，并且 Kubernetes 的节点名称也会使用它
      hostname: k8s-master1
      # 标识当前节点是否是 Master 节点
      master: yes
      # 标识当前节点时 Node 节点
      node: yes
      # 标识当前节点是否是 ETCD 节点
      etcd: yes
      # 标识当前节点是否用作 API Server 的代理节点，如果启用，将会在该节点上运行 Nginx 和 Keepalived（仅在多 Master 时生效）
      proxy_master: yes
      # 当前节点用作代理节点时会启动一个 Keepalived，该字段用来指定 Keepalived 配置中的优先级，优先级越高，VIP 则越优先绑定到该节点
      proxy_priority: 110
    10.0.1.202:
      hostname: k8s-master2
      node: yes
      master: yes
      etcd: yes
      proxy_master: yes
      proxy_priority: 100
    10.0.1.203: 
      hostname: k8s-node1
      etcd: yes
      node: yes
      ingress: yes
```
从上述配置可以看出：
- 上述配置最终会创建一个三节点的双 Master 三 Node 的 Kubernete 集群，并且每个节点也是 ETCD 集群中的一个成员；
- `10.0.1.201` 和 `10.0.1.202` 作为 Master 的同时也会作为 API Server 的代理节点；
- `10.0.1.201` 的优先级（`proxy_priority`）比 `10.0.1.202` 高，所以最终 Keepalived 管理的 VIP 会优先绑定到 `10.0.1.201` 上；

## 开始部署

按需修改 `hosts.yml`，大部分配置保持默认即可，几乎仅需要修改节点 IP 和密码，我这里修改完配置之后 `hosts.yml` 内容如下：

```yaml
all:
  vars:
    ansible_user: root
    ansible_ssh_pass: root1234
    ansible_sudo_pass: root1234
    is_mutil_master: yes
    virtual_ip: 10.0.1.200
    virtual_ip_device: eth0
    proxy_master_port: 7443
    install_dir: /opt/apps/
    package_dir: /opt/packages/
    tls_dir: /opt/k8s_tls
    ntp_host: ntp1.aliyun.com
    have_network: yes
    replace_repo: yes
    docker_registry_mirrors: https://7hsct51i.mirror.aliyuncs.com
    kubelet_bootstrap_token: 8fba966b6e3b5d182960a30f6cb94428
    pause_image: registry.cn-shenzhen.aliyuncs.com/zze/pause:3.2
    dashboard_port: 30001
    dashboard_token_file: dashboard_token.txt
    ingress_controller_type: haproxy
    cni_type: flannel
  hosts:
    10.0.1.201:
      hostname: k8s-master1
      master: yes
      node: yes
      etcd: yes
      proxy_master: yes
      proxy_priority: 110
    10.0.1.202:
      hostname: k8s-master2
      master: yes
      node: yes
      etcd: yes
      proxy_master: yes
      proxy_priority: 100
    10.0.1.203: 
      hostname: k8s-node1
      etcd: yes
      node: yes
      ingress: yes
```

修改完成后执行下面命令开始部署操作：

```bash
$ sudo ansible-playbook -i hosts.yml run.yml
...
TASK [deploy_manifests : 打印 token 信息] ***************************************************************************************************************************************************************
ok: [10.0.1.201] => {
    "msg": "token: eyJhbGciOiJSUzI1NiIsImtpZCI6IlVnU2Z6aTM1a0I1S3J5T04yVmMwQTNoWC0xZnF2RThybXBzQU9pcWhUYnMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4tamdzZHQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiMWI3YzcxMWYtMGQwYi00MTJjLTkwMGEtMzY5ZmVmZGZiMzZjIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.oxjPtZhyOylFO8mvWBJ6E8UD42161-jxLMXYeJuQSPKs_wioUqR2Fkx3p7DeYb3b0A4_I4cT0APC1nM1tQnuah9UH9wb6hryzdoiH8WVfNZjjGJcPCC59hMOLFfBswQOo5f9zIbZnMdDjo9NXo96RQrxlu_JxQM_l3UYpr2Gn5CRwZrMVQBRQ5mhDd2yTK-wF-I0rcwoIDAUGt-ajFRZ7J9V4AHxXjHDfA0XqVCay25ZKiJ50UkkGV0PCwU7VwZzdNqF-nOxRkhDnX7w13LVxlwaWvpBMcHimX2HU0P6orufslKlVrQAdj3nenZ4dKPW0Ss1ndK0nRUpOuOgd4hi7g"
}
skipping: [10.0.1.202]
skipping: [10.0.1.203]

TASK [deploy_manifests : 保存 token 到当前 ansible 目录] ***************************************************************************************************************************************************
skipping: [10.0.1.202]
skipping: [10.0.1.203]
changed: [10.0.1.201]

PLAY RECAP ******************************************************************************************************************************************************************************************
10.0.1.201                 : ok=117  changed=82   unreachable=0    failed=0    skipped=19   rescued=0    ignored=0   
10.0.1.202                 : ok=69   changed=53   unreachable=0    failed=0    skipped=33   rescued=0    ignored=0   
10.0.1.203                 : ok=49   changed=39   unreachable=0    failed=0    skipped=53   rescued=0    ignored=0  
```

## 添加 Node 节点

要添加 Node 节点也很简单，仅需在 `hosts.yml` 下新添加一个节点，并添加一个主机变量 `node: yes` 标识它为 Node 节点，我这里要添加一个 `10.0.1.204` 的主机为新 Node，所以在 `hosts.yml` 中添加配置如下：

```yml
all:
  vars:
    ansible_user: root
    ansible_ssh_pass: root1234
    ansible_sudo_pass: root1234
    ...
  hosts:
    ...
    10.0.1.203: 
      hostname: k8s-node1
      etcd: yes
      node: yes
    10.0.1.204:
      hostname: k8s-node2
      node: yes
```

然后执行 Playbook 时限定仅执行新 Node 节点相关的 Task，如下：

```bash
$ sudo ansible-playbook -i hosts.yml run.yml --limit 10.0.1.204
```

> 如果需要同时添加多个 Node 节点，有如下两种方法：
>
> 1. 使用 `--limit` 时后面指定多个 Node IP，以逗号 `,` 分隔；
> 2. 可以将多个 Node 节点的 IP 保存到一个文本文件，每行一个 IP，然后执行 `ansible-playbook` 时使用 `--limit @<文件名>` 即可；

执行完成后在 Master 节点可以接收到新 Node 中的 Kubulet 发出的证书申请：

```bash
$ kubectl get csr | grep Pending
node-csr-jHEi1_yP3TNX80M8_4KPRxIziC7E-bkf07rJpa_l4Vw   2m16s   kubernetes.io/kube-apiserver-client-kubelet   kubelet-bootstrap   Pending
```

直接在 Master 节点执行下面命令允许签发证书即可：

```bash
$ kubectl get csr | awk '$NF=="Pending"{print $1}' | xargs -i kubectl certificate approve {}
certificatesigningrequest.certificates.k8s.io/node-csr-jHEi1_yP3TNX80M8_4KPRxIziC7E-bkf07rJpa_l4Vw approved
```

然后就可以查看到新加入的节点了：

```bash
$ kubectl get node
NAME          STATUS     ROLES    AGE   VERSION
k8s-master1   Ready      <none>   26m   v1.19.3
k8s-master2   Ready      <none>   21m   v1.19.3
k8s-node1     Ready      <none>   26m   v1.19.3
k8s-node2     NotReady   <none>   22s   v1.19.3
```


## 检查

### 检查 Node

在 Master 节点（`10.0.1.201` 或 `10.0.1.202`）上检查 Node 是否正常：

```bash
$ kubectl get node
NAME          STATUS   ROLES    AGE    VERSION
k8s-master1   Ready    <none>   113s   v1.19.0
k8s-master2   Ready    <none>   113s   v1.19.0
k8s-node1     Ready    <none>   113s   v1.19.0
```
### 检查 CNI 网络插件
检查网络插件是否正常，即检查 `Pod` 能否跨主机通信，创建如下 `Deployment` 资源：
```bash
$ cat test_deploy.yml 
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: test
  name: test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - image: busybox:1.28.4
        name: busybox
        command: ["sleep", "3600"]

$ kubectl apply -f test_deploy.yml
deployment.apps/test created
```
随便进入一个 `Pod` 中的容器，`ping` 另外两个主机上的 `Pod`：
```bash
$ kubectl get pod -o wide
NAME                    READY   STATUS    RESTARTS   AGE   IP           NODE          NOMINATED NODE   READINESS GATES
test-54fdd84b68-j9zwq   1/1     Running   0          77s   10.244.0.2   k8s-node1     <none>           <none>
test-54fdd84b68-w64jv   1/1     Running   0          77s   10.244.2.4   k8s-master1   <none>           <none>
test-54fdd84b68-zptw8   1/1     Running   0          77s   10.244.1.3   k8s-master2   <none>           <none>

$ kubectl exec -it test-54fdd84b68-j9zwq -- sh
/ # ping 10.244.2.4
PING 10.244.2.4 (10.244.2.4): 56 data bytes
64 bytes from 10.244.2.4: seq=0 ttl=62 time=1.334 ms
^C
--- 10.244.2.4 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 1.334/1.334/1.334 ms
/ # 
/ # ping 10.244.1.3
PING 10.244.1.3 (10.244.1.3): 56 data bytes
64 bytes from 10.244.1.3: seq=0 ttl=62 time=0.761 ms
