#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

CTR_REGISTRY="${CTR_REGISTRY:-cybwan}"
CTR_TAG="${CTR_TAG:-1.4.0-alpha.3}"
IMAGE_PULL_POLICY="${IMAGE_PULL_POLICY:-Always}"

fsm_namespace="${fsm_namespace:-fsm-system}"
fsm_mesh_name="${fsm_mesh_name:-fsm}"

fsm_cluster_name="${fsm_cluster_name:-fsm}"

dns_svc_ip="$(kubectl get svc -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].spec.clusterIP}')"
clusters="${clusters:-c0}"

fsm install \
    --mesh-name "$fsm_mesh_name" \
    --fsm-namespace "$fsm_namespace" \
    --set=fsm.image.registry="$CTR_REGISTRY" \
    --set=fsm.image.tag="$CTR_TAG" \
    --set=fsm.image.pullPolicy="$IMAGE_PULL_POLICY" \
    --set=fsm.sidecar.sidecarLogLevel=warn \
    --set=fsm.controllerLogLevel=warn \
    --set=clusterSet.region=LN \
    --set=clusterSet.zone=DL \
    --set=clusterSet.group=FLOMESH \
    --set=clusterSet.name="$fsm_cluster_name" \
    --set=fsm.ztm.enabled=true \
    --set=fsm.localDNSProxy.enable=true \
    --set=fsm.localDNSProxy.wildcard.enable=false \
    --set=fsm.localDNSProxy.primaryUpstreamDNSServerIPAddr=$dns_svc_ip \
    --timeout=900s