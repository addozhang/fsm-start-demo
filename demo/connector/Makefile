#!/bin/bash

fsm_cluster_name ?= fsm
PORT_FORWARD ?= 14001:14001

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

CONSUL_VERSION      ?= 1.5.3

.PHONY: consul-deploy
consul-deploy:
	kubectl apply -n default -f ./manifests/consul.$(CONSUL_VERSION).yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=consul --timeout=180s

.PHONY: consul-reboot
consul-reboot:
	kubectl rollout restart deployment -n default consul

.PHONY: eureka-deploy
eureka-deploy:
	kubectl apply -n default -f ./manifests/eureka.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=eureka --timeout=180s

.PHONY: eureka-reboot
eureka-reboot:
	kubectl rollout restart deployment -n default eureka

.PHONY: nacos-deploy
nacos-deploy:
	kubectl apply -n default -f ./manifests/nacos.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n default -l app=nacos --timeout=180s

.PHONY: nacos-reboot
nacos-reboot:
	kubectl rollout restart deployment -n default nacos

.PHONY: consul-port-forward
consul-port-forward:
	export POD=$$(kubectl get pods --selector app=consul -n default --no-headers | grep 'Running' | awk 'NR==1{print $$1}');\
	kubectl port-forward "$$POD" -n default 8500:8500 --address 0.0.0.0 &

.PHONY: eureka-port-forward
eureka-port-forward:
	export POD=$$(kubectl get pods --selector app=eureka -n default --no-headers | grep 'Running' | awk 'NR==1{print $$1}');\
	kubectl port-forward "$$POD" -n default 8761:8761 --address 0.0.0.0 &

.PHONY: nacos-port-forward
nacos-port-forward:
	export POD=$$(kubectl get pods --selector app=nacos -n default --no-headers | grep 'Running' | awk 'NR==1{print $$1}');\
	kubectl port-forward "$$POD" -n default 8848:8848 --address 0.0.0.0 &

.PHONY: deploy-consul-bookwarehouse
deploy-consul-bookwarehouse:
	#fsm namespace add bookwarehouse
	kubectl delete namespace bookwarehouse --ignore-not-found
	kubectl create namespace bookwarehouse
	kubectl apply -n bookwarehouse -f ./manifests/consul/bookwarehouse.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookwarehouse -l app=bookwarehouse --timeout=180s

.PHONY: deploy-consul-bookstore
deploy-consul-bookstore:
	#fsm namespace add bookstore
	kubectl delete namespace bookstore --ignore-not-found
	kubectl create namespace bookstore
	kubectl apply -n bookstore -f ./manifests/consul/bookstore.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookstore -l app=bookstore --timeout=180s

.PHONY: deploy-consul-bookbuyer
deploy-consul-bookbuyer:
	#fsm namespace add bookbuyer
	kubectl delete namespace bookbuyer --ignore-not-found
	kubectl create namespace bookbuyer
	kubectl apply -n bookbuyer -f ./manifests/consul/bookbuyer.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookbuyer -l app=bookbuyer --timeout=180s

.PHONY: deploy-eureka-bookwarehouse
deploy-eureka-bookwarehouse:
	#fsm namespace add bookwarehouse
	kubectl delete namespace bookwarehouse --ignore-not-found
	kubectl create namespace bookwarehouse
	kubectl apply -n bookwarehouse -f ./manifests/eureka/bookwarehouse.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookwarehouse -l app=bookwarehouse --timeout=180s

.PHONY: deploy-eureka-bookstore
deploy-eureka-bookstore:
	#fsm namespace add bookstore
	kubectl delete namespace bookstore --ignore-not-found
	kubectl create namespace bookstore
	kubectl apply -n bookstore -f ./manifests/eureka/bookstore.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookstore -l app=bookstore --timeout=180s

.PHONY: deploy-eureka-bookbuyer
deploy-eureka-bookbuyer:
	#fsm namespace add bookbuyer
	kubectl delete namespace bookbuyer --ignore-not-found
	kubectl create namespace bookbuyer
	kubectl apply -n bookbuyer -f ./manifests/eureka/bookbuyer.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookbuyer -l app=bookbuyer --timeout=180s

.PHONY: deploy-nacos-bookwarehouse
deploy-nacos-bookwarehouse:
	#fsm namespace add bookwarehouse
	kubectl delete namespace bookwarehouse --ignore-not-found
	kubectl create namespace bookwarehouse
	kubectl apply -n bookwarehouse -f ./manifests/nacos/bookwarehouse.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookwarehouse -l app=bookwarehouse --timeout=180s

.PHONY: deploy-nacos-bookstore
deploy-nacos-bookstore:
	#fsm namespace add bookstore
	kubectl delete namespace bookstore --ignore-not-found
	kubectl create namespace bookstore
	kubectl apply -n bookstore -f ./manifests/nacos/bookstore.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookstore -l app=bookstore --timeout=180s

.PHONY: deploy-nacos-bookbuyer
deploy-nacos-bookbuyer:
	#fsm namespace add bookbuyer
	kubectl delete namespace bookbuyer --ignore-not-found
	kubectl create namespace bookbuyer
	kubectl apply -n bookbuyer -f ./manifests/nacos/bookbuyer.yaml
	sleep 2
	kubectl wait --all --for=condition=ready pod -n bookbuyer -l app=bookbuyer --timeout=180s

.PHONY: bookbuyer-port-forward
bookbuyer-port-forward:
	export PORT_FORWARD=$(PORT_FORWARD);\
	export POD=$$(kubectl get pods --selector app=bookbuyer -n bookbuyer --no-headers | grep 'Running' | awk 'NR==1{print $$1}');\
	kubectl port-forward "$$POD" -n bookbuyer "$$PORT_FORWARD" --address 0.0.0.0