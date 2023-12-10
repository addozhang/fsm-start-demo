# FSM Eureka FGW 跨集群集成测试

## 1. 下载并安装 fsm cli

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.16
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

## 3. Cluster 3

### 3.1安装 fsm

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
    --set=fsm.image.registry=cybwan \
    --set=fsm.image.tag=1.2.16 \
    --set=fsm.image.pullPolicy=Always \
    --set=fsm.sidecarLogLevel=warn \
    --set=fsm.controllerLogLevel=warn \
    --set=fsm.serviceAccessMode=mixed \
    --set=fsm.featureFlags.enableAutoDefaultRoute=true \
    --set=clusterSet.region=LN \
    --set=clusterSet.zone=DL \
    --set=clusterSet.group=FLOMESH \
    --set=clusterSet.name=C3 \
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
    --set=fsm.cloudConnector.eureka.enable=true \
    --set=fsm.cloudConnector.eureka.deriveNamespace=derive-eureka \
    --set=fsm.cloudConnector.eureka.httpAddr=http://$eureka_svc_addr:8761/eureka \
    --set=fsm.cloudConnector.eureka.syncToK8S.enable=true \
    --set=fsm.cloudConnector.eureka.syncToK8S.passingOnly=false \
    --set=fsm.cloudConnector.eureka.syncToK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.eureka.syncFromK8S.enable=true \
    --set "fsm.cloudConnector.eureka.syncFromK8S.allowK8sNamespaces={native}" \
    --set=fsm.cloudConnector.eureka.syncFromK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.gateway.ingress.ipSelector=ExternalIP \
    --set=fsm.cloudConnector.gateway.egress.ipSelector=ClusterIP \
    --set=fsm.cloudConnector.gateway.ingress.httpPort=10080 \
    --set=fsm.cloudConnector.gateway.egress.httpPort=10090 \
    --set=fsm.cloudConnector.gateway.syncToFgw.enable=true \
    --set "fsm.cloudConnector.gateway.syncToFgw.allowK8sNamespaces={derive-eureka,native}" \
    --timeout=900s

#用于承载转义的 eureka k8s services 和 endpoints
kubectl create namespace derive-eureka
fsm namespace add derive-eureka
kubectl patch namespace derive-eureka -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"eureka"}}}'  --type=merge
```

### 3.2部署FGW网关

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

## 4. Cluster 2

### 4.1安装 fsm

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
    --set=fsm.image.registry=cybwan \
    --set=fsm.image.tag=1.2.16 \
    --set=fsm.image.pullPolicy=Always \
    --set=fsm.sidecarLogLevel=warn \
    --set=fsm.controllerLogLevel=warn \
    --set=fsm.serviceAccessMode=mixed \
    --set=fsm.featureFlags.enableAutoDefaultRoute=true \
    --set=clusterSet.region=LN \
    --set=clusterSet.zone=DL \
    --set=clusterSet.group=FLOMESH \
    --set=clusterSet.name=C2 \
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
    --set=fsm.cloudConnector.eureka.enable=true \
    --set=fsm.cloudConnector.eureka.deriveNamespace=derive-eureka \
    --set=fsm.cloudConnector.eureka.httpAddr=http://$eureka_svc_addr:8761/eureka \
    --set=fsm.cloudConnector.eureka.syncToK8S.enable=true \
    --set=fsm.cloudConnector.eureka.syncToK8S.passingOnly=false \
    --set=fsm.cloudConnector.eureka.syncToK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.eureka.syncFromK8S.enable=true \
    --set "fsm.cloudConnector.eureka.syncFromK8S.allowK8sNamespaces={derive-vm}" \
    --set=fsm.cloudConnector.eureka.syncFromK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.machine.enable=true \
    --set=fsm.cloudConnector.machine.asInternalServices=true \
    --set=fsm.cloudConnector.machine.deriveNamespace=derive-vm \
    --set=fsm.cloudConnector.machine.syncToK8S.enable=true \
    --set=fsm.cloudConnector.machine.syncToK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.gateway.ingress.ipSelector=ExternalIP \
    --set=fsm.cloudConnector.gateway.egress.ipSelector=ExternalIP \
    --set=fsm.cloudConnector.gateway.ingress.httpPort=10080 \
    --set=fsm.cloudConnector.gateway.egress.httpPort=10090 \
    --set=fsm.cloudConnector.gateway.syncToFgw.enable=true \
    --set "fsm.cloudConnector.gateway.syncToFgw.allowK8sNamespaces={derive-eureka,derive-vm}" \
    --timeout=900s

#用于承载转义的 eureka k8s services 和 endpoints
kubectl create namespace derive-eureka
fsm namespace add derive-eureka
kubectl patch namespace derive-eureka -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"eureka"}}}'  --type=merge

#用于承载转义的virtual machine k8s services 和 endpoints
kubectl create namespace derive-vm
fsm namespace add derive-vm
kubectl patch namespace derive-vm -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"machine"}}}'  --type=merge
```

### 4.2 部署FGW网关

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

### 4.3 登记虚机

```
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
  - serviceName: weblogic
    port: 10010    
EOF
```

### 
