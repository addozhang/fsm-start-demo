# FSM Eureka集成测试

## 1. 下载并安装 fsm cli

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.11
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
kubectl port-forward "$POD" -n default 8761:8761 --address 0.0.0.0 &
```

## 3. 安装 fsm

```bash
export fsm_namespace=fsm-system
export fsm_mesh_name=fsm
export dns_svc_ip="$(kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}')"
echo $dns_svc_ip
export eureka_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=eureka -o jsonpath='{.items[0].spec.clusterIP}')"
echo $eureka_svc_addr

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.certificateProvider.kind=tresor \
    --set=fsm.image.registry=localhost:5000/flomesh \
    --set=fsm.image.tag=latest \
    --set=fsm.image.pullPolicy=Always \
    --set=fsm.sidecarLogLevel=debug \
    --set=fsm.controllerLogLevel=warn \
    --set=fsm.serviceAccessMode=mixed \
    --set=fsm.featureFlags.enableAutoDefaultRoute=true \
    --set=clusterSet.region=LN \
    --set=clusterSet.zone=DL \
    --set=clusterSet.group=FLOMESH \
    --set=clusterSet.name=LAB \
    --set fsm.fsmIngress.enabled=false \
    --set fsm.fsmGateway.enabled=true \
    --set=fsm.localDNSProxy.enable=true \
    --set=fsm.localDNSProxy.primaryUpstreamDNSServerIPAddr=$dns_svc_ip \
    --set fsm.featureFlags.enableValidateHTTPRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGRPCRouteHostnames=false \
    --set fsm.featureFlags.enableValidateTLSRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGatewayListenerHostname=false \
    --set fsm.featureFlags.enableGatewayProxyTag=true \
    --set=fsm.cloudConnector.eureka.enable=true \
    --set=fsm.cloudConnector.eureka.deriveNamespace=derive-eureka \
    --set=fsm.cloudConnector.eureka.httpAddr=http://$eureka_svc_addr:8761/eureka \
    --set=fsm.cloudConnector.eureka.syncToK8S.enable=true \
    --set=fsm.cloudConnector.eureka.syncToK8S.passingOnly=false \
    --set=fsm.cloudConnector.eureka.syncToK8S.suffixMetadata=version \
    --set=fsm.cloudConnector.eureka.syncToK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.eureka.syncFromK8S.enable=true \
    --set "fsm.cloudConnector.eureka.syncFromK8S.denyK8sNamespaces={default,kube-system,fsm-system}" \
    --set=fsm.cloudConnector.eureka.syncFromK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.machine.enable=true \
    --set=fsm.cloudConnector.machine.asInternalServices=false \
    --set=fsm.cloudConnector.machine.deriveNamespace=derive-vm \
    --set=fsm.cloudConnector.machine.syncToK8S.enable=true \
    --set=fsm.cloudConnector.machine.syncToK8S.withGatewayEgress.enable=true \
    --set=fsm.cloudConnector.gateway.ingress.ipSelector=ClusterIP \
    --set=fsm.cloudConnector.gateway.ingress.httpPort=10080 \
    --set=fsm.cloudConnector.gateway.egress.httpPort=10090 \
    --set=fsm.cloudConnector.gateway.syncToFgw.enable=true \
    --set "fsm.cloudConnector.gateway.syncToFgw.denyK8sNamespaces={default,kube-system,fsm-system}" \
    --timeout=900s

#用于承载转义的eureka k8s services 和 endpoints
kubectl create namespace derive-eureka
fsm namespace add derive-eureka
kubectl patch namespace derive-eureka -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"eureka"}}}'  --type=merge

#用于承载转义的virtual machine k8s services 和 endpoints
kubectl create namespace derive-vm
fsm namespace add derive-vm
kubectl patch namespace derive-vm -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"machine"}}}'  --type=merge

make eureka-deploy
make deploy-bookwarehouse
make eureka-port-forward
make eureka-reg-services
```

## 部署FGW网关

```
export fsm_namespace=fsm-system
cat <<EOF | kubectl apply -n "$fsm_namespace" -f -
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: k8s-fgw
spec:
  gatewayClassName: fsm-gateway-cls
  listeners:
    - protocol: HTTP
      port: 10080
      name: ingress-proxy
    - protocol: HTTP
      port: 10090
      name: egress-proxy
EOF
```

## 登记虚拟机资源

```bash
kubectl apply -n derive-vm -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm6
spec:
  serviceAccountName: vm
  machineIP: 192.168.127.8
  services:
  - serviceName: bookwarehouse
    port: 14001  
  - serviceName: bookdemo
    port: 10011
EOF

kubectl create namespace curl
fsm namespace add curl

kubectl apply -n curl -f https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/access-control/curl.yaml
sleep 1
kubectl wait --for=condition=ready pod -n curl -l app=curl --timeout=180s
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
  namespace: derive-eureka
spec:
  sources:
  - kind: Service
    namespace: derive-eureka
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
kubectl apply -n derive-eureka -f - <<EOF
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
kubectl apply -n derive-eureka -f - <<EOF
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
kubectl apply -n derive-eureka -f - <<EOF
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

