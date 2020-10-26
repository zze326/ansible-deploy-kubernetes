# Ansible 二进制部署 Kubernetes


## 离线二进制包下载
链接: <https://pan.baidu.com/s/1GePd1S3W6hw-ToHerTCokg>  密码: `dovo`

其中包含的二进制包如下：
- CNI 插件(v0.87)
- Docker(19.03.9)
- ETCD(v3.4.13)
- Kubernetes(1.19.0)
- cfssl 二进制包；

将其解压放到 `hosts.yml` 文件中 `package_dir` 变量指定的目录下即可。

## 部署
下载好上述提供的离线二进制包，将其解压到 `hosts.yml` 中 `package_dir` 指定的目录，比如我这里 `package_dir` 的值为 `/opt/packages`，那么解压压缩包后该目录的结构如下：

```bash
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
取消 Ansible 检查 Key：
```bash
$ vim /etc/ansible/ansible.cfg
# 取消此行注释
host_key_checking = False
```

修改 `hosts.yml` 配置，大部分配置保持默认即可，几乎仅需要修改节点 IP 和密码，修改完成后执行下面命令开始部署操作：

```bash
$ sudo ansible-playbook -i hosts.yml run.yml
```

> 暂只支持 CentOS 7 上的单 Master 集群部署，持续更新。。。
> 使用文档后续完善。。暂时有点忙。。`hosts.yml` 中描述也挺详细的，如有疑惑可提 ISSUE 或在 [此链接](https://www.zze.xyz/archives/kubernetes-deploy-binary-mutil-master.html) 下留言。

## 后续功能
- [x] CNI 插件自动部署；
- [ ] Ingress-Controller 自动部署；
- [ ] 多 Master 高可用（Keepalived + Nginx）一键部署；
- [ ] 支持 Ubuntu；
- [ ] 支持完全离线部署；
- [ ] 文档完善；
- [ ] CNI 插件可选配置；
- [ ] Ingress-Controller 可选配置；

敬请期待。。。
