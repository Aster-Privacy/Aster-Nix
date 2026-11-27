#!/usr/bin/env bash
set -euo pipefail

kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$(cd "${1:?usage: update.sh <nixpkgs checkout>}" && pwd)"
: "${GH_TOKEN:?GH_TOKEN must be set}"

bash "$kit/scripts/apply.sh" "$target"
cd "$target"
export NIX_PATH="nixpkgs=$target"

die() {
  echo "$*" >&2
  exit 1
}

eval_raw() {
  nix-instantiate --eval --raw -A "$1"
}

latest_version() {
  local version
  version="$(gh api "repos/$1/releases/latest" --jq '.tag_name | ltrimstr("v")')"
  [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "$1 published an unexpected version: $version"
  echo "$version"
}

is_newer() {
  [[ "$1" != "$2" && "$(printf '%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$2" ]]
}

tag_commit() {
  local repo="$1" tag="$2" type sha
  read -r type sha < <(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.type + " " + .object.sha')
  for _ in 1 2 3; do
    [[ "$type" == "tag" ]] || break
    read -r type sha < <(gh api "repos/$repo/git/tags/$sha" --jq '.object.type + " " + .object.sha')
  done
  [[ "$type" == "commit" ]] || die "$repo $tag does not point to a commit"
  echo "$sha"
}

require_trusted_commit() {
  local repo="$1" sha="$2" verified status
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "$repo: not a commit hash: $sha"
  verified="$(gh api "repos/$repo/commits/$sha" --jq '.commit.verification.verified')"
  [[ "$verified" == "true" ]] || die "$repo $sha is not a verified commit"
  status="$(gh api "repos/$repo/compare/$sha...main" --jq '.status')"
  [[ "$status" == "ahead" || "$status" == "identical" ]] || die "$repo $sha is not on main"
}

source_hash() {
  local hash
  hash="$( (nix-build --no-out-link -E "with import ./. { }; fetchFromGitHub { owner = \"Aster-Privacy\"; repo = \"$1\"; rev = \"$2\"; hash = lib.fakeHash; }" 2>&1 || true) |
    sed -n 's/^ *got: *\(sha256-[A-Za-z0-9+/=]*\)$/\1/p' | head -n 1)"
  [[ -n "$hash" ]] || die "could not hash Aster-Privacy/$1 at $2"
  echo "$hash"
}

require_source() {
  local attr="$1" repo="$2" tag="$3" sha expected actual
  sha="$(tag_commit "Aster-Privacy/$repo" "$tag")"
  require_trusted_commit "Aster-Privacy/$repo" "$sha"
  expected="$(source_hash "$repo" "$sha")"
  actual="$(eval_raw "$attr.outputHash")"
  [[ "$expected" == "$actual" ]] || die "$attr hash $actual does not match $repo $tag ($sha)"
}

mail_current="$(eval_raw aster-mail.version)"
mail_latest="$(latest_version Aster-Privacy/Aster-Mail)"
if is_newer "$mail_current" "$mail_latest"; then
  require_trusted_commit Aster-Privacy/Aster-Mail "$(tag_commit Aster-Privacy/Aster-Mail "v$mail_latest")"
  env -u GH_TOKEN nix-shell -p nix-update --run "nix-update aster-mail --version $mail_latest"
  [[ "$(eval_raw aster-mail.version)" == "$mail_latest" ]] || die "aster-mail did not move to $mail_latest"
fi

bridge_current="$(eval_raw aster-bridge-cli.version)"
bridge_latest="$(latest_version Aster-Privacy/Aster-Bridge)"
if is_newer "$bridge_current" "$bridge_latest"; then
  require_trusted_commit Aster-Privacy/Aster-Bridge "$(tag_commit Aster-Privacy/Aster-Bridge "v$bridge_latest")"
  GITHUB_TOKEN="$GH_TOKEN" env -u GH_TOKEN pkgs/by-name/as/aster-bridge-cli/update.sh
  [[ "$(eval_raw aster-bridge-cli.version)" == "$bridge_latest" ]] || die "aster-bridge-cli did not move to $bridge_latest"
fi

mail_version="$(eval_raw aster-mail.version)"
bridge_version="$(eval_raw aster-bridge-cli.version)"
[[ "$(eval_raw aster-bridge.version)" == "$bridge_version" ]] || die "aster-bridge and aster-bridge-cli versions differ"

require_source aster-mail.src Aster-Mail "v$mail_version"
require_source aster-bridge-cli.src Aster-Bridge "v$bridge_version"
require_trusted_commit Aster-Privacy/Aster-Mail "$(eval_raw aster-bridge-cli.mail-src.rev)"
require_trusted_commit Aster-Privacy/aster-ui "$(eval_raw aster-bridge.ui-src.rev)"

for name in aster-bridge-cli aster-bridge aster-mail; do
  cp "pkgs/by-name/as/$name/package.nix" "$kit/pkgs/by-name/as/$name/package.nix"
done

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "mail=$mail_version"
    echo "bridge=$bridge_version"
  } >>"$GITHUB_OUTPUT"
fi
echo "aster-mail $mail_version, aster-bridge $bridge_version"
