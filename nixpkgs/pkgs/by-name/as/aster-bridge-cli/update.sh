#!/usr/bin/env nix-shell
#!nix-shell -i bash -p coreutils curl gnugrep gnused jq nix-update

set -euo pipefail

repo="Aster-Privacy/Aster-Bridge"
dir="$(dirname "$(readlink -f "$0")")"
cli="$dir/package.nix"
desktop="$dir/../aster-bridge/package.nix"
cd "$dir/../../../.."

auth=(${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"})
version="$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" | jq -r '.tag_name | ltrimstr("v")')"
current="$(nix-instantiate --eval --raw -A aster-bridge-cli.version)"

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

pins="$(curl -fsSL "https://raw.githubusercontent.com/$repo/v$version/.github/source_pins.env")"
pin() {
  local rev
  rev="$(sed -n "s/^$1=\([0-9a-f]\{40\}\)$/\1/p" <<<"$pins")"
  if [[ -z "$rev" ]]; then
    echo "$repo v$version has no valid $1" >&2
    exit 1
  fi
  echo "$rev"
}
mail_rev="$(pin ASTER_MAIL_REV)"
ui_rev="$(pin ASTER_UI_REV)"

nix-update aster-bridge-cli --version "$version"

sed -i "s/rev = \"[0-9a-f]\{40\}\";/rev = \"$mail_rev\";/" "$cli"
sed -i "s/rev = \"[0-9a-f]\{40\}\";/rev = \"$ui_rev\";/" "$desktop"

refresh() {
  local file="$1" attr="$2" old new
  old="$(nix-instantiate --eval --raw -A "$attr.outputHash")"
  sed -i "s|\"$old\"|lib.fakeHash|" "$file"
  new="$( (nix-build --no-out-link -A "$attr" 2>&1 || true) | sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\)$/\1/p' | head -n 1)"
  if [[ -z "$new" ]]; then
    new="$old"
  fi
  sed -i "s|lib.fakeHash|\"$new\"|" "$file"
}

refresh "$cli" aster-bridge-cli.mail-src
refresh "$desktop" aster-bridge.ui-src
refresh "$desktop" aster-bridge.aster-ui.npmDeps
refresh "$desktop" aster-bridge.npmDeps
