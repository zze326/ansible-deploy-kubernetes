# Ansible 二进制部署 Kubernetes
## 功能说明

- [x] CNI 插件自动部署；
- [x] Dashboard UI 自动部署；
- [x] core DNS 自动部署；
- [x] 一键加入新的 Node；
- [x] Ingress-Controller 自动部署；
- [x] 多 Master 高可用（Keepalived + Nginx）一键部署；
- [x] 透明支持 CentOS 和 Ubuntu；
- [ ] 支持完全离线部署；
- [ ] CNI 插件可选配置；
- [ ] Ingress-Controller 可选配置；

> 如有疑惑或建议可提 ISSUE 或在 [此链接](https://www.zze.xyz/archives/kubernetes-deploy-binary-mutil-master.html) 下留言。
> 这里我在 CentOS 7.8 和 Ubuntu 16.04 上进行了测试，完全能够一键跑完。
> 要注意的是，如果你使用的是 Ubuntu，那么需要先在所有节点上装上 python 环境，因为 Ansible 依赖被控端的 python，而 Ubuntu 默认是没有的（CentOS 默认有），执行 `sudo apt install python-minimal` 安装即可。

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
│   ├── cfssl-certinfo_linux-amd64
│   ├── cfssljson_linux-amd64
│   └── cfssl_linux-amd64
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
    # 启用 Ingress，可使用在 hosts 节对应主机下添加 ingress: yes 标识仅在该主机上部署 Ingress-Controller，如果没有标识则默认在所有 Node 上部署
    enable_ingress: yes
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
TASK [deploy_manifests : 部署 coredns] ****************************************************************************************************************************************************************
skipping: [10.0.1.202] => (item=/root/kubernetes-deploy-ansible/manifests/coredns.yml) 
skipping: [10.0.1.203] => (item=/root/kubernetes-deploy-ansible/manifests/coredns.yml) 
changed: [10.0.1.201] => (item=/root/kubernetes-deploy-ansible/manifests/coredns.yml)

PLAY RECAP ******************************************************************************************************************************************************************************************
10.0.1.201                 : ok=110  changed=58   unreachable=0    failed=0    skipped=15   rescued=0    ignored=0   
10.0.1.202                 : ok=68   changed=35   unreachable=0    failed=0    skipped=27   rescued=0    ignored=0   
10.0.1.203                 : ok=49   changed=24   unreachable=0    failed=0    skipped=46   rescued=0    ignored=0  
```
目前 Ansible 的最后一个 Task 是 `部署  coredns`，到这里说明你的 Ansible 顺利执行完成了。
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
k8s-master1   Ready      <none>   26m   v1.19.0
k8s-master2   Ready      <none>   21m   v1.19.0
k8s-node1     Ready      <none>   26m   v1.19.0
k8s-node2     NotReady   <none>   22s   v1.19.0
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

这里我将 Dashboard 服务默认使用 `NodePort` 类型的 `Service` 暴露服务，其暴露端口由 `hosts.yml` 中的 `dashboard_port` 指定，这里我指定的为 `30001`，所以 Dashboard UI 的访问地址为 [https://NodeIP:30001](https://10.0.1.203:30001)。

并且在上述 Ansible Role 执行完成之后会在 `hosts.yml` 同级目录下生成一个 `dashboard_token.txt` 文件，该文件名由 `hosts.yml` 中的 `dashboard_token_file` 指定，该文件中保存了具备访问 Dashboard UI 权限的用户的 Token，如下：

```bash
$ ls
dashboard_token.txt  hosts.yml  manifests  README.md  roles  run.yml
$ cat dashboard_token.txt 
eyJhbGciOiJSUzI1NiIsImtpZCI6IlhjQU9EckdpRHpSNTZTQXoyMjJHa3lRWVd4UGw2ZGhhNjk0RkhUZlBKWkUifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4tOTc2NTYiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiN2ZjNzE3YzctYjk5MS00NjFiLWE5MGUtNTkyYjQ0Njc3MzM4Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.PgNaPBkI28hv2jmFF5z5DKSI2Rl_0PNHxAQn9-t-033Lr7aIW7NL8QE_1Nj4fAJ692VY85bEFiHXAsStyxusMeN6LvJTRGbcZaWZN0YbqX5Q6n22VE0goadGStfVmuSGkB-fyDe5WACTFJPN9EdXbgXtkD4Ny5CX4Kzv3S9iigs_58UBRhwkBs2BVuE_5PT361KK82HP6yvS-YYGRqTHEvRyk4AQ2L4Dh7NSYH8pFba-n5nT4K8wOlbqdkdQN62S5KkabYOEzHBX8WoHTERr36YxhpMvhk3o0iWgkGiOaxEfjwamtz5SDb3NQvRGqNXwNsTRh48Xw8hDfYRf7s6d-g
```

 进入 Dashboard UI 页面后选择 Token 认证直接填入该 Token 就可以登入。

### 检查 Ingress

当前默认使用的是 HAProxy Ingress-Controller，检查是否部署成功：

```bash
$ kubectl get pod -n haproxy-controller -o wide
NAME                                     READY   STATUS    RESTARTS   AGE   IP           NODE        NOMINATED NODE   READINESS GATES
haproxy-ingress-jtldj                    1/1     Running   0          10m   10.0.1.203   k8s-node1   <none>           <none>
ingress-default-backend-c675c85f-6k974   1/1     Running   0          30m   10.244.2.6   k8s-node1   <none>           <none>
```

由于上面我在 `k8s-node1` 节点下添加了 `ingress: yes` 属性，所以仅会在该节点下部署 Ingress-Controller。

这里先使用 Nginx 镜像创建一个 `Deployment` 资源，然后使用 `Service` 资源暴露它到集群内部：

```bash
$ kubectl create deploy nginx-web --image=nginx
deployment.apps/nginx-web created
$ kubectl expose deploy nginx-web --target-port=80 --port=80
service/nginx-web exposed
```

下面添加一下 `Ingress` 规则来检查 Ingress-Controller 是否运作正常，定义如下 `Ingress` 规则：

```bash
$ cat web-ingress.yml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: "www.zze.cn"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-web
            port:
              number: 80
```

修改本机的 hosts 进行测试，解析 `www.zze.cn` 到部署了 Ingress-Controller 的节点，访问结果如下：

```bash
$ curl -I www.zze.cn
HTTP/1.1 200 OK
server: nginx/1.19.3
date: Wed, 28 Oct 2020 07:58:13 GMT
content-type: text/html
content-length: 612
last-modified: Tue, 29 Sep 2020 14:12:31 GMT
etag: "5f7340cf-264"
accept-ranges: bytes
```

OK，Ingress-Controller  也工作正常~
