#!/usr/bin/env bash
# Recover and build the public Go source revision recorded in v1.2.25.2802.
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source_dir="$project_dir/.dart_tool/reconstruction/sing-box"
output_dir=${1:-"$project_dir/bind/linux/core"}
source_revision=93f6a441a141cc4b5914a4c63dd97c77bc69281c
source_repository=https://github.com/KaringX/sing-box.git
build_tags=with_karing,with_acme,with_quic,with_dhcp,with_shadowsocksr,with_wireguard,with_grpc,with_gvisor,with_utls,with_clash_api,with_conntrack,with_tailscale,with_naive_outbound,with_purego

# go-json-experiment/json at the recorded version requires this Go release.
export GOTOOLCHAIN=go1.26.6
export CGO_ENABLED=1
export GOOS=linux
export GOARCH=amd64
export GOAMD64=v1
export TMPDIR=${TMPDIR:-"$project_dir/.dart_tool/linux-core-tmp"}
mkdir -p -- "$TMPDIR"

if [[ ! -d "$source_dir/.git" ]]; then
  if [[ -e "$source_dir" ]]; then
    printf 'Source directory exists without Git metadata: %s\n' "$source_dir" >&2
    exit 1
  fi
  mkdir -p -- "$(dirname -- "$source_dir")"
  git init --quiet "$source_dir"
  git -C "$source_dir" remote add origin "$source_repository"
  git -C "$source_dir" fetch --depth=1 origin "$source_revision"
  git -C "$source_dir" checkout --quiet --detach FETCH_HEAD
fi

actual_revision=$(git -C "$source_dir" rev-parse HEAD)
if [[ "$actual_revision" != "$source_revision" ]]; then
  printf 'Expected source revision %s, found %s in %s\n' "$source_revision" "$actual_revision" "$source_dir" >&2
  exit 1
fi
if [[ -n $(git -C "$source_dir" status --porcelain --untracked-files=no) ]]; then
  printf 'Source has local changes; refusing to label it as the pinned revision: %s\n' "$source_dir" >&2
  exit 1
fi

mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
cd -- "$source_dir"
go build -mod=readonly -p "${KARING_CORE_BUILD_JOBS:-2}" -trimpath \
  -tags "$build_tags" \
  -ldflags '-s -w -X github.com/sagernet/sing-box/constant.Version=1.13.0-karing-reconstructed' \
  -o "$output_dir/karingService" ./cmd/sing-box

# The with_purego Naive outbound dynamically loads this pinned Go dependency.
cronet_dir=$(go list -m -f '{{.Dir}}' github.com/sagernet/cronet-go/lib/linux_amd64)
install -m 644 -- "$cronet_dir/libcronet.so" "$output_dir/libcronet.so"
install -m 644 -- LICENSE "$output_dir/LICENSE-sing-box"
install -m 644 -- "$cronet_dir/LICENSE" "$output_dir/LICENSE-cronet"
printf 'Built Linux amd64 backend and Cronet runtime in %s\n' "$output_dir"
