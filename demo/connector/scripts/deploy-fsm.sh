#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

fsm_namespace="${fsm_namespace:-fsm-system}"
fsm_mesh_name="${fsm_mesh_name:-fsm}"

fsm_cluster_name="${fsm_cluster_name:-fsm}"

dns_svc_ip="$(kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}')"
clusters="${clusters:-c0}"

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.image.registry=localhost:5000/flomesh \
    --set=fsm.image.tag=latest \
    --set=fsm.image.pullPolicy=Always \
    --set=fsm.sidecar.sidecarLogLevel=warn \
    --set=fsm.controllerLogLevel=warn \
    --set=fsm.serviceAccessMode=mixed \
    --set=fsm.featureFlags.enableAutoDefaultRoute=true \
    --set=clusterSet.region=LN \
    --set=clusterSet.zone=DL \
    --set=clusterSet.group=FLOMESH \
    --set=clusterSet.name="$fsm_cluster_name" \
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
    --set=fsm.featureFlags.enableSidecarPrettyConfig=true \
    --timeout=900s

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