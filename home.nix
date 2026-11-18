{ config, pkgs, user, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
in

{
  home.username = user;
  home.homeDirectory = "/Users/${user}";
  home.stateVersion = "24.11";
  home.packages = with pkgs; [
    # cli i use constantly
    ripgrep   # fast search
    fd        # fast find
    fzf       # fuzzy finder
    jq        # json on the command line
    lazygit
    neovim
    # the font everything renders in
    nerd-fonts.hack
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
    gh
    git
    grpcurl
    kubernetes-helm  # was brew helm
    kind
    kubectl         # was brew kubernetes-cli
    jdk17_headless  # was openjdk@17
    natscli         # was brew "nats"
    nats-server
    nmap
    nodejs          # was brew node
    osmium-tool
    picotool
    protobuf
    pyenv
    tcl             # was brew tcl-tk
    tk              # (the tk half of tcl-tk)
    tmux
    uhubctl
    uv              # python project/venv manager (recreate moved project venvs)
    wireshark-cli   # was brew "wireshark" (tshark + CLI)
    zlib
    zsh
    ngrok           # was cask "ngrok" (same CLI binary)
    wezterm
    claude-code
  ];
  fonts.fontconfig.enable = true;
  home.sessionVariables.EDITOR = "nvim";

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;      # ghost text from history
    syntaxHighlighting.enable = true;  # commands turn green when valid
    initContent = ''
      bindkey '^f' autosuggest-accept
    '';
    shellAliases = {
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
      cc = "claude --dangerously-skip-permissions";
      co = "codex --full-auto";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  # Spotlight never indexes /nix, and it resolves app symlinks to their target,
  # so a symlinked WezTerm.app is invisible to it. Copy the bundle instead so
  # it exists as a real, indexable directory in ~/Applications.
  home.activation.installWeztermApp = config.lib.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "$HOME/Applications"
    # cp -R preserves the nix store's read-only modes, and BSD rm can't delete
    # trees with read-only dirs - make it writable before replacing.
    chmod -R u+w "$HOME/Applications/WezTerm.app" 2>/dev/null || true
    rm -rf "$HOME/Applications/WezTerm.app"
    cp -R "${pkgs.wezterm}/Applications/WezTerm.app" "$HOME/Applications/WezTerm.app"
    chmod -R u+w "$HOME/Applications/WezTerm.app"
  '';

  # Edit-in-place: the real file stays in my repo, ~/.config just points at it.
  home.file.".config/wezterm".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/wezterm";
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/nvim";
  home.file.".config/herdr".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.config/herdr";
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.claude/settings.json";

  # Keep Pi's credential and runtime state local by linking only authored files and directories.
  home.file.".pi/agent/themes".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/themes";
  home.file.".pi/agent/extensions".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/extensions";
  home.file.".pi/agent/models.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/models.json";
  home.file.".pi/agent/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/.pi/agent/settings.json";

  home.file.".claude/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
  home.file.".config/opencode/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/home/AGENTS.md";
}
