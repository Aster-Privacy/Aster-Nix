#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl gh jq

set -euo pipefail

repo="Aster-Privacy/Aster-Bridge"
dir="$(dirname "$(readlink -f "$0")")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

release="$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/repos/$repo/releases/latest")"
version="$(jq -r '.tag_name | ltrimstr("v")' <<<"$release")"
current="$(jq -r .version "$dir/sources.json")"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "$repo published an unexpected version: $version" >&2
  exit 1
fi

if [[ "$version" == "$current" ]]; then
  echo "aster-bridge is up to date at $version"
  exit 0
fi

if [[ "$(printf '%s\n' "$current" "$version" | sort -V | tail -n 1)" != "$version" ]]; then
  echo "refusing to move aster-bridge from $current back to $version" >&2
  exit 1
fi

sri() {
  local name="$1" digest file actual
  digest="$(jq -er --arg n "$name" '.assets[] | select(.name == $n) | .digest' <<<"$release")"
  if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    echo "$name has no SHA-256 digest in the release" >&2
    exit 1
  fi
  file="$work/$name"
  curl -fsSL -o "$file" "https://github.com/$repo/releases/download/v$version/$name"
  actual="$(sha256sum "$file" | cut -d ' ' -f 1)"
  if [[ "sha256:$actual" != "$digest" ]]; then
    echo "$name doesn't match the digest published with the release" >&2
    exit 1
  fi
  if ! gh attestation verify "$file"     --repo "$repo"     --signer-workflow "$repo/.github/workflows/release.yml"     --source-ref "refs/tags/v$version"     --deny-self-hosted-runners >/dev/null; then
    echo "$name wasn't built by the release workflow for v$version" >&2
    exit 1
  fi
  nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "${digest#sha256:}"
}

x86="$(sri "Aster.Bridge_${version}_amd64.deb")"
arm="$(sri "Aster.Bridge_${version}_arm64.deb")"

jq -n \
  --arg version "$version" \
  --arg x86 "$x86" \
  --arg arm "$arm" \
  '{
    version: $version,
    assets: {
      "x86_64-linux": { arch: "amd64", hash: $x86 },
      "aarch64-linux": { arch: "arm64", hash: $arm }
    }
  }' >"$dir/sources.json"

echo "aster-bridge updated to $version"
