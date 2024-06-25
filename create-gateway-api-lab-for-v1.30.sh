#!/usr/bin/env bash
set -euo pipefail
yq '.networking.kubeProxyMode = "none"' ~/Projects/kind/kind.yaml | kind create cluster --config -
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.1.0/config/crd/experimental/gateway.networking.k8s.io_backendtlspolicies.yaml
cilium install --namespace kube-system --version v1.16.0-rc.0 \
               --set l2announcements.enabled=true \
               --set gatewayAPI.enabled=true
#               --set envoy.enabled=true
cilium hubble enable
cilium status --wait
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb --namespace metallb-system --create-namespace --set loadBalancerClass=metallb
kubectl wait --namespace metallb-system \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=metallb \
             --timeout=120s
k apply -f - <<EOF
---
apiVersion: cilium.io/v2alpha1
kind: CiliumL2AnnouncementPolicy
metadata:
  name: policy1
spec:
  nodeSelector:
    matchExpressions:
      - key: node-role.kubernetes.io/control-plane
        operator: DoesNotExist
  externalIPs: true
  loadBalancerIPs: true
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: cilium-pool
spec:
  blocks:
  - start: 10.254.254.240
    stop: 10.254.254.247
EOF
kubectl apply -f - <<EOF
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 10.254.254.248-10.254.254.254
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
    - default
  nodeSelectors:
    - matchLabels:
        kubernetes.io/hostname: kind-worker
    - matchLabels:
        kubernetes.io/hostname: kind-worker2
EOF

pushd /tmp
helm pull oci://ghcr.io/nginxinc/charts/nginx-gateway-fabric
tar -zxvf $(ls nginx-gateway*tgz)
sed -i -E '/spec:/s/spec:/spec:\n{{- if and (eq .Values.service.type "LoadBalancer") (.Values.service.loadBalancerClass) }}\n  loadBalancerClass: {{ .Values.service.loadBalancerClass }}\n{{- end}}/' nginx-gateway-fabric/templates/service.yaml
sed -i -E '/service:/s/service:/service:\n  loadBalancerClass: ""/' nginx-gateway-fabric/values.yaml
helm install ngf ./nginx-gateway-fabric \
             --create-namespace \
             --namespace nginx-gateway \
             --set service.loadBalancerClass=metallb \
             --set nginxGateway.gwAPIExperimentalFeatures.enable=true \
             --set nginxGateway.productTelemetry.enable=false
kubectl wait --namespace nginx-gateway \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=nginx-gateway-fabric \
             --timeout=120s
popd
helm install eg oci://docker.io/envoyproxy/gateway-helm \
             --version v0.0.0-latest \
             --namespace envoy-gateway-system \
             --create-namespace
kubectl wait --namespace envoy-gateway-system \
             --for=condition=Available \
             --timeout=5m \
             deployment/envoy-gateway
kubectl apply -f - <<EOF
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: custom-proxy-config
    namespace: envoy-gateway-system
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: custom-proxy-config
  namespace: envoy-gateway-system
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyService:
        loadBalancerClass: metallb
EOF

helm repo add jetstack https://charts.jetstack.io
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.15.0 \
  --set crds.enabled=true \
  --set "extraArgs={--enable-gateway-api=true}"