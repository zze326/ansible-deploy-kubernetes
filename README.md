# Ansible 二进制部署 Kubernetes
## 功能说明

- [x] CNI 插件自动部署；
- [x] Dashboard UI 自动部署；
- [x] core DNS 自动部署；
- [x] 一键加入新的 Node；
- [ ] Ingress-Controller 自动部署；
- [x] 多 Master 高可用（Keepalived + Nginx）一键部署；
- [ ] 支持 Ubuntu；
- [ ] 支持完全离线部署；
- [ ] CNI 插件可选配置；
- [ ] Ingress-Controller 可选配置；

> 如有疑惑或建议可提 ISSUE 或在 [此链接](https://www.zze.xyz/archives/kubernetes-deploy-binary-mutil-master.html) 下留言。

## 环境准备

### 离线二进制包下载
链接: <https://pan.baidu.com/s/1GePd1S3W6hw-ToHerTCokg>  密码: `dovo`.

其中包含的二进制包如下：
- CNI 插件(v0.87)
- Docker(19.03.9)
- ETCD(v3.4.13)
- Kubernetes(1.19.0)
- cfssl 二进制包；

下载好后将其上传到服务器上，如下：
```bash
$ ls
kubernetes-1.19.0-zze-ansible.bin.tar.gz
```

解压压缩包到 `/opt` 目录，解压后的所有文件会在 `packages` 目录下，所以解压后的压缩包路径就为 `/opt/packages` 了，操作如下：

```bash
$ tar xf kubernetes-1.19.0-zze-ansible.bin.tar.gz -C /opt/
$ tree /opt/packages/
/opt/packages/
├── cfssl
│   ├── cfssl-certinfo_linux-amd64
│   ├── cfssljson_linux-amd64
│   └── cfssl_linux-amd64
├── cni-plugins-linux-amd64-v0.8.7.tgz
├── docker-19.03.9.tgz
├── etcd-v3.4.13-linux-amd64.tar.gz
└── kubernetes-server-linux-amd64.tar.gz

1 directory, 7 files
```
<font color='red'>注意：这里之所以是解压到 `/opt` 目录下，是因为在 Ansible 变量中我默认使用的是这个目录，如果你不是使用这个目录，则需要修改对应的变量，在下面我会进行说明。</font>
### 安装 Ansible 和 Git
安装 Ansible 和 Git，由于目前该 Ansible 仅支持 CentOS，所以我这里使用的是 CentOS 7.8 做演示，直接使用 YUM 安装即可：

```bash
$ yum install ansible git -y
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

## 配置修改
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
    # Dashboard 部署到的命名空间
    dashboard_namespace: kube-system
    # 保存 Dashboard 访问 Token 的文件名，在当前 hosts.yml 同级目录下
    dashboard_token_file: dashboard_token.txt
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
```
从上述配置可以看出：
- 上述配置最终会创建一个三节点的双 Master 三 Node 的 Kubernete 集群，并且每个节点也是 ETCD 集群中的一个成员；
- `10.0.1.201` 和 `10.0.1.202` 作为 Master 的同时也会作为 API Server 的代理节点；
- `10.0.1.201` 的优先级（`proxy_priority`）比 `10.0.1.202` 高，所以最终 Keepalived 管理的 VIP 会优先绑定到 `10.0.1.201` 上；

## 执行部署操作
按需修改 `hosts.yml`，大部分配置保持默认即可，几乎仅需要修改节点 IP 和密码，修改完成后执行下面命令开始部署操作：

```bash
$ sudo ansible-playbook -i hosts.yml run.yml
...
TASK [deploy_manifests : 部署 coredns] ****************************************************************************************************************************************************************
skipping: [10.0.1.202] => (item=/root/kubernetes-deploy-ansible/manifests/coredns.yml) 
skipping: [10.0.1.203] => (item=/root/kubernetes-deploy-ansible/manifests/coredns.yml) 
changed: [10.0.1.201] => (item=/root/kubernetes-deploy-ansible/manifests/coredns.yml)

PLAY RECAP ******************************************************************************************************************************************************************************************
10.0.1.201                 : ok=110  changed=58   unreachable=0    failed=0    skipped=15   rescued=0    ignored=0   
10.0.1.202                 : ok=68   changed=35   unreachable=0    failed=0    skipped=27   rescued=0    ignored=0   
10.0.1.203                 : ok=49   changed=24   unreachable=0    failed=0    skipped=46   rescued=0    ignored=0  
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
64 bytes from 10.244.1.3: seq=1 ttl=62 time=0.467 ms
^C
--- 10.244.1.3 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.467/0.614/0.761 ms
```
可以看到是可以正常通信的。

### 检查 Core DNS
依旧时进入上述测试进入的 `Pod`，测试解析 `kubernetes` 为 IP：

```bash
$ kubectl exec -it test-54fdd84b68-j9zwq -- sh
/ # nslookup kubernetes
Server:    10.0.0.2
Address 1: 10.0.0.2 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes
Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local
```
解析成功，说明 Core DNS 也工作正常。

### 检查 Dashboard UI
这里我将 Dashboard 服务默认使用 `NodePort` 类型的 `Service` 暴露服务，其暴露端口由 `hosts.yml` 中的 `dashboard_port` 指定，这里我指定的为 `30001`，所以 Dashboard UI 的访问地址为 <https://<NodeIP>:30001>。
并且在上述 Ansible Role 执行完成之后会在 `hosts.yml` 同级目录下生成一个 `dashboard_token.txt` 文件，该文件名由 `hosts.yml` 中的 `dashboard_token_file` 指定，该文件中保存了具备访问 Dashboard UI 权限的用户的 Token， 进入 Dashboard UI 页面后直接使用该 Token 就可以登入。


