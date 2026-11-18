#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles
# Absolute path: sudo scrubs PATH to /usr/bin:/bin:/usr/sbin:/sbin, and this
# machine has no /run/current-system, so bare `sudo darwin-rebuild` is not found.
# The script re-exports a PATH with the nix profiles once it starts.
exec sudo /nix/var/nix/profiles/system/sw/bin/darwin-rebuild switch --flake ~/.dotfiles#mac
