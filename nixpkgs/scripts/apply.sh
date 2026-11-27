#!/usr/bin/env bash
set -euo pipefail

kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="${1:?usage: apply.sh <nixpkgs checkout>}"
cd "$target"

rm -rf pkgs/by-name/as/aster-bridge pkgs/by-name/as/aster-bridge-cli pkgs/by-name/as/aster-mail
cp -r "$kit/pkgs/by-name/as/." pkgs/by-name/as/
chmod +x pkgs/by-name/as/aster-bridge-cli/update.sh
cp "$kit/nixos/modules/services/mail/aster-bridge.nix" nixos/modules/services/mail/
cp "$kit/nixos/tests/aster-bridge.nix" nixos/tests/

perl "$kit/scripts/insert_sorted.pl" maintainers/maintainer-list.nix '^  ([A-Za-z0-9_-]+) = \{' findleyl '  findleyl = {
    name = "Lucas";
    github = "findleyl";
    githubId = 257867858;
  };
'
perl "$kit/scripts/insert_sorted.pl" nixos/modules/module-list.nix '^  \./services/mail/([A-Za-z0-9_.-]+)$' aster-bridge.nix '  ./services/mail/aster-bridge.nix
'
perl "$kit/scripts/insert_sorted.pl" nixos/tests/all-tests.nix '^  ([A-Za-z0-9_-]+) = ' aster-bridge '  aster-bridge = runTest ./aster-bridge.nix;
' '^  aaaaxy = '

notes="$(printf '%s\n' nixos/doc/manual/release-notes/rl-*.section.md | sort -V | tail -n 1)"
perl "$kit/scripts/release_note.pl" "$notes"
