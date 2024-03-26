# Dubbo & Zookeeper 服务测试

## 1. 下载并安装 fsm cli

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.1
curl -L https://github.com/cybwan/fsm/releases/download/${release}/fsm-${release}-${system}-${arch}.tar.gz | tar -vxzf -
./${system}-${arch}/fsm version
cp ./${system}-${arch}/fsm /usr/local/bin/
```

## 2. 部署 fsm

```bash
export fsm_namespace=fsm-system
export fsm_mesh_name=fsm

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.certificateProvider.kind=tresor \
    --set=fsm.image.registry=cybwan \
    --set=fsm.image.tag=1.2.1 \
    --set=fsm.image.pullPolicy=Always \
    --set=fsm.sidecar.sidecarLogLevel=warn \
    --set=fsm.controllerLogLevel=warn \
    --set=fsm.serviceAccessMode=mixed \
    --set=fsm.featureFlags.enableAutoDefaultRoute=true \
    --set=clusterSet.region=LN \
    --set=clusterSet.zone=DL \
    --set=clusterSet.group=FLOMESH \
    --set=clusterSet.name=LAB \
    --timeout=900s

kubectl create namespace zookeeper-derive
fsm namespace add zookeeper-derive
kubectl patch namespace consul-derive -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"zookeeper"}}}'  --type=merge
```

## 3. 启用宽松流量模式

**目的: 以便 consul 微服务之间可以相互访问**

```bash
export fsm_namespace=fsm-system
kubectl patch meshconfig fsm-mesh-config -n "$fsm_namespace" -p '{"spec":{"traffic":{"enablePermissiveTrafficPolicyMode":true}}}'  --type=merge
```

## 4. 启用外部流量宽松模式

**目的: 以便 dubbo 微服务可以访问 zookeeper 服务中心**

```bash
export fsm_namespace=fsm-system
kubectl patch meshconfig fsm-mesh-config -n "$fsm_namespace" -p '{"spec":{"traffic":{"enableEgress":true}}}'  --type=merge
```

## 5 启用访问控制策略

```bash
export fsm_namespace=fsm-system
kubectl patch meshconfig fsm-mesh-config -n "$fsm_namespace" -p '{"spec":{"featureFlags":{"enableAccessControlPolicy":true}}}'  --type=merge
```

## 6. 部署 Zookeeper

```bash
export demo_home=https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/cloud/dubbo/zookeeper

kubectl apply -n default -f ${demo_home}/zookeeper.yaml
kubectl wait --all --for=condition=ready pod -n default -l app=zookeeper --timeout=180s
```

## 7. 设置访问控制策略

**目的: 以便 zookeeper 服务中心可以访问 dubbo 微服务**

```bash
kubectl apply -f - <<EOF
kind: AccessControl
apiVersion: policy.flomesh.io/v1alpha1
metadata:
  name: zookeeper
  namespace: zookeeper-derive
spec:
  sources:
  - kind: Service
    namespace: default
    name: zookeeper
EOF
```

## 8. 部署 Dubbo 服务

```bash
export demo_home=https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/cloud/dubbo/zookeeper

kubectl create namespace bookwarehouse
fsm namespace add bookwarehouse
kubectl apply -n bookwarehouse -f ${demo_home}/bookwarehouse.yaml
sleep 2
kubectl wait --all --for=condition=ready pod -n bookwarehouse -l app=bookwarehouse --timeout=180s

kubectl create namespace bookstore
fsm namespace add bookstore
kubectl apply -n bookstore -f ${demo_home}/bookstore.yaml
sleep 2
kubectl wait --all --for=condition=ready pod -n bookstore -l app=bookstore --timeout=180s

kubectl create namespace bookbuyer
fsm namespace add bookbuyer
kubectl apply -n bookbuyer -f ${demo_home}/bookbuyer.yaml
sleep 2
kubectl wait --all --for=condition=ready pod -n bookbuyer -l app=bookbuyer --timeout=180s
```

## 9. 服务端口转发

```bash
export POD=$(kubectl get pods --selector app=zookeeper -n default --no-headers | grep 'Running' | awk 'NR==1{print $1}')

kubectl port-forward "$POD" -n default 2181:2181 --address 0.0.0.0 &
kubectl port-forward "$POD" -n default 8080:8081 --address 0.0.0.0 &
```