#!/usr/bin/env bash

#
# Same test for Lab-1 and Lab-2
#
set -euo pipefail

k apply -f app-space/

for name in overlays/*; do k apply -k $name/; done

CILIUM_GATEWAY=$(kubectl -n cilium-gw get gateway cilium-gw -o jsonpath='{.status.addresses[0].value}')
echo $CILIUM_GATEWAY
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/original-prefix
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/path-and-host
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/path-and-status
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/scheme-and-host
curl -vs http://$CILIUM_GATEWAY/prefix/one | jq .
curl -vs http://$CILIUM_GATEWAY/prefix/rewrite-path-and-modify-headers | jq .
curl -vs http://$CILIUM_GATEWAY/mirror | jq .


NGINX_GATEWAY=$(kubectl -n nginx-gw get gateway nginx-gw -o jsonpath='{.status.addresses[0].value}')
echo $NGINX_GATEWAY
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/original-prefix
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/path-and-host
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/path-and-status
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/scheme-and-host
curl -vs http://$NGINX_GATEWAY/prefix/one | jq .
curl -vs http://$NGINX_GATEWAY/prefix/rewrite-path-and-modify-headers | jq .
curl -vs http://$NGINX_GATEWAY/mirror

ENVOY_GATEWAY=$(kubectl -n envoy-gw get gateway envoy-gw -o jsonpath='{.status.addresses[0].value}')
echo $ENVOY_GATEWAY
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/original-prefix
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/path-and-host
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/path-and-status
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/scheme-and-host
curl -vs http://$ENVOY_GATEWAY/prefix/one | jq .
curl -vs http://$ENVOY_GATEWAY/prefix/rewrite-path-and-modify-headers | jq .
curl -vs http://$ENVOY_GATEWAY/mirror | jq .

k apply -f reference-grant/

CILIUM_GATEWAY=$(kubectl -n cilium-gw get gateway cilium-gw -o jsonpath='{.status.addresses[0].value}')
echo $CILIUM_GATEWAY
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/original-prefix
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/path-and-host
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/path-and-status
curl -I -w "%{http_code}\n\n" http://$CILIUM_GATEWAY/scheme-and-host
curl -s http://$CILIUM_GATEWAY/prefix/one | jq .
curl -s http://$CILIUM_GATEWAY/prefix/rewrite-path-and-modify-headers | jq .
curl -s http://$CILIUM_GATEWAY/mirror | jq .


NGINX_GATEWAY=$(kubectl -n nginx-gw get gateway nginx-gw -o jsonpath='{.status.addresses[0].value}')
echo $NGINX_GATEWAY
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/original-prefix
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/path-and-host
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/path-and-status
curl -I -w "%{http_code}\n\n" http://$NGINX_GATEWAY/scheme-and-host
curl -s http://$NGINX_GATEWAY/prefix/one | jq .
curl -s http://$NGINX_GATEWAY/prefix/rewrite-path-and-modify-headers | jq .
curl -s http://$NGINX_GATEWAY/mirror

ENVOY_GATEWAY=$(kubectl -n envoy-gw get gateway envoy-gw -o jsonpath='{.status.addresses[0].value}')
echo $ENVOY_GATEWAY
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/original-prefix
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/path-and-host
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/path-and-status
curl -I -w "%{http_code}\n\n" http://$ENVOY_GATEWAY/scheme-and-host
curl -s http://$ENVOY_GATEWAY/prefix/one | jq .
curl -s http://$ENVOY_GATEWAY/prefix/rewrite-path-and-modify-headers | jq .
curl -s http://$ENVOY_GATEWAY/mirror | jq .

for name in overlays/*; do k delete -k $name/; done
k delete -f reference-grant/
k delete -f app-space/
