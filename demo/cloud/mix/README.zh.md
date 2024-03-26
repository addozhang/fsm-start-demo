# Consul & Eureka & Nacos & VM 服务融合测试

## 1. 下载并安装 fsm cli

```bash
system=$(uname -s | tr [:upper:] [:lower:])
arch=$(dpkg --print-architecture)
release=v1.2.2
curl -L https://github.com/cybwan/fsm/releases/download/${release}/fsm-${release}-${system}-${arch}.tar.gz | tar -vxzf -
./${system}-${arch}/fsm version
cp ./${system}-${arch}/fsm /usr/local/bin/
```

## 2. 安装 fsm

```bash
export fsm_namespace=fsm-system
export fsm_mesh_name=fsm
export dns_svc_ip="$(kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}')"
echo $dns_svc_ip
export consul_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=consul -o jsonpath='{.items[0].spec.clusterIP}')"
echo $consul_svc_addr
export eureka_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=eureka -o jsonpath='{.items[0].spec.clusterIP}')"
echo $eureka_svc_addr
export nacos_svc_addr="$(kubectl get svc -n default --field-selector metadata.name=nacos -o jsonpath='{.items[0].spec.clusterIP}')"
echo $nacos_svc_addr

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.certificateProvider.kind=tresor \
    --set=fsm.image.registry=cybwan \
    --set=fsm.image.tag=1.2.2 \
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
    --set=fsm.localDNSProxy.wildcard.enable=true \
    --set=fsm.localDNSProxy.primaryUpstreamDNSServerIPAddr=$dns_svc_ip \
    --set fsm.featureFlags.enableValidateHTTPRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGRPCRouteHostnames=false \
    --set fsm.featureFlags.enableValidateTLSRouteHostnames=false \
    --set fsm.featureFlags.enableValidateGatewayListenerHostname=false \
    --set fsm.featureFlags.enableGatewayProxyTag=true \
    --set=fsm.cloudConnector.consul.enable=true \
    --set=fsm.cloudConnector.consul.deriveNamespace=derive-consul \
    --set=fsm.cloudConnector.consul.httpAddr=$consul_svc_addr:8500 \
    --set=fsm.cloudConnector.consul.syncToK8S.enable=true \
    --set=fsm.cloudConnector.consul.syncToK8S.clusterId=consul_cluster_1 \
    --set=fsm.cloudConnector.consul.syncToK8S.suffixTag=version \
    --set=fsm.cloudConnector.consul.syncToK8S.withGateway.enable=false \
    --set=fsm.cloudConnector.consul.syncFromK8S.enable=true \
    --set fsm.cloudConnector.consul.syncFromK8S.appendTag[0]=tag0 \
    --set fsm.cloudConnector.consul.syncFromK8S.appendTag[1]=tag1 \
    --set "fsm.cloudConnector.consul.syncFromK8S.allowK8sNamespaces={derive-eureka,derive-nacos,bookwarehouse}" \
    --set=fsm.cloudConnector.consul.syncFromK8S.withGateway.enable=false \
    --set=fsm.cloudConnector.eureka.enable=true \
    --set=fsm.cloudConnector.eureka.deriveNamespace=derive-eureka \
    --set=fsm.cloudConnector.eureka.httpAddr=http://$eureka_svc_addr:8761/eureka \
    --set=fsm.cloudConnector.eureka.syncToK8S.enable=true \
    --set=fsm.cloudConnector.eureka.syncToK8S.clusterId=eureka_cluster_1 \
    --set=fsm.cloudConnector.eureka.syncToK8S.suffixMetadata=version \
    --set=fsm.cloudConnector.eureka.syncToK8S.withGateway.enable=false \
    --set=fsm.cloudConnector.eureka.syncFromK8S.enable=true \
    --set fsm.cloudConnector.eureka.syncFromK8S.appendMetadata[0].key=type \
    --set fsm.cloudConnector.eureka.syncFromK8S.appendMetadata[0].value=smart-gateway \
    --set fsm.cloudConnector.eureka.syncFromK8S.appendMetadata[1].key=version \
    --set fsm.cloudConnector.eureka.syncFromK8S.appendMetadata[1].value=release \
    --set fsm.cloudConnector.eureka.syncFromK8S.appendMetadata[2].key=zone \
    --set fsm.cloudConnector.eureka.syncFromK8S.appendMetadata[2].value=yinzhou \
    --set "fsm.cloudConnector.eureka.syncFromK8S.allowK8sNamespaces={derive-consul,derive-nacos,bookwarehouse}" \
    --set=fsm.cloudConnector.eureka.syncFromK8S.withGateway.enable=false \
    --set=fsm.cloudConnector.nacos.enable=true \
    --set=fsm.cloudConnector.nacos.deriveNamespace=derive-nacos \
    --set=fsm.cloudConnector.nacos.httpAddr=$nacos_svc_addr:8848 \
    --set=fsm.cloudConnector.nacos.syncToK8S.enable=true \
    --set=fsm.cloudConnector.nacos.syncToK8S.clusterId=nacos_cluster_1 \
    --set=fsm.cloudConnector.nacos.syncToK8S.suffixMetadata=version \
    --set=fsm.cloudConnector.nacos.syncToK8S.withGateway.enable=false \
    --set=fsm.cloudConnector.nacos.syncFromK8S.enable=true \
    --set "fsm.cloudConnector.nacos.syncFromK8S.allowK8sNamespaces={derive-consul,derive-eureka,bookwarehouse}" \
    --set=fsm.cloudConnector.nacos.syncFromK8S.withGateway.enable=false \
    --set=fsm.cloudConnector.machine.enable=true \
    --set=fsm.cloudConnector.machine.connectorNameSuffix=vm-cluster1 \
    --set=fsm.cloudConnector.machine.asInternalServices=false \
    --set=fsm.cloudConnector.machine.deriveNamespace=derive-vm1 \
    --set=fsm.cloudConnector.machine.syncToK8S.enable=true \
    --set=fsm.cloudConnector.machine.syncToK8S.clusterId=vm_cluster_1 \
    --set=fsm.cloudConnector.machine.syncToK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.gateway.ingress.ipSelector=ExternalIP \
    --set=fsm.cloudConnector.gateway.ingress.httpPort=10080 \
    --set=fsm.cloudConnector.gateway.egress.ipSelector=ExternalIP \
    --set=fsm.cloudConnector.gateway.egress.httpPort=10090 \
    --set=fsm.cloudConnector.gateway.syncToFgw.enable=true \
    --set "fsm.cloudConnector.gateway.syncToFgw.denyK8sNamespaces={default,kube-system,fsm-system}" \
    --timeout=900s

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
EOF

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

fsm connector enable \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.cloudConnector.machine.enable=true \
    --set=fsm.cloudConnector.machine.connectorNameSuffix=vm-cluster2 \
    --set=fsm.cloudConnector.machine.asInternalServices=false \
    --set=fsm.cloudConnector.machine.deriveNamespace=derive-vm2 \
    --set=fsm.cloudConnector.machine.syncToK8S.enable=true \
    --set=fsm.cloudConnector.machine.syncToK8S.clusterId=vm_cluster_2 \
    --set=fsm.cloudConnector.machine.syncToK8S.withGateway.enable=true \
    --set=fsm.cloudConnector.gateway.ingress.ipSelector=ClusterIP \
    --set=fsm.cloudConnector.gateway.ingress.httpPort=10080 \
    --set=fsm.cloudConnector.gateway.ingress.grpcPort=10180 \
    --set=fsm.cloudConnector.gateway.egress.ipSelector=ExternalIP \
    --set=fsm.cloudConnector.gateway.egress.httpPort=10090 \
    --set=fsm.cloudConnector.gateway.egress.grpcPort=10190

kubectl create namespace derive-vm2
fsm namespace add derive-vm2
kubectl patch namespace derive-vm2 -p '{"metadata":{"annotations":{"flomesh.io/mesh-service-sync":"machine"}}}'  --type=merge

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
