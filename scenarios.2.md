# 场景一 Consul & Eureka & Nacos 服务融合

## 部署 C1 C2 C3三个集群

```bash
export clusters="C1 C2"
make k3d-up
```

## C1集群

### 部署 FSM Mesh

```bash
kubecm switch k3d-C1

fsm_cluster_name=C1 make deploy-fsm

PORT_FORWARD="6061:6060" make port-forward-fsm-repo &
http://127.0.0.1:6061/
```

### 部署 Consul 微服务

```bash
kubecm switch k3d-C1

CONSUL_VERSION=1.15.4 make consul-deploy

PORT_FORWARD="8501:8500" make consul-port-forward &
http://127.0.0.1:8501

export c1_consul_cluster_ip="$(kubectl get svc -n default --field-selector metadata.name=consul -o jsonpath='{.items[0].spec.clusterIP}')"
echo c1_consul_cluster_ip $c1_consul_cluster_ip

export c1_consul_external_ip="$(kubectl get svc -n default --field-selector metadata.name=consul -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c1_consul_external_ip $c1_consul_external_ip

export c1_consul_pod_ip="$(kubectl get pod -n default --selector app=consul -o jsonpath='{.items[0].status.podIP}')"
echo c1_consul_pod_ip $c1_consul_pod_ip

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
    name: consul
EOF

#WITH_MESH=true make deploy-consul-bookwarehouse
make deploy-bookwarehouse
```

## C2集群

### 部署 FSM Mesh

```bash
kubecm switch k3d-C2

fsm_cluster_name=C2 make deploy-fsm

PORT_FORWARD="6062:6060" make port-forward-fsm-repo &
http://127.0.0.1:6062/
```

### 部署 Consul 微服务

```bash
kubecm switch k3d-C2

CONSUL_VERSION=1.15.4 make consul-deploy

PORT_FORWARD="8502:8500" make consul-port-forward &
http://127.0.0.1:8502

export c2_consul_cluster_ip="$(kubectl get svc -n default --field-selector metadata.name=consul -o jsonpath='{.items[0].spec.clusterIP}')"
echo c2_consul_cluster_ip $c2_consul_cluster_ip

export c2_consul_external_ip="$(kubectl get svc -n default --field-selector metadata.name=consul -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c2_consul_external_ip $c2_consul_external_ip

export c2_consul_pod_ip="$(kubectl get pod -n default --selector app=consul -o jsonpath='{.items[0].status.podIP}')"
echo c2_consul_pod_ip $c2_consul_pod_ip

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
    name: consul
EOF

#WITH_MESH=true make deploy-consul-bookwarehouse
WITH_MESH=true make deploy-consul-bookstore
WITH_MESH=true make deploy-consul-bookbuyer
```

## 微服务融合

### C1 集群

```bash
kubecm switch k3d-C1
```

#### 部署 fgw

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: k8s-c1-fgw
spec:
  gatewayClassName: fsm-gateway-cls
  listeners:
    - protocol: HTTP
      port: 10080
      name: igrs-http
    - protocol: HTTP
      port: 10090
      name: egrs-http
EOF

kubectl patch AccessControl -n bookwarehouse global --type=json -p='[{"op": "add", "path": "/spec/sources/-", "value": {"kind":"Service","namespace":"fsm-system","name":"fsm-gateway-fsm-system-tcp"}}]'

export c1_fgw_cluster_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].spec.clusterIP}')"
echo c1_fgw_cluster_ip $c1_fgw_cluster_ip

export c1_fgw_external_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c1_fgw_external_ip $c1_fgw_external_ip

export c1_fgw_pod_ip="$(kubectl get pod -n $fsm_namespace --selector app=fsm-gateway -o jsonpath='{.items[0].status.podIP}')"
echo c1_fgw_pod_ip $c1_fgw_pod_ip
```

#### 部署 fgw connector

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
      - bookwarehouse
EOF
```

#### 创建 derive-consul namespace

```bash
kubectl create namespace derive-consul
fsm namespace add derive-consul
kubectl patch namespace derive-consul -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"consul"}}}'  --type=merge
```

#### 部署 consul connector(c1-consul-to-c1-k8s)

**c1 consul微服务同步到c1 k8s**

```bash
kubectl apply  -f - <<EOF
kind: ConsulConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-consul-to-c1-k8s
spec:
  httpAddr: $c1_consul_cluster_ip:8500
  deriveNamespace: derive-consul
  asInternalServices: true
  syncToK8S:
    enable: true
    withGateway: true
  syncFromK8S:
    enable: false
EOF

kubectl get svc -n derive-consul
```

#### 部署 consul connector(c1-k8s-to-c2-consul)

##### **c1 k8s微服务同步到c2 consul**

```
kubectl apply  -f - <<EOF
kind: ConsulConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-k8s-to-c2-consul
spec:
  httpAddr: $c2_consul_external_ip:8500
  deriveNamespace: derive-consul
  asInternalServices: false
  syncToK8S:
    enable: false
  syncFromK8S:
    enable: true
    withGateway: true
    withGatewayMode: forward
    allowK8sNamespaces:
      - bookwarehouse
EOF
```

### C2 集群

```bash
kubecm switch k3d-C2
```

#### 部署 fgw

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: k8s-c2-fgw
spec:
  gatewayClassName: fsm-gateway-cls
  listeners:
    - protocol: HTTP
      port: 10080
      name: igrs-http
    - protocol: HTTP
      port: 10090
      name: egrs-http
EOF

kubectl patch AccessControl -n bookstore global --type=json -p='[{"op": "add", "path": "/spec/sources/-", "value": {"kind":"Service","namespace":"fsm-system","name":"fsm-gateway-fsm-system-tcp"}}]'

kubectl wait --all --for=condition=ready pod -n "$fsm_namespace" -l app=svclb-fsm-gateway-fsm-system-tcp --timeout=180s

export c2_fgw_cluster_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].spec.clusterIP}')"
echo c2_fgw_cluster_ip $c2_fgw_cluster_ip

export c2_fgw_external_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c2_fgw_external_ip $c2_fgw_external_ip

export c2_fgw_pod_ip="$(kubectl get pod -n $fsm_namespace --selector app=fsm-gateway -o jsonpath='{.items[0].status.podIP}')"
echo c2_fgw_pod_ip $c2_fgw_pod_ip
```

#### 部署 fgw connector

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
    grpcPort: 10180
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
    grpcPort: 10190
  syncToFgw:
    enable: true
    allowK8sNamespaces:
      - derive-consul
EOF
```

#### 创建 derive-consul namespace

```bash
kubectl create namespace derive-consul
fsm namespace add derive-consul
kubectl patch namespace derive-consul -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"consul"}}}'  --type=merge
```

#### 部署 consul connector(c2-consul-to-c2-derive-consul)

```
kubectl apply  -f - <<EOF
kind: ConsulConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c2-consul-to-c2-derive-consul
spec:
  httpAddr: $c2_consul_cluster_ip:8500
  deriveNamespace: derive-consul
  asInternalServices: true
  syncToK8S:
    enable: true
    withGateway: true
  syncFromK8S:
    enable: false
EOF
```

### C3 集群

```bash
kubecm switch k3d-C3
```

#### 部署 fgw

```bash
export fsm_namespace=fsm-system
kubectl apply -n "$fsm_namespace" -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: k8s-c3-fgw
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

kubectl patch AccessControl -n bookbuyer global --type=json -p='[{"op": "add", "path": "/spec/sources/-", "value": {"kind":"Service","namespace":"fsm-system","name":"fsm-gateway-fsm-system-tcp"}}]'

kubectl wait --all --for=condition=ready pod -n "$fsm_namespace" -l app=svclb-fsm-gateway-fsm-system-tcp --timeout=180s

export c3_fgw_cluster_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].spec.clusterIP}')"
echo c3_fgw_cluster_ip $c3_fgw_cluster_ip

export c3_fgw_external_ip="$(kubectl get svc -n $fsm_namespace --field-selector metadata.name=fsm-gateway-fsm-system-tcp -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo c3_fgw_external_ip $c3_fgw_external_ip

export c3_fgw_pod_ip="$(kubectl get pod -n $fsm_namespace --selector app=fsm-gateway -o jsonpath='{.items[0].status.podIP}')"
echo c3_fgw_pod_ip $c3_fgw_pod_ip
```

#### 部署 fgw connector

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
    grpcPort: 10180
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
    grpcPort: 10190
  syncToFgw:
    enable: true
    allowK8sNamespaces:
      - derive-nacos
EOF
```

#### 部署 nacos connectors

```bash
kubectl create namespace derive-nacos
fsm namespace add derive-nacos
kubectl patch namespace derive-nacos -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

##### 部署 nacos connector(nacos-to-derive-nacos)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: nacos-to-derive-nacos
spec:
  httpAddr: $nacos_cluster_ip:8848
  deriveNamespace: derive-nacos
  syncToK8S:
    enable: true
    withGateway: false
  syncFromK8S:
    enable: false
EOF
```

#### 部署 fgw connector

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
    grpcPort: 10180
  egress:
    ipSelector: ClusterIP
    httpPort: 10090
    grpcPort: 10190
  syncToFgw:
    enable: true
    allowK8sNamespaces:
      - derive-nacos
EOF
```

#### 

```bash
curl -H "proxy-tag: bookstore" http://bookstore:10080/buy-a-book/new
```



## 卸载 C1 C2 C3三个集群

```bash
export clusters="C1 C2 C3"
make k3d-reset
```
