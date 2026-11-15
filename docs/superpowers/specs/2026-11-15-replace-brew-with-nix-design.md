# Replace Homebrew management with Nix-first config

Date: 2026-11-15

## Intent

Make this repo manage all tooling on this machine through Nix, shrinking Homebrew
to only what nixpkgs cannot provide. One `./bootstrap.sh` on this (not yet
Nix-installed) machine then installs Determinate Nix and performs the cutover.

## Goals

- All CLI tools available in nixpkgs move to `home.nix` `home.packages`.
- Homebrew keeps only packages not in nixpkgs (2 taps, 4 brews, 4 casks).
- `homebrew.onActivation.cleanup = "zap"` stays: orphaned formulas and ~100
  dependency packages disappear on the first switch.
- `acli` (Atlassian) is dropped, not migrated.

## Non-goals

- No fresh-machine setup changes; `bootstrap.sh` flow unchanged.
- No attempt to nixify GUI apps nixpkgs lacks (iterm2, pearcleaner, pieces).

## Approaches considered

1. **Kill brew entirely** — rejected: herdr, rtk, rill, iterm2, pearcleaner,
   pieces have no nixpkgs package.
2. **Nix-first, brew shrunk to exceptions** — chosen.
3. **Prune first, then migrate** — skipped: user confirmed all top-level
   formulas are in use.

## Migration mapping

To nix (`home.nix`): act, awscli, binutils, cbc, colima, coreutils, docker,
docker-buildx, docker-compose, duckdb, ffmpeg, fish, gh, git, grpcurl, helm,
kind, kubernetes-cli, mole, nats-server, nmap, node, osmium-tool, protobuf,
pyenv, tcl-tk, tmux, uhubctl, zlib, zsh; openjdk@17 → jdk17_headless;
wireshark → wireshark-cli; nats → nats-cli (uncertain); lsusb, picotool,
claude-code (uncertain); ngrok, wezterm.

Uncertain names get verified at the first build; failure aborts the switch
before zap runs, so the brew originals survive a failed attempt.

Stays brew: `herdr`, `rtk`, `rill` (`rilldata/tap`), casks `iterm2`,
`pearcleaner`, `pieces`, `pieces-os` (plus `atlassian/acli` tap removed with acli).

## Files touched

- `home.nix` — package additions.
- `configuration.nix` — `homebrew.taps`, shrunk brews/casks lists.
- `README.md` — package list and herdr note.

## Verification limit

Nix is not installed yet, so `nix flake check` cannot run before the switch.
Correctness of the new lists is proven by the first `./bootstrap.sh` /
`./rebuild.sh`: eval failure aborts before zap; success means the machine
converged. Known residual risks: nixpkgs version drift (node/JDK majors),
wezterm .app linking on macOS, unverified package names above.
