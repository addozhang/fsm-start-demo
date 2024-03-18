

# FSM Connector 混合架构微服务融合测试

## 1. 下载并安装 fsm 命令行工具

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.1
curl -L https://github.com/flomesh-io/fsm/releases/download/${release}/fsm-${release}-${system}-${arch}.tar.gz | tar -vxzf -
./${system}-${arch}/fsm version
cp ./${system}-${arch}/fsm /usr/local/bin/
```

## 2.部署注册中心

### 2.1 部署 Consul 注册中心

```bash
kubectl apply -n default -f https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/connector/consul.yaml
sleep 5
kubectl wait --all --for=condition=ready pod -n default -l app=consul --timeout=180s

export POD=$(kubectl get pods --selector app=consul --no-headers | grep 'Running' | awk 'NR==1{print $1}')
kubectl port-forward "$POD" -n default 8500:8500 --address 0.0.0.0 &

浏览器访问 http://127.0.0.1:8500
```

### 2.2 部署 Eureka 注册中心

```bash
kubectl apply -n default -f https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/connector/eureka.yaml
sleep 5
kubectl wait --all --for=condition=ready pod -n default -l app=eureka --timeout=180s

export POD=$(kubectl get pods --selector app=eureka --no-headers | grep 'Running' | awk 'NR==1{print $1}')
kubectl port-forward "$POD" -n default 8761:8761 --address 0.0.0.0 &

浏览器访问 http://127.0.0.1:8761
```

### 2.3 部署 Nacos 注册中心

```bash
kubectl apply -n default -f https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/connector/nacos.yaml
sleep 5
kubectl wait --all --for=condition=ready pod -n default -l app=nacos --timeout=180s

export POD=$(kubectl get pods --selector app=nacos --no-headers | grep 'Running' | awk 'NR==1{print $1}')
kubectl port-forward "$POD" -n default 8848:8848 --address 0.0.0.0 &

浏览器访问 http://127.0.0.1:8848/nacos
```

## 3. 安装 fsm

```bash
export fsm_namespace=fsm-system
export fsm_mesh_name=fsm
export dns_svc_ip="$(kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}')"
echo $dns_svc_ip

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.certificateProvider.kind=tresor \
    --set=fsm.image.registry=flomesh \
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
    --set fsm.fsmIngress.enabled=false \
    --set fsm.fsmGateway.enabled=true \
    --set=fsm.localDNSProxy.enable=true \
    --set=fsm.localDNSProxy.wildcard.enable=false \
    --set=fsm.localDNSProxy.primaryUpstreamDNSServerIPAddr=$dns_svc_ip \
    --set fsm.featureFlags.enableValidateHTTPRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGRPCRouteHostnames=false \
    --set fsm.featureFlags.enableValidateTLSRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGatewayListenerHostname=false \
    --set fsm.featureFlags.enableGatewayProxyTag=true \
    --set=fsm.featureFlags.enableSidecarPrettyConfig=false \
    --timeout=900s
```

## 4. 创建衍生服务命名空间

```bash
kubectl create namespace derive-consul
fsm namespace add derive-consul
kubectl patch namespace derive-consul -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"consul"}}}'  --type=merge

kubectl create namespace derive-eureka
fsm namespace add derive-eureka
kubectl patch namespace derive-eureka -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"eureka"}}}'  --type=merge

kubectl create namespace derive-nacos
fsm namespace add derive-nacos
kubectl patch namespace derive-nacos -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge

kubectl create namespace derive-vm1
fsm namespace add derive-vm1
kubectl patch namespace derive-vm1 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"machine"}}}'  --type=merge

kubectl create namespace derive-vm2
fsm namespace add derive-vm2
kubectl patch namespace derive-vm2 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"machine"}}}'  --type=merge
```

## 5. 创建边际网关

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: k8s-fgw
spec:
  gatewayClassName: fsm-gateway-cls
  listeners:
    - protocol: HTTP
      port: 10080
      name: igrs-http
    - protocol: HTTP
      port: 10090
      name: egrs-http
    - protocol: HTTP
      port: 10180
      name: igrs-grpc
    - protocol: HTTP
      port: 10190
      name: egrs-grpc
EOF

sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l app=fsm-gateway --timeout=180s
```

## 6. 创建混合架构微服务连接器

### 6.1 创建边际网关连接器

```bash
kubectl apply  -f - <<EOF
kind: GatewayConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: fgw-1
spec:
  ingress:
    ipSelector: ExternalIP
    httpPort: 10080
    grpcPort: 10180
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
    grpcPort: 10190
  syncToFgw:
    enable: true
    denyK8sNamespaces:
      - default
      - kube-system
      - fsm-system
EOF

export fsm_namespace=fsm-system
sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l flomesh.io/fsm-connector=gateway --timeout=180s
```

### 6.2 创建Consul微服务连接器

```bash
export consul_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=consul -o jsonpath='{.items[0].spec.clusterIP}')"
echo $consul_svc_addr

kubectl apply  -f - <<EOF
kind: ConsulConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: cluster-1
spec:
  httpAddr: $consul_svc_addr:8500
  deriveNamespace: derive-consul
  syncToK8S:
    enable: true
    clusterId: consul_cluster_1
    suffixTag: version
    withGateway: true
  syncFromK8S:
    enable: true
    consulNodeName: k8s-sync
    appendTags:
      - tag0
      - tag1
    allowK8sNamespaces:
      - derive-eureka
      - derive-nacos
      - bookwarehouse
    withGateway: true
EOF

export fsm_namespace=fsm-system
sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l flomesh.io/fsm-connector=consul --timeout=180s
```

### 6.3 创建Eureka微服务连接器

```bash
export eureka_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=eureka -o jsonpath='{.items[0].spec.clusterIP}')"
echo $eureka_svc_addr

kubectl apply  -f - <<EOF
kind: EurekaConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: cluster-2
spec:
  httpAddr: http://$eureka_svc_addr:8761/eureka
  deriveNamespace: derive-eureka
  syncToK8S:
    enable: true
    clusterId: eureka_cluster_1
    suffixMetadata: version
    withGateway: true
  syncFromK8S:
    enable: true
    appendMetadatas:
      - key: type
        value: smart-gateway
      - key: version
        value: release
      - key: zone
        value: yinzhou
    allowK8sNamespaces:
      - derive-consul
      - derive-nacos
      - bookwarehouse
    withGateway: true
EOF

export fsm_namespace=fsm-system
sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l flomesh.io/fsm-connector=eureka --timeout=180s
```

### 6.4 创建Nacos微服务连接器

```bash
export nacos_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].spec.clusterIP}')"
echo $nacos_svc_addr

kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: cluster-3
spec:
  httpAddr: $nacos_svc_addr:8848
  deriveNamespace: derive-nacos
  syncToK8S:
    enable: true
    clusterId: nacos_cluster_1
    suffixMetadata: version
    withGateway: true
  syncFromK8S:
    enable: true
    allowK8sNamespaces:
      - derive-consul
      - derive-eureka
      - bookwarehouse
    withGateway: true
EOF

export fsm_namespace=fsm-system
sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l flomesh.io/fsm-connector=nacos --timeout=180s
```

### 6.5 创建虚拟机微服务连接器

#### 6.5.1 创建虚拟机集群 1 微服务连接器

```bash
kubectl apply  -f - <<EOF
kind: MachineConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: vm-cluster-1
spec:
  deriveNamespace: derive-vm1
  syncToK8S:
    enable: true
    clusterId: vm_cluster_1
    withGateway: true
EOF

export fsm_namespace=fsm-system
sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l flomesh.io/fsm-connector=machine --timeout=180s
```

#### 6.5.2 创建虚拟机集群 2 微服务连接器

```bash
kubectl apply  -f - <<EOF
kind: MachineConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: vm-cluster-2
spec:
  deriveNamespace: derive-vm2
  syncToK8S:
    enable: true
    clusterId: vm_cluster_2
    withGateway: true
EOF

export fsm_namespace=fsm-system
sleep 5
kubectl wait --all --for=condition=ready pod -n $fsm_namespace -l flomesh.io/fsm-connector=machine --timeout=180s
```

## 7. 登记虚拟机微服务

```bash
kubectl apply -n derive-vm1 -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm11
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm11
spec:
  serviceAccountName: vm11
  machineIP: 192.168.127.11
  services:
  - serviceName: hello11
    port: 10011
EOF

kubectl apply -n derive-vm1 -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm12
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm12
spec:
  serviceAccountName: vm12
  machineIP: 192.168.127.12
  services:
  - serviceName: hello12
    port: 10011
EOF

kubectl apply -n derive-vm1 -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm13
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm13
spec:
  serviceAccountName: vm13
  machineIP: 192.168.226.21
EOF

kubectl apply -n derive-vm1 -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm14
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm14
spec:
  serviceAccountName: vm14
  machineIP: 192.168.226.22
EOF

kubectl apply -n derive-vm2 -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm21
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm21
spec:
  serviceAccountName: vm21
  machineIP: 192.168.127.21
  services:
  - serviceName: world21
    port: 10011
EOF

kubectl apply -n derive-vm2 -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vm22
---
kind: VirtualMachine
apiVersion: machine.flomesh.io/v1alpha1
metadata:
  name: vm22
spec:
  serviceAccountName: vm22
  machineIP: 192.168.127.22
  services:
  - serviceName: world22
    port: 10011
EOF
```

## 8. 部署 demo 服务

```bash
kubectl create namespace bookwarehouse
kubectl apply -n bookwarehouse -f https://raw.githubusercontent.com/cybwan/fsm-start-demo/main/demo/connector/bookwarehouse.yaml
sleep 5
kubectl wait --all --for=condition=ready pod -n bookwarehouse -l app=bookwarehouse --timeout=180s
```

## 9. 确认服务注册状态

**浏览器访问:**

**Consul http://127.0.0.1:8500**

**Eureka http://127.0.0.1:8761**

**Nacos http://127.0.0.1:8848/nacos**

可以看到新增了bookwarehouse服务,该服务衍生于 k8s 服务.

