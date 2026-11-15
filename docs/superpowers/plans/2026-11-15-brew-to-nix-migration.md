# Brew → Nix Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move all brew-managed tools that exist in nixpkgs into Nix config, shrinking Homebrew to 1 tap / 4 brews / 4 casks.

**Architecture:** Declarative edits to the existing nix-darwin + home-manager config. No new modules. Cutover happens on the first `./bootstrap.sh` switch: nix evaluates before Homebrew zap runs, so an eval failure leaves the machine untouched.

**Tech Stack:** nix-darwin, home-manager, nix-homebrew (all already wired in `flake.nix`).

**Spec:** `docs/superpowers/specs/2026-11-15-replace-brew-with-nix-design.md`

## Global Constraints

- Keep `nix-homebrew.enable = true` and `homebrew.onActivation.cleanup = "zap"` exactly as-is.
- `acli` is dropped, not migrated; `atlassian/acli` tap is not declared anywhere.
- Nix is not installed on this machine until Task 4 — Tasks 1–3 cannot run `nix` commands; their verification is diff review, not eval.
- Match existing comment style in both nix files.

## Review Focus

- Uncertain nixpkgs names: `nats-cli`, `lsusb`, `picotool`, `claude-code`. Expected: if eval fails on one, remove that `home.packages` line and move the tool into the `brews`/`casks` keep-list instead (fallback documented per-task). Test: the first switch in Task 4 succeeding, or the fallback edit re-running it.
- wezterm from nixpkgs may not land a `.app` in `/Applications` the way the cask did. Expected: `wezterm` binary on PATH; if GUI launch is wanted later, move it back to `casks`.
- Version drift: nixpkgs node/JDK majors may differ from the brew versions being replaced. Expected: tools work; pin a specific `nodejs_X` / JDK only if the user reports breakage.
- `wireshark` brew formula = CLI/tshark; `wireshark-cli` nix attr is the equivalent; the GUI stays the `wireshark-app`... not migrated — GUI cask `wireshark-app` is NOT in the keep-list per spec, so the Wireshark GUI will be zapped. Expected by spec: user accepted all-6-in-use but keep-list has no wireshark GUI. **Spec conflict — see Task 2 note; resolved as: add `wireshark-app` to casks keep-list.**

---

### Task 1: Add migrated packages to `home.nix`

**Files:**
- Modify: `home.nix` (`home.packages` list, lines 11–21)

**Interfaces:**
- Consumes: nothing.
- Produces: nixpkgs packages available to `home.packages`; Task 4's verification greps this list.

- [ ] **Step 1: Extend `home.packages`**

Append after the existing entries, keeping the `with pkgs;` style and a comment header per group:

```nix
    # migrated from Homebrew (2026-11)
    act
    awscli
    binutils
    cbc
    colima
    coreutils
    docker          # client; daemon comes from colima
    docker-buildx
    docker-compose
    duckdb
    ffmpeg
    fish
    gh
    git
    grpcurl
    helm
    kind
    kubernetes-cli  # kubectl
    jdk17_headless  # was openjdk@17
    mole
    nats-cli        # was brew "nats"; not in nixpkgs -> move to brews
    nats-server
    nmap
    node
    osmium-tool
    picotool        # not in nixpkgs -> move to brews
    protobuf
    pyenv
    tmux
    uhubctl
    wireshark-cli   # was brew "wireshark" (tshark + CLI)
    zlib
    zsh
    ngrok           # was cask "ngrok" (same CLI binary)
    wezterm
    claude-code     # not in nixpkgs -> move to casks
```

Also keep `lsusb`? No: `lsusb` is NOT included — macOS `lsusb` formula has no nixpkgs equivalent; move it to `brews` in Task 2. (Uncertain-name fallbacks are stated inline above.)

- [ ] **Step 2: Verify diff**

Run: `git diff home.nix`
Expected: only the `home.packages` list grew; symlinks, zsh, starship untouched.

- [ ] **Step 3: Commit**

```bash
git add home.nix
git commit -m "feat(nix): add CLI packages migrated from Homebrew"
```

### Task 2: Shrink Homebrew keep-list in `configuration.nix`

**Files:**
- Modify: `configuration.nix:32-44` (the `homebrew` block)

**Interfaces:**
- Consumes: Task 1's fallback decisions if any uncertain name was already confirmed missing (implementer of Task 2 reads Task 1's outcome).
- Produces: the brew keep-list Task 4 verifies against.

- [ ] **Step 1: Replace the `homebrew` block with**

```nix
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    taps = [
      { name = "rilldata/tap"; }
    ];
    brews = [
      "herdr"
      "rtk"
      "rilldata/tap/rill"
      "lsusb"
    ];
    casks = [
      "iterm2"
      "pearcleaner"
      "pieces"
      "pieces-os"
      "wireshark-app"  # Wireshark GUI; CLI moved to nix
    ];
  };
```

Note: `wireshark-app` joins the keep-list (spec mapping missed it; user uses Wireshark GUI). If Task 1 confirmed `claude-code` missing from nixpkgs, add it back under `casks` and delete that line from `home.nix`. Same for `nats-cli` / `picotool` under `brews`.

- [ ] **Step 2: Verify diff**

Run: `git diff configuration.nix`
Expected: `nix-homebrew` block and zap line unchanged; `wezterm`, `claude-code`, plain `herdr`-only lists replaced by block above; no `atlassian/acli`.

- [ ] **Step 3: Commit**

```bash
git add configuration.nix
git commit -m "feat(nix): shrink Homebrew to nixpkgs-missing exceptions"
```

### Task 3: Update README package claims

**Files:**
- Modify: `README.md:26-33` ("What you get" bullets)

- [ ] **Step 1: Rewrite the two tool bullets**

Replace:

```
- Homebrew apps (casks and CLI tools)
- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, Hack Nerd Font)
```

with:

```
- Nix user packages (ripgrep, fd, fzf, jq, lazygit, Neovim, Hack Nerd Font,
  plus CLI tools migrated from Homebrew: docker/k8s stack, awscli, gh, ffmpeg,
  tmux, and more - see `home.nix`)
- Homebrew for what nixpkgs lacks (herdr, rtk, rill; casks iterm2,
  pearcleaner, pieces, wireshark-app)
```

- [ ] **Step 2: Verify**

Run: `grep -n "Homebrew" README.md`
Expected: remaining Homebrew mentions (cleanup warning, herdr note, Pi launcher) still accurate; no claim that brews/casks lists live in "brews and casks arrays" is now false — the cleanup warning at README.md:116-119 stays correct as written.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: reflect nix-first package split in README"
```

### Task 4: Cutover — bootstrap, then verify convergence

**Files:** none (system operation).

**Interfaces:**
- Consumes: committed Tasks 1–3; `flake.nix` `user = "herry"` matches `whoami` (verified 2026-11-15).

- [ ] **Step 1: User runs bootstrap** (sudo password required; agent must not run it)

```sh
! ./bootstrap.sh
```

Expected output: `==> Done.` with no eval error. If eval fails naming one of `nats-cli`/`picotool`/`claude-code`: apply that task's documented fallback (move line to brew/cask keep-list), `./rebuild.sh`, continue.

- [ ] **Step 2: Verify migration (agent)**

```sh
command -v nix docker kubectl tmux wezterm claude ngrok     # all found, under /run/current-system or nix store
brew leaves                                                 # exactly: herdr, rilldata/tap/rill, rtk (+ lsusb unless nixpkgs grew one)
brew list --cask --installed-on-request                     # exactly: iterm2, pearcleaner, pieces, pieces-os, wireshark-app
brew tap                                                    # exactly: rilldata/tap
```

- [ ] **Step 3: Report drift**

If any old brew package survives (zap missed it) or any migrated tool is missing from PATH, report the exact package and the fix applied; do not silently re-add packages.
