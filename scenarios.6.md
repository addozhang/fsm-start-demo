# 场景 Nacos 多集群HA微服务融合

## 1 部署 C1 C2 C3  三个集群

```bash
export clusters="C1 C2 C3"
make k3d-up
```

## 2 部署服务

### 2.1 C1集群

```bash
kubecm switch k3d-C1
```

#### 2.1.1 部署 FSM Mesh

```bash
fsm_cluster_name=C1 make deploy-fsm
```

#### 2.1.2 部署 Nacos 微服务

```bash
make nacos-auth-deploy

PORT_FORWARD="8811:8848" make nacos-port-forward &

export c1_nacos_cluster_ip="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].spec.clusterIP}')"
echo c1_nacos_cluster_ip $c1_nacos_cluster_ip

export c1_nacos_external_ip="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c1_nacos_external_ip $c1_nacos_external_ip

export c1_nacos_pod_ip="$(kubectl get pod -n default --selector app=nacos -o jsonpath='{.items[0].status.podIP}')"
echo c1_nacos_pod_ip $c1_nacos_pod_ip

kubectl create namespace fsm-policy
fsm namespace add fsm-policy

kubectl apply -f - <<EOF
kind: AccessControl
apiVersion: policy.flomesh.io/v1alpha1
metadata:
  name: global
  namespace: fsm-policy
spec:
  sources:
  - kind: Service
    namespace: default
    name: nacos
EOF

WITH_MESH=true make deploy-nacos-httpbin
WITH_MESH=true make deploy-nacos-curl
```

### 2.2 C2集群

```bash
kubecm switch k3d-C2
```

#### 2.2.1 部署 FSM Mesh

```bash
fsm_cluster_name=C2 make deploy-fsm
```

#### 2.2.2 部署 Nacos 微服务

```bash
make nacos-auth-deploy

PORT_FORWARD="8822:8848" make nacos-port-forward &

export c2_nacos_cluster_ip="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].spec.clusterIP}')"
echo c2_nacos_cluster_ip $c2_nacos_cluster_ip

export c2_nacos_external_ip="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c2_nacos_external_ip $c2_nacos_external_ip

export c2_nacos_pod_ip="$(kubectl get pod -n default --selector app=nacos -o jsonpath='{.items[0].status.podIP}')"
echo c2_nacos_pod_ip $c2_nacos_pod_ip

kubectl create namespace fsm-policy
fsm namespace add fsm-policy

kubectl apply -f - <<EOF
kind: AccessControl
apiVersion: policy.flomesh.io/v1alpha1
metadata:
  name: global
  namespace: fsm-policy
spec:
  sources:
  - kind: Service
    namespace: default
    name: nacos
EOF

WITH_MESH=true make deploy-nacos-httpbin
WITH_MESH=true make deploy-nacos-curl
```

### 2.3 C3集群

```bash
kubecm switch k3d-C3
```

#### 2.3.1 部署 FSM Mesh

```bash
fsm_cluster_name=C3 make deploy-fsm
```

#### 2.3.2 部署 Nacos 微服务

```bash
make nacos-auth-deploy

PORT_FORWARD="8833:8848" make nacos-port-forward &

export c3_nacos_cluster_ip="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].spec.clusterIP}')"
echo c3_nacos_cluster_ip $c3_nacos_cluster_ip

export c3_nacos_external_ip="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c3_nacos_external_ip $c3_nacos_external_ip

export c3_nacos_pod_ip="$(kubectl get pod -n default --selector app=nacos -o jsonpath='{.items[0].status.podIP}')"
echo c3_nacos_pod_ip $c3_nacos_pod_ip

kubectl create namespace fsm-policy
fsm namespace add fsm-policy

kubectl apply -f - <<EOF
kind: AccessControl
apiVersion: policy.flomesh.io/v1alpha1
metadata:
  name: global
  namespace: fsm-policy
spec:
  sources:
  - kind: Service
    namespace: default
    name: nacos
EOF

WITH_MESH=true make deploy-nacos-httpbin
WITH_MESH=true make deploy-nacos-curl
```

## 3 集群内微服务融合

### 3.1 C1 集群

```bash
kubecm switch k3d-C1
```

#### 3.1.1 部署 fgw

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: k8s-c1-fgw
spec:
  gatewayClassName: fsm
  listeners:
    - protocol: HTTP
      port: 10080
      name: igrs-http
      allowedRoutes:
        namespaces:
          from: All
    - protocol: HTTP
      port: 10090
      name: egrs-http
      allowedRoutes:
        namespaces:
          from: All
EOF

kubectl wait --all --for=condition=ready pod -n "$fsm_namespace" -l app=svclb-fsm-gateway-fsm-system-tcp --timeout=180s

kubectl patch AccessControl -n fsm-policy global --type=json -p='[{"op": "add", "path": "/spec/sources/-", "value": {"kind":"Service","namespace":"fsm-system","name":"fsm-gateway-fsm-system-tcp"}}]'

export c1_fgw_cluster_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].spec.clusterIP}')"
echo c1_fgw_cluster_ip $c1_fgw_cluster_ip

export c1_fgw_external_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c1_fgw_external_ip $c1_fgw_external_ip

export c1_fgw_pod_ip="$(kubectl get pod -n $fsm_namespace --selector app=fsm-gateway -o jsonpath='{.items[0].status.podIP}')"
echo c1_fgw_pod_ip $c1_fgw_pod_ip
```

#### 3.1.2 部署 fgw connector

```bash
kubectl apply  -f - <<EOF
kind: GatewayConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-fgw
spec:
  ingress:
    ipSelector: ExternalIP
    httpPort: 10080
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
  syncToFgw:
    enable: true
    allowK8sNamespaces:
      - derive-c1
EOF
```

#### 3.1.3 创建 derive-c1 namespace

```bash
kubectl create namespace derive-c1
fsm namespace add derive-c1
kubectl patch namespace derive-c1 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

#### 3.1.4 部署 nacos connector(c1-nacos-to-c1-derive-c1)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-nacos-to-c1-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c1_nacos_cluster_ip:8848
  deriveNamespace: derive-c1
  asInternalServices: true
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: ''
  syncFromK8S:
    enable: false
EOF
```

#### 3.1.5 确认本集群服务调用效果

转发 curl 服务端口:

```bash
PORT_FORWARD="11001:14001" make curl-port-forward &
```

测试指令:

```bash
curl http://127.0.0.1:11001 -v
```

确认运行效果,返回:

```bash
*   Trying 127.0.0.1:11001...
* Connected to 127.0.0.1 (127.0.0.1) port 11001
> GET / HTTP/1.1
> Host: 127.0.0.1:11001
> User-Agent: curl/8.6.0
> Accept: */*
> 
Handling connection for 11001
< HTTP/1.1 200 
< Content-Type: text/plain;charset=UTF-8
< Content-Length: 24
< Date: Sat, 01 Jun 2024 03:01:33 GMT
< 
* Connection #0 to host 127.0.0.1 left intact
httpbin-6fdb4c9544-svv8s
```

### 3.2 C2 集群

```bash
kubecm switch k3d-C2
```

#### 3.2.1 部署 fgw

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: k8s-c2-fgw
spec:
  gatewayClassName: fsm
  listeners:
    - protocol: HTTP
      port: 10080
      name: igrs-http
      allowedRoutes:
        namespaces:
          from: All
    - protocol: HTTP
      port: 10090
      name: egrs-http
      allowedRoutes:
        namespaces:
          from: All
EOF

kubectl wait --all --for=condition=ready pod -n "$fsm_namespace" -l app=svclb-fsm-gateway-fsm-system-tcp --timeout=180s

kubectl patch AccessControl -n fsm-policy global --type=json -p='[{"op": "add", "path": "/spec/sources/-", "value": {"kind":"Service","namespace":"fsm-system","name":"fsm-gateway-fsm-system-tcp"}}]'

export c2_fgw_cluster_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].spec.clusterIP}')"
echo c2_fgw_cluster_ip $c2_fgw_cluster_ip

export c2_fgw_external_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c2_fgw_external_ip $c2_fgw_external_ip

export c2_fgw_pod_ip="$(kubectl get pod -n $fsm_namespace --selector app=fsm-gateway -o jsonpath='{.items[0].status.podIP}')"
echo c2_fgw_pod_ip $c2_fgw_pod_ip
```

#### 3.2.2 部署 fgw connector

```bash
kubectl apply  -f - <<EOF
kind: GatewayConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-fgw
spec:
  ingress:
    ipSelector: ExternalIP
    httpPort: 10080
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
  syncToFgw:
    enable: true
    allowK8sNamespaces:
      - derive-c2
EOF
```

#### 3.2.3 创建 derive-c2 namespace

```bash
kubectl create namespace derive-c2
fsm namespace add derive-c2
kubectl patch namespace derive-c2 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

#### 3.2.4 部署 nacos connector(c2-nacos-to-c2-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-nacos-to-c2-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c2_nacos_cluster_ip:8848
  deriveNamespace: derive-c2
  asInternalServices: true
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: ''
  syncFromK8S:
    enable: false
EOF
```

#### 3.2.5 确认本集群服务调用效果

转发 curl 服务端口:

```bash
PORT_FORWARD="22001:14001" make curl-port-forward &
```

测试指令:

```bash
curl http://127.0.0.1:22001 -v
```

确认运行效果,返回:

```bash
*   Trying 127.0.0.1:22001...
* Connected to 127.0.0.1 (127.0.0.1) port 22001
> GET / HTTP/1.1
> Host: 127.0.0.1:22001
> User-Agent: curl/8.6.0
> Accept: */*
> 
Handling connection for 22001
< HTTP/1.1 200 
< Content-Type: text/plain;charset=UTF-8
< Content-Length: 24
< Date: Sat, 01 Jun 2024 03:10:34 GMT
< 
* Connection #0 to host 127.0.0.1 left intact
httpbin-6fdb4c9544-fm4dh
```

### 3.3 C3 集群

```bash
kubecm switch k3d-C3
```

#### 3.3.1 部署 fgw

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: k8s-c3-fgw
spec:
  gatewayClassName: fsm
  listeners:
    - protocol: HTTP
      port: 10080
      name: igrs-http
      allowedRoutes:
        namespaces:
          from: All
    - protocol: HTTP
      port: 10090
      name: egrs-http
      allowedRoutes:
        namespaces:
          from: All
EOF

kubectl wait --all --for=condition=ready pod -n "$fsm_namespace" -l app=svclb-fsm-gateway-fsm-system-tcp --timeout=180s

kubectl patch AccessControl -n fsm-policy global --type=json -p='[{"op": "add", "path": "/spec/sources/-", "value": {"kind":"Service","namespace":"fsm-system","name":"fsm-gateway-fsm-system-tcp"}}]'

export c3_fgw_cluster_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].spec.clusterIP}')"
echo c3_fgw_cluster_ip $c3_fgw_cluster_ip

export c3_fgw_external_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c3_fgw_external_ip $c3_fgw_external_ip

export c3_fgw_pod_ip="$(kubectl get pod -n $fsm_namespace --selector app=fsm-gateway -o jsonpath='{.items[0].status.podIP}')"
echo c3_fgw_pod_ip $c3_fgw_pod_ip
```

#### 3.3.2 部署 fgw connector

```bash
kubectl apply  -f - <<EOF
kind: GatewayConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c3-fgw
spec:
  ingress:
    ipSelector: ExternalIP
    httpPort: 10080
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
  syncToFgw:
    enable: true
    allowK8sNamespaces:
      - derive-c3
EOF
```

#### 3.3.3 创建 derive-c3 namespace

```bash
kubectl create namespace derive-c3
fsm namespace add derive-c3
kubectl patch namespace derive-c3 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

#### 3.3.4 部署 nacos connector(c3-nacos-to-c3-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c3-nacos-to-c3-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c3_nacos_cluster_ip:8848
  deriveNamespace: derive-c3
  asInternalServices: true
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: ''
  syncFromK8S:
    enable: false
EOF
```

#### 3.3.5 确认本集群服务调用效果

转发 curl 服务端口:

```bash
PORT_FORWARD="33001:14001" make curl-port-forward &
```

测试指令:

```bash
curl http://127.0.0.1:33001 -v
```

确认运行效果,返回:

```bash
*   Trying 127.0.0.1:33001...
* Connected to 127.0.0.1 (127.0.0.1) port 33001
> GET / HTTP/1.1
> Host: 127.0.0.1:33001
> User-Agent: curl/8.6.0
> Accept: */*
> 
Handling connection for 33001
< HTTP/1.1 200 
< Content-Type: text/plain;charset=UTF-8
< Content-Length: 24
< Date: Sun, 02 Jun 2024 00:06:01 GMT
< 
* Connection #0 to host 127.0.0.1 left intact
httpbin-6fdb4c9544-kfll
```

## 4 跨集群微服务融合(使用 Nacos SDK 的负载均衡机制)

### 4.1 C1 集群

```bash
kubecm switch k3d-C1
```

#### 4.1.1 C1 k8s derive 微服务同步到C2 Nacos

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-k8s-derive-to-c2-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c2_nacos_external_ip:8848
  deriveNamespace: none
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: 
      enable: true
    allowK8sNamespaces:
      - derive-c1
    appendMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C1'
EOF
```

#### 4.1.2 C1 k8s derive 微服务同步到C3 Nacos

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-k8s-derive-to-c3-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c3_nacos_external_ip:8848
  deriveNamespace: none
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: 
      enable: true
    allowK8sNamespaces:
      - derive-c1
    appendMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C1'
EOF
```

#### 4.1.3 从 C1 Nacos 导入 C2 Nacos 的微服务到 derive-c2

#####  4.1.3.1 创建 derive-c2 namespace

```bash
kubectl create namespace derive-c2
fsm namespace add derive-c2
kubectl patch namespace derive-c2 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 4.1.3.2 部署 nacos connector(c1-nacos-to-c2-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-nacos-to-c2-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c1_nacos_cluster_ip:8848
  deriveNamespace: derive-c2
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
      multiGateways: false
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C2'
  syncFromK8S:
    enable: false
EOF
```

#### 4.1.4 从 C1 nacos 导入 C3 nacos 的微服务到 derive-c3

#####  4.1.4.1 创建 derive-c3 namespace

```bash
kubectl create namespace derive-c3
fsm namespace add derive-c3
kubectl patch namespace derive-c3 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 4.1.4.2 部署 nacos connector(c1-nacos-to-c3-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-nacos-to-c3-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c1_nacos_cluster_ip:8848
  deriveNamespace: derive-c3
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
      multiGateways: false
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C3'
  syncFromK8S:
    enable: false
EOF
```

### 4.2 C2 集群

```bash
kubecm switch k3d-C2
```

#### 4.2.1 C2 k8s derive 微服务同步到C1 Nacos

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-k8s-derive-to-c1-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c1_nacos_external_ip:8848
  deriveNamespace: none
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: 
      enable: true
    allowK8sNamespaces:
      - derive-c2
    appendMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C2'
EOF
```

#### 4.2.2 C2 k8s derive 微服务同步到C3 Nacos

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-k8s-derive-to-c3-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c3_nacos_external_ip:8848
  deriveNamespace: none
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: 
      enable: true
    allowK8sNamespaces:
      - derive-c2
    appendMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C2'
EOF
```

#### 4.2.3 从 C2 Nacos 导入 C1 Nacos 的微服务到 derive-c1

#####  4.2.3.1 创建 derive-c2 namespace

```bash
kubectl create namespace derive-c1
fsm namespace add derive-c1
kubectl patch namespace derive-c1 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 4.2.3.2 部署 nacos connector(c2-nacos-to-c1-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-nacos-to-c1-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c2_nacos_cluster_ip:8848
  deriveNamespace: derive-c1
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
      multiGateways: false
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C1'
  syncFromK8S:
    enable: false
EOF
```

#### 4.2.4 从 C2 Nacos 导入 C3 Nacos 的微服务到 derive-c3

#####  4.2.4.1 创建 derive-c3 namespace

```bash
kubectl create namespace derive-c3
fsm namespace add derive-c3
kubectl patch namespace derive-c3 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 4.2.4.2 部署 nacos connector(c2-nacos-to-c3-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-nacos-to-c3-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c2_nacos_cluster_ip:8848
  deriveNamespace: derive-c3
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
      multiGateways: false
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C3'
  syncFromK8S:
    enable: false
EOF
```

### 4.3 C3 集群

```bash
kubecm switch k3d-C3
```

#### 4.3.1 C3 k8s derive 微服务同步到C1 Nacos

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c3-k8s-derive-to-c1-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c1_nacos_external_ip:8848
  deriveNamespace: none
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: 
      enable: true
    allowK8sNamespaces:
      - derive-c3
    appendMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C3'
EOF
```

#### 4.3.2 C3 k8s derive 微服务同步到C2 Nacos

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c3-k8s-derive-to-c2-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c2_nacos_external_ip:8848
  deriveNamespace: none
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: 
      enable: true
    allowK8sNamespaces:
      - derive-c3
    appendMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C3'
EOF
```

#### 4.3.3 从 C3 Nacos 导入 C2 Nacos 的微服务到 derive-c1

#####  4.3.3.1 创建 derive-c2 namespace

```bash
kubectl create namespace derive-c1
fsm namespace add derive-c1
kubectl patch namespace derive-c2 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 4.3.3.2 部署 nacos connector(c3-nacos-to-c1-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c3-nacos-to-c1-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c3_nacos_cluster_ip:8848
  deriveNamespace: derive-c1
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
      multiGateways: false
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C1'
  syncFromK8S:
    enable: false
EOF
```

#### 4.3.4 从 C3 Nacos 导入 C2 Nacos 的微服务到 derive-c2

#####  4.3.4.1 创建 derive-c3 namespace

```bash
kubectl create namespace derive-c2
fsm namespace add derive-c2
kubectl patch namespace derive-c2 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 4.3.4.2 部署 nacos connector(c3-nacos-to-c2-derive)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c3-nacos-to-c2-derive
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c3_nacos_cluster_ip:8848
  deriveNamespace: derive-c2
  syncToK8S:
    enable: true
    withGateway: 
      enable: true
      multiGateways: false
    filterMetadatas:
      - key: 'fsm-cross-cluster-id'
        value: 'C2'
  syncFromK8S:
    enable: false
EOF
```

### 4.4 确认服务调用效果

#### 4.4.1 确认C1集群服务调用效果

测试指令:

```bash
curl http://127.0.0.1:11001
curl http://127.0.0.1:11001
curl http://127.0.0.1:11001
```

确认运行效果,分别返回 三个集群的 httpbin pod 的名字:

```bash
httpbin-6fdb4c9544-phz9g
httpbin-6fdb4c9544-hkbg5
httpbin-6fdb4c9544-c8vmw
```

#### 4.4.2 确认C2集群服务调用效果

测试指令:

```bash
curl http://127.0.0.1:22001
curl http://127.0.0.1:22001
curl http://127.0.0.1:22001
```

确认运行效果,分别返回 三个集群的 httpbin pod 的名字:

```bash
httpbin-6fdb4c9544-phz9g
httpbin-6fdb4c9544-c8vmw 
httpbin-6fdb4c9544-hkbg5
```

#### 4.4.3 确认C3集群服务调用效果

测试指令:

```bash
curl http://127.0.0.1:33001
curl http://127.0.0.1:33001
curl http://127.0.0.1:33001
```

确认运行效果,分别返回 三个集群的 httpbin pod 的名字:

```bash
httpbin-6fdb4c9544-hkbg5
httpbin-6fdb4c9544-phz9g
httpbin-6fdb4c9544-c8vmw
```

## 5 使用 MESH 负载均衡机制

```
kubecm switch k3d-C1
```

### 5.1 创建分流策略

```
cat <<EOF | kubectl apply -n derive-c1 -f -
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: httpbin
spec:
  service: httpbin
  backends:
  - service: derive-c2/httpbin
    weight: 50
  - service: derive-c3/httpbin
    weight: 50
EOF

cat <<EOF | kubectl apply -n derive-c2 -f -
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: httpbin
spec:
  service: httpbin
  backends:
  - service: derive-c2/httpbin
    weight: 50
  - service: derive-c3/httpbin
    weight: 50
EOF

cat <<EOF | kubectl apply -n derive-c3 -f -
apiVersion: split.smi-spec.io/v1alpha4
kind: TrafficSplit
metadata:
  name: httpbin
spec:
  service: httpbin
  backends:
  - service: derive-c2/httpbin
    weight: 50
  - service: derive-c3/httpbin
    weight: 50
EOF
```

#### 5.2 确认C1集群服务调用效果

测试指令:

```bash
curl http://127.0.0.1:11001
curl http://127.0.0.1:11001
curl http://127.0.0.1:11001
curl http://127.0.0.1:11001
```

确认运行效果,分别返回 C2 和 C3集群的 httpbin pod 的名字:

```bash
待排查 ....
```

## 6 卸载 C1 C2 C3 三个集群

```bash
export clusters="C1 C2 C3"
make k3d-reset
```
