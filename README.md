## Description

图表示例为2 个 node 节点的情况下，部署 大于2 个relica 的 file server 服务, 以及 大于2个replica 的星图服务的情况

### 技术选型


- 高可用
基于k8s的部署方案 (场外支持难度降低)
扩容灵活度较高 (支持基本的scale, 数据更新采用Canary Zero Downtime部署逻辑)
数据持久化 (Persistent Volume)，日志可导出
- SDK访问
提供统一的endpoint访问 (Service 固定端口暴露)
客户端集群的多节点无感知 (Ansible 任务流，分组执行)
- 项目复用
主服务和批处理服务 共享业务基础逻辑 (替换变量 例如：命名空间，资源上下限度, 网关等)





### 技术方案

两个部分组成：主服务和批量处理服务


1. 主服务：数据挂载+多点读取+数据更新重载+服务扩容

服务数据依赖于mysql库，以及数据包bin; 服务配置properties等文档。底层依赖k8s(多节点)部署。

- 项目流程主要有

挂载依赖
从本地路径确认依赖文档文件名正确，通过pv挂载到k8s集群(命名空间namespace为{k8s_ns: planet-graph-ns}，在目标路径为 {base_data_dir}, 根据本地路径可自定义。

1) 文件服务 fileserver

通过pv 将外部数据挂载将服务器储存的内容挂载，架起小型服务端允许多节点读取容器内数据
文件持久化存储节点被 pvc利用， 通过指定的 storage class name 一对一高强度绑定 pv

2) 星图地址标记服务

在已经解压星图服务docker 镜像成为tar 包的前提 + 在pv 和 pvc 已绑定的状态下，通过 deployment 多节点上启动多个pod 服务
调度器schedular 会把 pod 调度在node 上，建议设置大于等于 3 个 replicaset 以保证高可用









2. 批数据处理：数据挂载+启动并行服务+数据输出+资源清理

服务数据依赖于mysql库。底层依赖k8s(多节点)部署。并行工作处理以来rabbitMQ服务。


1) 文件服务

通过pv 将外部数据挂载将服务器储存的内容挂载，架起小型服务端允许多节点读取容器内数据
文件持久化存储节点被 pvc利用， 通过指定的storage class name 一对一高强度绑定 pv

2) 工作队列 的并行job
借助 rabbitMQ服务确定每个 Pod 要处理哪个工作条目
文通过启动statefulset的进行队列publish和consume任务，即需要处理的文件目录信息
以 fanout 方式发出并行pod 所需处理的文件信息

3) 并行处理任务
指定任务并行数，rabbitmq 标记数据路径下文件名，组成任务队列输出文件结果到服务器指定路径
管理资源清除和运行状态通过自身特性，保证job正常结束后级联式地删除 Job 和资源


ttlSecondsAfterFinished 和 activeDeadlineSeconds 

## 业务框架

inventory/: 定制化完成部署的

roles/: ansible 对应的role, 可以对应小分类的任务并且进行pipeline 编排

site.yaml: 在bin 文件已经存在的情况下，启动file server 文件分享服务, 启动星图service 进据服务

rollout_service.yaml: 本地文件更新后重新启动星图服务

clean.yaml: 清除所有服务 


涉及存储和分布式的服务包括：(role 中对应模块为 mysql, rabbitmq)

mysql
rabbitmq

项目结构：
hosts文件写了各个组件的k8s节点地址
job.yaml
site.yaml
clean.yaml
job_clean.yaml
playbook 服务模块
role
files里面放置一些脚本、程序
tasks里面都包括了main.yml和clean.yml，对应安装和卸载
templates里放置配置、脚本，是和业务相关直接相关的文件


 ~/root
     |__inventory (脚本变量定义)
         |__ hosts (主机信息)
         |__ groupvars
             |__all.yaml    (变量定义)

         |__playbooks       (脚本库)
             |__ folder   (任务脚本；比如启动file server，清理file server, 滚动更新服务)
             |__ xxxx.yaml  (子任务类型脚本)


## 环境
安装KB前需要先满足以下环境和工具依赖

## 环境要求

Linux操作系统，建议CentOS 7发行版。
已安装1.16.8或以上版本的k8s集群。
已安装位于同k8s集群、4.0.0以上版本的先知环境。
在k8s集群的主节点上执行安装。

## 工具要求
- 安装python 3.6以上
- 服务器有root登录权限


## Install

- K8s related
- Ansible
- Python ^3


Not required:

- Playbook 任务计时插件
  Github 地址： https://github.com/jlafon/ansible-profile

  ```
  mkdir callback_plugins
  cd callback_plugins
  wget https://raw.githubusercontent.com/jlafon/ansible-profile/master/callback_plugins/profile_tasks.py
  ```

- Yamllint (web portal should be Ok) (for quick reference)

  - Callback

  ```
  wget https://raw.githubusercontent.com/jlafon/ansible-profile/master/callback_plugins/p
  ```

  - Kubens

  ```
  curl -L https://github.com/ahmetb/kubectx/releases/download/v0.9.1/kubens -o /bin/kubens
  chmod +x /bin/kubens
  kubens <命名空间名称>
  ```

## Run

#### 安装
```
# 已安装pip package库
ansible-playbook site.yaml

# 第一次安装：
ansible-playbook site.yaml --tags "initialize"
```

####  清理
```
ansible-playbook clean.yaml
```

#### 扩缩容

```

ansible-playbook script-ansible.yaml -v -u root --e 'scaled_replicas=5'

```
#### 重载数据bin包
```
ansible-playbook rollout.yaml
```



## Steps

#### 1、安装
a. Ansible
```
# example
yum install ansible -y
```
b. 更改 hosts 和 all.yaml 部署k8s 集群

c. bin 文件load 到 路径 root/tmp_bin/, 确认文件地址 `ls /root/tmp_bin`



#### 2、更新配置信息 （场外无需添加）
加密

```
kubectl create secret docker-registry myregistrykey --docker-server=docker.4pd.io/ --docker-username=deploy --docker-password=GlW5SRo1TC3q
```


#### 3、一键安装
#### 方法1: 全部
```
# 已安装pip package库
ansible-playbook site.yaml

# 第一次安装：
ansible-playbook site.yaml --tags "initialize"
```

#### 方法2: 细分


a. 启动file server  (planet graph file server)
```
ansible-playbook playbooks/01.start_fileserver.yaml
```

确认planet-graph-file-server-deployment 状态成功 （available = up-to-date）
```
k get deployment -n planet-graph-ns
k get po -n planet-graph-ns -o wide | grep fileserver
```

b. 启动planet graph server
```
ansible-playbook playbooks/02.start_service.yaml
```
确认planet-graph-service-deployment 状态成功  （available = up-to-date）
```
k get deployment -n planet-graph-ns
k get po -n planet-graph-ns -o wide | grep service
```

#### 4、查看部署信息（用于错误快速排查）
```
ansible-playbook site.yaml -t "debug"
```

#### 5、更新bin数据包，重新部署file server 和 形图服务
```
ansible-playbook rollout.yaml
```


#### 6、service 扩缩容 (用于资源不足/请求并发过高)
```
ansible-playbook scale_service.yaml --e 'scaled_replicas=5'
```

#### 7、一键清理
```
ansible-playbook clean.yaml
```

#### 8 启动批处理服务
```
# 方法一：
ansible-playbook job.yaml # 此时会以来 playbooks/vars/processor.yaml
# 方法二： 
ansible-playbook job.yaml -e "input_data_path=1613965896"
```

#### 9 清除批处理
```
# 一键清理
ansible-playbook clean_job.yaml
```

## Test

星图服务测试 example

```
# Request
curl -X POST 'http://{LOCALHOST}:{PORT}//planet-graph/v2/address/standardize' --header 'Content-Type: application/json' --data '{"addrs":["北京"]}'

```

```
# Response
{"addrs":[{"segments":["北京市","北京市"],"province":"北京市","city":"北京市","region":null,"town":null,"village":null,"houseNumber":-1,"company":null,"road":null,"residential":null,"office":null,"mall":null,"businessCircle":null,"level":"市"}]}

```


## Output

#### 1、安装
```
-->$ ansible-playbook site.yaml

PLAY [all] *********************************************************************

TASK [prepare : check data.bin] ************************************************
changed: [172.27.233.48]

TASK [prepare : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
    "msg": "root@172.27.233.48 "
}

TASK [prepare : check data bin repository] *************************************
changed: [172.27.233.48] => (item=data_stable.bin)
changed: [172.27.233.48] => (item=planetgraph.lic)
changed: [172.27.233.48] => (item=application.properties)

TASK [prepare : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
    "msg": "172.27.233.48 | Located /mnt/data/data_bin/data_stable.bin. Located /mnt/data/data_bin/planetgraph.lic. Located /mnt/data/data_bin/application.properties. "
}

TASK [prepare : check bin repository content] **********************************
ok: [172.27.233.48] => {
    "msg": " {'msg': '172.27.233.48 | Located /mnt/data/data_bin/data_stable.bin. Located /mnt/data/data_bin/planetgraph.lic. Located /mnt/data/data_bin/application.properties. ', 'failed': False, 'changed': False}"
}

TASK [prepare : check pip package version] *************************************
changed: [172.27.233.48] => (item=openshift)
changed: [172.27.233.48] => (item=ansible-base)
changed: [172.27.233.48] => (item=ansible)

TASK [fileserver : k8s: create volume] *****************************************
changed: [172.27.233.48]

TASK [fileserver : k8s: create claim] ******************************************
changed: [172.27.233.48]

TASK [fileserver : register volume] ********************************************
changed: [172.27.233.48]

TASK [fileserver : register volume claim] **************************************
changed: [172.27.233.48]

TASK [fileserver : DEBUG info] *************************************************
ok: [172.27.233.48] => {
    "msg": "created pv and claim: planet-graph-volume and planet-graph-ns/planet-graph-volume-claim"
}

TASK [fileserver : k8s: create deployment] *************************************
changed: [172.27.233.48]

TASK [fileserver : register deployment] ****************************************
changed: [172.27.233.48]

TASK [fileserver : k8s: register replicas] *************************************
changed: [172.27.233.48]

TASK [fileserver : k8s: wait for deployment has available replicas] ************
changed: [172.27.233.48]

TASK [fileserver : DEBUG info] *************************************************
ok: [172.27.233.48] => {
    "msg": "created deployment: planet-graph-file-server-deployment"
}

TASK [fileserver : k8s: create file server service] ****************************
changed: [172.27.233.48]

TASK [fileserver : file server register service] *******************************
changed: [172.27.233.48]

TASK [fileserver : file server register service] *******************************
changed: [172.27.233.48]

TASK [fileserver : DEBUG info] *************************************************
ok: [172.27.233.48] => {
    "msg": "created service cluster at: 10.42.155.75:80 external port: 31000"
}

TASK [mysql : k8s: create deployment] ******************************************
changed: [172.27.233.48]

TASK [mysql : register deployment] *********************************************
changed: [172.27.233.48]

TASK [mysql : register replicas] ***********************************************
changed: [172.27.233.48]

TASK [mysql : k8s: wait for deployment has available replicas] *****************
FAILED - RETRYING: k8s: wait for deployment has available replicas (10 retries left).
changed: [172.27.233.48]

TASK [mysql : DEBUG info] ******************************************************
ok: [172.27.233.48] => {
    "msg": "created deployment: planet-graph-mysql-deployment with 1/1 replicas "
}

TASK [k8s: create mysql server service] ****************************************
changed: [172.27.233.48]

TASK [mysql server register service] *******************************************
changed: [172.27.233.48]

TASK [mysql server register service port] **************************************
changed: [172.27.233.48]

TASK [mysql : DEBUG info] ******************************************************
ok: [172.27.233.48] => {
    "msg": "created mysql cluster at: 10.42.10.77:3306 external port: 32000"
}

PLAY [all] *********************************************************************

TASK [service : show date] *****************************************************
changed: [172.27.233.48]

TASK [service : k8s: create dataconfig] ****************************************
ok: [172.27.233.48]

TASK [service : k8s: create planet graph pod] **********************************
changed: [172.27.233.48]

TASK [service : k8s: create planet graph deployment] ***************************
changed: [172.27.233.48]

TASK [service : register deployment] *******************************************
changed: [172.27.233.48]

TASK [service : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
    "msg": "created deployment: planet-graph-service-deployment"
}

TASK [k8s: create planet graph service] ****************************************
changed: [172.27.233.48]

TASK [register service] ********************************************************
changed: [172.27.233.48]

TASK [service : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
    "msg": "created service: planet-graph-server"
}

TASK [planet graph server register service] ************************************
changed: [172.27.233.48]

TASK [planet graph server register service] ************************************
changed: [172.27.233.48]

TASK [planet graph server register service port] *******************************
changed: [172.27.233.48]

TASK [service : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
    "msg": "created planet graph service cluster at: 10.42.63.78:8080 external port: 30000"
}

PLAY RECAP *********************************************************************
172.27.233.48              : ok=42   changed=30   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

Playbook run took 0 days, 0 hours, 4 minutes, 21 seconds
```



#### 2、检查

-->$ ansible-playbook site.yaml --tags "debug"
[WARNING]: While constructing a mapping from /root/git-repos/planet-graph-
deploy/playbooks/roles/prepare/tasks/check.yaml, line 23, column 5, found a
duplicate dict key (name). Using last defined value only.

PLAY [all] *********************************************************************

TASK [prepare : check data.bin] ************************************************
changed: [172.27.233.48]

TASK [prepare : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
"msg": "root@172.27.233.48 "
}

TASK [prepare : check data bin repository] *************************************
changed: [172.27.233.48] => (item=data_stable.bin)
changed: [172.27.233.48] => (item=planetgraph.lic)
changed: [172.27.233.48] => (item=application.properties)

TASK [prepare : check bin repository content] **********************************
ok: [172.27.233.48] => {
"msg": "172.27.233.48 | Located /mnt/data/data_bin/data_stable.bin. Located /mnt/data/data_bin/planetgraph.lic. Located /mnt/data/data_bin/application.properties. "
}

TASK [prepare : check pip package version] *************************************
changed: [172.27.233.48] => (item=openshift)
changed: [172.27.233.48] => (item=ansible-base)
changed: [172.27.233.48] => (item=ansible)

TASK [mysql : register deployment] *********************************************
changed: [172.27.233.48]

TASK [mysql : register replicas] ***********************************************
changed: [172.27.233.48]

TASK [mysql : k8s: wait for deployment has available replicas] *****************
changed: [172.27.233.48]

TASK [mysql : DEBUG info] ******************************************************
ok: [172.27.233.48] => {
"msg": "created deployment: planet-graph-mysql-deployment with 1/1 replicas "
}

TASK [mysql server register service] *******************************************
changed: [172.27.233.48]

TASK [mysql server register service port] **************************************
changed: [172.27.233.48]

TASK [mysql : DEBUG info] ******************************************************
ok: [172.27.233.48] => {
"msg": "created mysql cluster at: 10.42.10.77:3306 external port: 32000"
}

PLAY [all] *********************************************************************

TASK [service : register deployment] *******************************************
changed: [172.27.233.48]

TASK [service : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
"msg": "created deployment: planet-graph-service-deployment"
}

TASK [register service] ********************************************************
changed: [172.27.233.48]

TASK [service : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
"msg": "created service: planet-graph-server"
}

TASK [planet graph server register service] ************************************
changed: [172.27.233.48]

TASK [planet graph server register service port] *******************************
changed: [172.27.233.48]

TASK [service : DEBUG info] ****************************************************
ok: [172.27.233.48] => {
"msg": "created planet graph service cluster at: 10.42.63.78:8080 external port: 30000"
}

PLAY RECAP *********************************************************************
172.27.233.48 : ok=19 changed=12 unreachable=0 failed=0 skipped=0 rescued=0 ignored=0

Playbook run took 0 days, 0 hours, 1 minutes, 5 seconds

## Quick Cmd

BIN 文件包发送
```
scp ansible.yaml root@172.27.233.14:/root/planet-graph-deploy/
```

事件时间查询
```
kubectl get events --sort-by=.metadata.creationTimestamp
```
