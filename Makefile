#!/bin/bash

fsm_cluster_name ?= fsm
PORT_FORWARD ?= 14001:14001
WITH_MESH ?= false

.PHONY: k3d-up
k3d-up:
	./scripts/k3d-with-registry-multicluster.sh
	kubecm list

.PHONY: k3d-reset
k3d-reset:
	./scripts/k3d-multicluster-cleanup.sh

.PHONY: deploy-fsm
deploy-fsm:
	$fsm_cluster_name=$(fsm_cluster_name) scripts/deploy-fsm.sh

.PHONY: hello-deploy
hello-deploy:
	kubectl apply -n default -f ./manifests/hello.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=hello --timeout=180s

.PHONY: hello-reboot
hello-reboot:
	kubectl rollout restart deployment -n default hello

.PHONY: curl-deploy
curl-deploy:
	kubectl apply -n default -f ./manifests/curl.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=curl --timeout=180s

.PHONY: curl-reboot
curl-reboot:
	kubectl rollout restart deployment -n default curl

.PHONY: ztm-ca-deploy
ztm-ca-deploy:
	kubectl apply -n default -f ./manifests/ztm-ca.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=ztm-ca --timeout=180s

.PHONY: ztm-hub-deploy
ztm-hub-deploy:
	kubectl apply -n default -f ./manifests/ztm-hub.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=ztm-hub --timeout=180s
