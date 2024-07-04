

# 基于 ZTM 跨集群微服务集成测试

## 下载并安装 fsm 命令行工具

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.3.5-alpha.1
curl -L https://github.com/cybwan/fsm/releases/download/${release}/fsm-${release}-${system}-${arch}.tar.gz | tar -vxzf -
./${system}-${arch}/fsm version
cp ./${system}-${arch}/fsm /usr/local/bin/
```

## 下载 Demo 资源

```bash
git clone https://github.com/cybwan/fsm-start-demo.git -b ztm
cd fsm-start-demo
```

## 场景一: [单服务单副本](scenarios.1.md)

## 场景二: [单服务多副本](scenarios.2.md)

## 场景三: [多服务多副本异端口](scenarios.3.md)

## 场景四: [多服务多副本同端口](scenarios.4.md)