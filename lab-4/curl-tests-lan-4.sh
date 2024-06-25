#!/usr/bin/env bash
set -euo pipefail

k apply -f kopi-teh-space/

for name in overlays/*; do k apply -k $name/; done

TMPD=$(mktemp -d)
pushd "$TMPD"
for name in nginx cilium envoy
do
  k -n "$name"-gw get secret root-secret -oyaml | \
  yq '.data."ca.crt"' | \
  base64 -d | \
  tee "$name"-gw-ca.crt
done

CILIUM_GATEWAY=$(kubectl -n cilium-gw get gateway cilium-gw -o jsonpath='{.status.addresses[0].value}')
printf "cilium-gw: %s\n\n" $CILIUM_GATEWAY
for kopiteh in coffee tea
do
  echo cilium-"$kopiteh"
  for count in {1..6}
  do
    curl -sSL --cacert cilium-gw-ca.crt --resolve www.kopi-teh.com:443:"$CILIUM_GATEWAY" https://www.kopi-teh.com/"$kopiteh" | \
    jq .Hostname
  done
done

NGINX_GATEWAY=$(kubectl -n nginx-gw get gateway nginx-gw -o jsonpath='{.status.addresses[0].value}')
printf "nginx-gw: %s\n\n" $NGINX_GATEWAY
for kopiteh in coffee tea
do
  echo nginx-"$kopiteh"
  for count in {1..6}
  do
    curl -sSL --cacert nginx-gw-ca.crt --resolve www.kopi-teh.com:443:"$NGINX_GATEWAY" https://www.kopi-teh.com/"$kopiteh" | \
    jq .Hostname
  done
done

ENVOY_GATEWAY=$(kubectl -n envoy-gw get gateway envoy-gw -o jsonpath='{.status.addresses[0].value}')
printf "envoy-gw: %s\n\n" $ENVOY_GATEWAY
for kopiteh in coffee tea
do
  echo envoy-"$kopiteh"
  for count in {1..6}
  do
    curl -sSL --cacert envoy-gw-ca.crt --resolve www.kopi-teh.com:443:"$ENVOY_GATEWAY" https://www.kopi-teh.com/"$kopiteh" | \
    jq .Hostname
  done
done

popd
rm -rf $TMPD

k delete -f kopi-teh-space/

for name in overlays/*; do k delete -k $name/; done
