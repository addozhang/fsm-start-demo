# 场景 单服务单副本

## 1 部署 C1 C2 C3 三个集群

```bash
export clusters="C1 C2 C3"
make k3d-up
```

## 2 部署服务

### 2.1 C1集群

```bash
kubecm switch k3d-C1
```

#### 2.1.1 部署 ZTM CA 服务

```bash
make ztm-ca-deploy

export ztm_ca_external_ip="$(kubectl get svc -n default --field-selector metadata.name=ztm-ca -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo ztm_ca_external_ip $ztm_ca_external_ip

export ztm_ca_pod="$(kubectl get pod -n default --selector app=ztm-ca -o jsonpath='{.items[0].metadata.name}')"
echo ztm_ca_pod $ztm_ca_pod
```

#### 2.1.2 部署 ZTM HUB 服务

```bash
make ztm-hub-deploy

export ztm_hub_external_ip="$(kubectl get svc -n default --field-selector metadata.name=ztm-hub -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')"
echo ztm_hub_external_ip $ztm_hub_external_ip

export ztm_hub_pod="$(kubectl get pod -n default --selector app=ztm-hub -o jsonpath='{.items[0].metadata.name}')"
echo ztm_hub_pod $ztm_hub_pod
```

#### 2.1.3 创建 ZTM 用户

```bash
kubectl exec -n default $ztm_ca_pod -- ztm evict fsm
kubectl exec -n default $ztm_ca_pod -- ztm invite fsm -b $ztm_ca_external_ip:8888 > /tmp/fsm.perm.json
```

### 2.2 C2集群

```bash
kubecm switch k3d-C2
```

#### 2.2.1 部署 k8s hello 服务

```bash
replicas=1 cluster=C2 make hello-deploy

export c2_hello_1_pod_ip="$(kubectl get pod -n default --selector app=hello -o jsonpath='{.items[0].status.podIP}')"
echo c2_hello_1_pod_ip $c2_hello_1_pod_ip

export c2_hello_svc_port="$(kubectl get -n default svc hello -o jsonpath='{.spec.ports[0].port}')"
echo c2_hello_svc_port $c2_hello_svc_port

export c2_hello_svc_target_port="$(kubectl get -n default svc hello -o jsonpath='{.spec.ports[0].targetPort}')"
echo c2_hello_svc_target_port $c2_hello_svc_target_port

make curl-deploy

export c2_curl_pod="$(kubectl get pod -n default --selector app=curl -o jsonpath='{.items[0].metadata.name}')"
echo c2_curl_pod $c2_curl_pod

kubectl exec $c2_curl_pod -n default -- curl -s http://hello.default:$c2_hello_svc_port
```

#### 2.2.2 部署 FSM Mesh

```bash
fsm_cluster_name=C2 make deploy-fsm
```

#### 2.2.3 创建 ZTM Agent

```bash
kubectl apply  -f - <<EOF
kind: Agent
apiVersion: ztm.flomesh.io/v1alpha1
metadata:
  name: c2-agent
spec:
  permit:
    bootstraps: $(cat /tmp/fsm.perm.json | jq .bootstraps)
    ca: $(cat /tmp/fsm.perm.json | jq .ca)
    agent:
      privateKey: $(cat /tmp/fsm.perm.json | jq .agent.privateKey)
      certificate: $(cat /tmp/fsm.perm.json | jq .agent.certificate)
  joinMeshes:
  - meshName: k8s
    serviceExports:
    - protocol: tcp
      name: hello
      ip: $c2_hello_1_pod_ip
      port: $c2_hello_svc_target_port
EOF
```

### 2.3 C3集群

```bash
kubecm switch k3d-C3
```

#### 2.3.1 部署 curl 服务

```bash
make curl-deploy

export c3_curl_pod="$(kubectl get pod -n default --selector app=curl -o jsonpath='{.items[0].metadata.name}')"
echo c3_curl_pod $c3_curl_pod
```

#### 2.3.2 部署 FSM Mesh

```bash
fsm_cluster_name=C3 make deploy-fsm
```

#### 2.3.3 创建 ZTM Agent

```bash
kubectl apply  -f - <<EOF
kind: Agent
apiVersion: ztm.flomesh.io/v1alpha1
metadata:
  name: c3-agent
spec:
  permit:
    bootstraps: $(cat /tmp/fsm.perm.json | jq .bootstraps)
    ca: $(cat /tmp/fsm.perm.json | jq .ca)
    agent:
      privateKey: $(cat /tmp/fsm.perm.json | jq .agent.privateKey)
      certificate: $(cat /tmp/fsm.perm.json | jq .agent.certificate)
  joinMeshes:
  - meshName: k8s
    serviceImports:
    - protocol: tcp
      name: hello
      ip: 0.0.0.0
      port: $c2_hello_svc_target_port
EOF
```

#### 2.3.4 部署 k8s hello 服务

```bash
replicas=1 cluster=C3 make hello-deploy
```

#### 2.3.5 创建 k8s hello 服务的 ztm EndpointSlice

```bash
export c3_ztm_agent_pod_ip="$(kubectl get pod -n fsm-system --selector app=fsm-ztmagent-c3-agent -o jsonpath='{.items[0].status.podIP}')"
echo c3_ztm_agent_pod_ip $c3_ztm_agent_pod_ip

kubectl apply  -f - <<EOF
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: hello-ztm-agent
  labels:
    kubernetes.io/service-name: hello
addressType: IPv4
ports:
  - name: http
    port: $c2_hello_svc_target_port
endpoints:
  - addresses:
      - $c3_ztm_agent_pod_ip
EOF

# headless service
#kubectl apply  -f - <<EOF
#apiVersion: v1
#kind: Service
#metadata:
#  name: hello
#spec:
#  clusterIP: None
#  ports:
#    - name: http
#      port: $c2_hello_svc_port
#      targetPort: $c2_hello_svc_target_port
#EOF

# clusterIP service
#kubectl apply  -f - <<EOF
#apiVersion: v1
#kind: Service
#metadata:
#  name: hello
#  labels:
#    service: hello
#spec:
#  selector:
#    app: hello
#  ports:
#    - name: hello
#      port: $c2_hello_svc_port
#      targetPort: $c2_hello_svc_target_port
#EOF
```

#### 2.3.5 测试 hello 服务

```bash
kubectl exec $c3_curl_pod -n default -- curl -s http://$c3_ztm_agent_pod_ip:$c2_hello_svc_target_port

kubectl exec $c3_curl_pod -n default -- curl -s http://hello:$c2_hello_svc_port
```

## 3 卸载 C1 C2 C3 三个集群

```bash
export clusters="C1 C2 C3"
make k3d-reset
```





```
kubectl apply  -f - <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: f4gw
  labels:
    k8s-app: f4gw
spec:
  selector:
    matchLabels:
      name: f4gw
  template:
    metadata:
      labels:
        name: f4gw
    spec:
      hostNetwork: true
      containers:
      - name: f4gw
        image: cybwan/ebpf-build:latest
        imagePullPolicy: Always
        securityContext:
          privileged: true
        command: ["sleep", "365d"]
        resources:
          limits:
            memory: 1024Mi
          requests:
            cpu: 600m
            memory: 1024Mi
EOF

clear;sudo cat /sys/kernel/debug/tracing/trace_pipe|grep bpf_trace_printk

git clone https://github.com/cybwan/f4gw-cni.git -b release/v0.1

export https_proxy=http://192.168.226.1:7890 http_proxy=http://192.168.226.1:7890 all_proxy=socks5://192.168.226.1:7890

unset https_proxy http_proxy all_proxy

curl 39.156.66.14 -I

10.42.0.1       16787978
10.42.0.2       33565194
10.42.0.3       50342410
10.42.0.4       67119626
10.42.0.5       83896842
10.42.0.6       100674058
10.42.0.7       117451274
10.42.0.8       134228490
10.42.0.9       151005706
172.18.0.3      50336428
39.156.66.14    239246375

curl 69.162.80.61 -I

curl 172.18.0.3 -I

iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -t nat -A POSTROUTING -o ens33 -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward

alias h1="sudo ip netns exec h1"
h1 curl 39.156.66.14 -I

https://tldp.org/HOWTO/html_single/Masquerading-Simple-HOWTO/
https://atbug.com/cross-node-traffic-on-flannel-vxlan-network/

sudo apt install -y \
linux-modules-5.15.0-113-generic \
linux-headers-5.15.0-113-generic \
linux-image-5.15.0-113-generic

sudo apt -y --fix-broken install

replicas=1 cluster=C1 make hello-deploy

kubectl apply  -f - <<EOF
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: hello-ztm-agent
  labels:
    kubernetes.io/service-name: hello
addressType: IPv4
ports:
  - name: http
    port: 14001
endpoints:
  - addresses:
      - 192.168.226.63
EOF
```

