#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl jq

set -euo pipefail

repo="Aster-Privacy/Aster-Bridge"
dir="$(dirname "$(readlink -f "$0")")"

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
current="$(jq -r .version "$dir/sources.json")"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "$repo published an unexpected version: $version" >&2
  exit 1
fi

if [[ "$version" == "$current" ]]; then
  echo "aster-bridge-cli is up to date at $version"
  exit 0
fi

if [[ "$(printf '%s\n' "$current" "$version" | sort -V | tail -n 1)" != "$version" ]]; then
  echo "refusing to move aster-bridge-cli from $current back to $version" >&2
  exit 1
fi

sri() {
  local name="$1" digest actual
  digest="$(jq -er --arg n "$name" '.assets[] | select(.name == $n) | .digest' <<<"$release")"
  if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "$name has no SHA-256 digest in the release" >&2
    exit 1
  fi
  actual="$(curl -fsSL "https://github.com/$repo/releases/download/v$version/$name" | sha256sum | cut -d ' ' -f 1)"
  if [[ "sha256:$actual" != "$digest" ]]; then
    echo "$name doesn't match the digest published with the release" >&2
    exit 1
  fi
  nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "${digest#sha256:}"
}

x86="$(sri "aster-bridge-cli-x86_64-unknown-linux-gnu.tar.gz")"
arm="$(sri "aster-bridge-cli-aarch64-unknown-linux-gnu.tar.gz")"

jq -n \
  --arg version "$version" \
  --arg x86 "$x86" \
  --arg arm "$arm" \
  '{
    version: $version,
    assets: {
      "x86_64-linux": { target: "x86_64-unknown-linux-gnu", hash: $x86 },
      "aarch64-linux": { target: "aarch64-unknown-linux-gnu", hash: $arm }
    }
  }' >"$dir/sources.json"

echo "aster-bridge-cli updated to $version"
