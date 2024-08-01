#!/bin/bash

fsm_cluster_name ?= fsm
PORT_FORWARD ?= 14001:14001
WITH_MESH ?= false
replicas ?= 1
cluster ?= c0
names ?= 0.0.0.0

.PHONY: k3d-up
k3d-up:
	./scripts/k3d-with-registry-multicluster.sh
	kubecm list

.PHONY: k3d-proxy-up
k3d-proxy-up:
	./scripts/k3d-with-registry-multicluster-with-proxy.sh
	kubecm list

.PHONY: k3d-reset
k3d-reset:
	./scripts/k3d-multicluster-cleanup.sh

.PHONY: deploy-fsm
deploy-fsm:
	$fsm_cluster_name=$(fsm_cluster_name) scripts/deploy-fsm.sh

.PHONY: httpbin-deploy
httpbin-deploy:
	kubectl get namespace demo >> /dev/null 2>&1 || kubectl create namespace demo
	if [ "$(WITH_MESH)" = "true" ]; then fsm namespace add demo; fi
	replicas=$(replicas) cluster=$(cluster) envsubst < ./manifests/httpbin.yaml | kubectl apply -n demo -f -
	sleep 2
	kubectl wait --all --for=condition=ready pod -n demo -l app=httpbin --timeout=180s

.PHONY: httpbin-reboot
httpbin-reboot:
	kubectl rollout restart deployment -n demo httpbin

.PHONY: curl-deploy
curl-deploy:
	kubectl get namespace demo >> /dev/null 2>&1 || kubectl create namespace demo
	if [ "$(WITH_MESH)" = "true" ]; then fsm namespace add demo; fi
	kubectl apply -n demo -f ./manifests/curl.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n demo -l app=curl --timeout=180s

.PHONY: curl-reboot
curl-reboot:
	kubectl rollout restart deployment -n demo curl

.PHONY: ztm-svc-deploy
ztm-svc-deploy:
	kubectl apply -n default -f ./manifests/ztm-svc.yaml
	sleep 2
	kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' -n default service/ztm-hub

.PHONY: ztm-hub-deploy
ztm-hub-deploy:
	names=$(names) envsubst < ./manifests/ztm-hub.yaml | kubectl apply -n default -f -
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=ztm-hub --timeout=180s
