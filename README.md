

# FSM Connector 跨集群混合架构微服务融合测试

## 下载并安装 fsm 命令行工具

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.1
curl -L https://github.com/flomesh-io/fsm/releases/download/${release}/fsm-${release}-${system}-${arch}.tar.gz | tar -vxzf -
./${system}-${arch}/fsm version
cp ./${system}-${arch}/fsm /usr/local/bin/
```

## 下载 Demo 资源

```bash
git clone https://github.com/cybwan/fsm-start-demo.git -b connector
cd fsm-start-demo
```

## 场景一: [Consul 跨集群微服务融合](scenarios.1.md)

## 场景二: [Consul & K8S 跨集群混合架构微服务融合](scenarios.2.md)

## 场景三: [Consul & Eureka & Nacos 跨集群混合架构微服务融合](scenarios.3.md)
