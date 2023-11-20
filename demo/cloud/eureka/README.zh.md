# FSM Eureka集成测试

## 1. 下载并安装 fsm cli

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.0
curl -L https://github.com/cybwan/fsm/releases/download/${release}/fsm-${release}-${system}-${arch}.tar.gz | tar -vxzf -
./${system}-${arch}/fsm version
cp ./${system}-${arch}/fsm /usr/local/bin/
```

## 2.部署 Eureka 服务

```bash
#部署Eureka服务
export DEMO_HOME=https://raw.githubusercontent.com/flomesh-io/springboot-bookstore-demo/main
kubectl apply -n default -f $DEMO_HOME/manifests/eureka.yaml
kubectl wait --all --for=condition=ready pod -n default -l app=eureka --timeout=180s

POD=$(kubectl get pods --selector app=eureka -n default --no-headers | grep 'Running' | awk 'NR==1{print $1}')
kubectl port-forward "$POD" -n default 8761:8761 --address 0.0.0.0
```

## 3. 安装 fsm

```bash
export fsm_namespace=fsm-system
export fsm_mesh_name=fsm
export eureka_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=eureka -o jsonpath='{.items[0].spec.clusterIP}')"
fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.certificateProvider.kind=tresor \
    --set=fsm.image.registry=cybwan \
    --set=fsm.image.tag=1.2.0 \
    --set=fsm.image.pullPolicy=Always \
    --set=fsm.sidecarLogLevel=debug \
    --set=fsm.controllerLogLevel=warn \
    --set=fsm.serviceAccessMode=mixed \
    --set=fsm.featureFlags.enableAutoDefaultRoute=true \
    --set=fsm.deployEurekaConnector=true \
    --set=fsm.cloudConnector.eureka.deriveNamespace=eureka-derive \
    --set=fsm.cloudConnector.eureka.httpAddr=http://$eureka_svc_addr:8761/eureka \
    --set=fsm.cloudConnector.eureka.passingOnly=false \
    --set=fsm.cloudConnector.eureka.suffixMetadata=version \
    --timeout=900s

#用于承载转义的consul k8s services 和 endpoints
kubectl create namespace eureka-derive
fsm namespace add eureka-derive
kubectl patch namespace eureka-derive -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"eureka"}}}'  --type=merge
```

## 4. Eureka集成测试

### 4.1 启用宽松流量模式

**目的: 以便 eureka 微服务之间可以相互访问**

```bash
export fsm_namespace=fsm-system
kubectl patch meshconfig fsm-mesh-config -n "$fsm_namespace" -p '{"spec":{"traffic":{"enablePermissiveTrafficPolicyMode":true}}}'  --type=merge
```

### 4.2 启用外部流量宽松模式

**目的: 以便 eureka 微服务可以访问 eureka 服务中心**

```bash
export fsm_namespace=fsm-system
kubectl patch meshconfig fsm-mesh-config -n "$fsm_namespace" -p '{"spec":{"traffic":{"enableEgress":true}}}'  --type=merge
```

### 4.3 启用访问控制策略

```bash
export fsm_namespace=fsm-system
kubectl patch meshconfig fsm-mesh-config -n "$fsm_namespace" -p '{"spec":{"featureFlags":{"enableAccessControlPolicy":true}}}'  --type=merge
```

### 4.4 设置访问控制策略

**目的: 以便eureka 服务中心可以访问 eureka 微服务**

```bash
kubectl apply -f - <<EOF
kind: AccessControl
apiVersion: policy.flomesh.io/v1alpha1
metadata:
  name: eureka
  namespace: eureka-derive
spec:
  sources:
  - kind: Service
    namespace: eureka-derive
    name: eureka
EOF
```

### 4.5 部署业务 POD


```bash
#模拟业务服务
export DEMO_HOME=https://raw.githubusercontent.com/flomesh-io/springboot-bookstore-demo/main

kubectl create namespace bookwarehouse
kubectl create namespace bookstore
kubectl create namespace bookbuyer

fsm namespace add bookstore bookbuyer bookwarehouse

kubectl apply -n bookwarehouse -f $DEMO_HOME/manifests/eureka/bookwarehouse-eureka.yaml
kubectl wait --all --for=condition=ready pod -n bookwarehouse -l app=bookwarehouse --timeout=180s

kubectl apply -n bookstore -f $DEMO_HOME/manifests/eureka/bookstore-eureka.yaml
kubectl apply -n bookstore -f $DEMO_HOME/manifests/eureka/bookstore-v2-eureka.yaml
kubectl wait --all --for=condition=ready pod -n bookstore -l app=bookstore --timeout=180s

kubectl apply -n bookbuyer -f $DEMO_HOME/manifests/eureka/bookbuyer-eureka.yaml
kubectl wait --all --for=condition=ready pod -n bookbuyer -l app=bookbuyer --timeout=180s
```

### 4.6 业务端口转发

```bash
BUYER_V1_POD="$(kubectl get pods --selector app=bookbuyer,version=v1 -n bookbuyer --no-headers | grep 'Running' | awk 'NR==1{print $1}')"
STORE_V1_POD="$(kubectl get pods --selector app=bookstore,version=v1 -n bookstore --no-headers | grep 'Running' | awk 'NR==1{print $1}')"
STORE_V2_POD="$(kubectl get pods --selector app=bookstore,version=v2 -n bookstore --no-headers | grep 'Running' | awk 'NR==1{print $1}')"

kubectl port-forward $BUYER_V1_POD -n bookbuyer 8080:14001 --address 0.0.0.0 &
kubectl port-forward $STORE_V1_POD -n bookstore 8084:14001 --address 0.0.0.0 &
kubectl port-forward $STORE_V2_POD -n bookstore 8082:14001 --address 0.0.0.0 &
```

### 4.6 设置分流策略

#### 4.6.1 流量全部走bookstore-v1

```bash
kubectl apply -n eureka-derive -f - <<EOF
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: bookstore-split
spec:
  service: bookstore
  backends:
  - service: bookstore-v1
    weight: 100
  - service: bookstore-v2
    weight: 0
EOF
```

#### 4.6.2 流量全部走bookstore-v2

```bash
kubectl apply -n eureka-derive -f - <<EOF
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: bookstore-split
spec:
  service: bookstore
  backends:
  - service: bookstore-v1
    weight: 0
  - service: bookstore-v2
    weight: 100
EOF
```

#### 4.6.3 流量均分

```bash
kubectl apply -n eureka-derive -f - <<EOF
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: bookstore-split
spec:
  service: bookstore
  backends:
  - service: bookstore-v1
    weight: 50
  - service: bookstore-v2
    weight: 50
EOF
```
