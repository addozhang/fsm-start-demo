# 场景 Nacos 微服务整合

## 1 部署 k3d 集群

```bash
export clusters="C1"
make k3d-up
```

## 2 部署服务

```bash
kubecm switch k3d-C1
```

### 2.1 部署 FSM Mesh

```bash
fsm_cluster_name=C1 make deploy-fsm
```

### 2.2 部署 Nacos 服务

```bash
make nacos-auth-deploy

#make nacos-deploy
#kubectl patch deployments -n default nacos --type=json -p='[{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name":"NACOS_AUTH_ENABLE","value":"true"}},{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name":"NACOS_AUTH_TOKEN","value":"SecretKeyM1Z2WDc4dnVyZkQ3NmZMZjZ3RHRwZnJjNFROdkJOemEK"}},{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name":"NACOS_AUTH_IDENTITY_KEY","value":"nacos"}},{"op": "add", "path": "/spec/template/spec/containers/0/env/-", "value": {"name":"NACOS_AUTH_IDENTITY_VALUE","value":"nacos"}}]'
#kubectl wait --all --for=condition=ready pod -n default -l app=nacos --timeout=180s

PORT_FORWARD="8848:8848" make nacos-port-forward &

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
```

### 2.3 创建 derive-nacos namespace

```bash
kubectl create namespace derive-nacos
fsm namespace add derive-nacos
kubectl patch namespace derive-nacos -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"nacos"}}}'  --type=merge
```

### 2.4 部署 nacos connector(c1-nacos-to-c1-derive-nacos)

```
kubectl apply  -f - <<EOF
kind: NacosConnector
apiVersion: connector.flomesh.io/v1alpha1
metadata:
  name: c1-nacos-to-c1-derive-nacos
spec:
  auth:
    username: nacos
    password: nacos
  httpAddr: $c1_nacos_cluster_ip:8848
  deriveNamespace: derive-nacos
  asInternalServices: true
  syncToK8S:
    enable: true
  syncFromK8S:
    enable: false
EOF
```

### 2.7 部署 Nacos 微服务

```bash
WITH_MESH=true make deploy-nacos-httpbin
WITH_MESH=true make deploy-nacos-curl
```

## 3 确认服务调用效果

转发 curl 服务端口:

```bash
PORT_FORWARD="14001:14001" make curl-port-forward &
```

测试指令:

```bash
curl http://127.0.0.1:14001 -v
```

确认运行效果,返回:

```bash
*   Trying 127.0.0.1:14001...
* Connected to 127.0.0.1 (127.0.0.1) port 14001
> GET / HTTP/1.1
> Host: 127.0.0.1:14001
> User-Agent: curl/8.4.0
> Handling connection for 14001
Accept: */*
> 
< HTTP/1.1 200 
< Content-Type: text/plain;charset=UTF-8
< Content-Length: 24
< Date: Thu, 09 May 2024 12:05:12 GMT
< 
* Connection #0 to host 127.0.0.1 left intact
httpbin-6fdb4c9544-kb94g%
```

## 4 卸载 k3d 集群

```bash
export clusters="C1"
make k3d-reset
```
