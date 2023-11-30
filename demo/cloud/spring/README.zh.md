# FSM Eureka FGW 跨集群集成测试

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
export eureka_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=eureka -o jsonpath='{.items[0].spec.clusterIP}')"
echo $eureka_svc_addr

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.certificateProvider.kind=tresor \
    --set=fsm.image.registry=cybwan \
    --set=fsm.image.tag=1.2.11 \
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
    --set fsm.featureFlags.enableValidateHTTPRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGRPCRouteHostnames=false \
    --set fsm.featureFlags.enableValidateTLSRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGatewayListenerHostname=false \
    --set=fsm.cloudConnector.eureka.enable=true \
    --set=fsm.cloudConnector.eureka.deriveNamespace=eureka-derive \
    --set=fsm.cloudConnector.eureka.httpAddr=http://$eureka_svc_addr:8761/eureka \
    --set=fsm.cloudConnector.eureka.syncToK8S.enable=true \
    --set=fsm.cloudConnector.eureka.syncToK8S.passingOnly=false \
    --set=fsm.cloudConnector.eureka.syncToK8S.suffixMetadata=version \
    --set=fsm.cloudConnector.eureka.syncToK8S.withGatewayAPI=true \
    --set=fsm.cloudConnector.eureka.syncFromK8S.enable=true \
    --set=fsm.cloudConnector.eureka.syncFromK8S.withGatewayAPI.enable=true \
    --set=fsm.cloudConnector.eureka.syncFromK8S.withGatewayAPI.via=ExternalIP \
    --set "fsm.cloudConnector.eureka.syncFromK8S.denyK8sNamespaces={default,kube-system,fsm-system}" \
    --set=fsm.cloudConnector.eureka.syncToFgw.enable=true \
    --set "fsm.cloudConnector.eureka.syncToFgw.denyK8sNamespaces={default,kube-system,fsm-system}" \
    --timeout=900s

#用于承载转义的consul k8s services 和 endpoints
kubectl create namespace eureka-derive
fsm namespace add eureka-derive
kubectl patch namespace eureka-derive -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"eureka"}}}'  --type=merge
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
      name: http
EOF
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
    namespace: default
    name: eureka
EOF
```

#### 
