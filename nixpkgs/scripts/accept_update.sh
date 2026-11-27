#!/usr/bin/env bash
set -euo pipefail

update="$(cd "${1:?usage: accept_update.sh <artifact directory>}" && pwd)"
cd "$(dirname "${BASH_SOURCE[0]}")/../.."

die() {
  echo "$*" >&2
  exit 1
}

names=(aster-bridge-cli aster-bridge aster-mail)
expected="$(printf 'd %s\nf %s/package.nix\n' "${names[0]}" "${names[0]}" "${names[1]}" "${names[1]}" "${names[2]}" "${names[2]}" | LC_ALL=C sort)"
found="$(cd "$update" && find . -mindepth 1 -printf '%y %P\n' | LC_ALL=C sort)"
[[ "$found" == "$expected" ]] || die "unexpected files in the update: $found"

for name in "${names[@]}"; do
  file="$update/$name/package.nix"
  [[ -f "$file" && ! -L "$file" ]] || die "$name/package.nix is not a regular file"
  (($(stat -c %s "$file") < 65536)) || die "$name/package.nix is too large"
  cp -- "$file" "nixpkgs/pkgs/by-name/as/$name/package.nix"
done

changed="$(git status --porcelain --untracked-files=all)"
allowed="$(printf ' M nixpkgs/pkgs/by-name/as/%s/package.nix\n' "${names[@]}")"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  grep -qxF -- "$line" <<<"$allowed" || die "unexpected change: $line"
done <<<"$changed"

pattern="^[+-] *(version = \"[0-9]+\\.[0-9]+\\.[0-9]+\"|(hash|cargoHash) = \"sha256-[A-Za-z0-9+/]{43}=\"|rev = \"[0-9a-f]{40}\");$"
bad="$(git diff -U0 -- nixpkgs/pkgs/by-name/as | grep -E '^[+-]' | grep -Ev '^(\+\+\+|---) ' | grep -Ev "$pattern" || true)"
[[ -z "$bad" ]] || die "the update changes more than versions and hashes: $bad"

added="$(git diff -U0 -- nixpkgs/pkgs/by-name/as | grep -cE '^\+[^+]' || true)"
removed="$(git diff -U0 -- nixpkgs/pkgs/by-name/as | grep -cE '^-[^-]' || true)"
[[ "$added" == "$removed" ]] || die "the update adds or removes lines"
declare -A rev_repo=([aster-bridge-cli]=Aster-Privacy/Aster-Mail [aster-bridge]=Aster-Privacy/aster-ui)
for name in "${names[@]}"; do
  revs="$(git diff -U0 -- "nixpkgs/pkgs/by-name/as/$name/package.nix" | sed -n 's/^+ *rev = "\([0-9a-f]\{40\}\)";$/\1/p')"
  [[ -z "$revs" ]] && continue
  repo="${rev_repo[$name]:-}"
  [[ -n "$repo" ]] || die "$name has no pinned revision to change"
  for sha in $revs; do
    [[ "$(gh api "repos/$repo/commits/$sha" --jq '.commit.verification.verified')" == "true" ]] || die "$repo $sha is not a verified commit"
    status="$(gh api "repos/$repo/compare/$sha...main" --jq '.status')"
    [[ "$status" == "ahead" || "$status" == "identical" ]] || die "$repo $sha is not on main"
  done
done

git diff --stat -- nixpkgs
