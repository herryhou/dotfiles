{ user, ... }:

{
  # Determinate already manages the Nix daemon, so nix-darwin shouldn't.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin"; # use x86_64-darwin for Intel CPU

  system.primaryUser = user;
  users.users.${user} = {
    home = "/Users/${user}";
  };
  system.stateVersion = 6;
  system.defaults = {
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      KeyRepeat = 2;          # fast key repeat
      InitialKeyRepeat = 15;  # short delay before repeat
      _HIHideMenuBar = true;  # auto-hide the menu bar
      AppleShowAllExtensions = true;
    };
    dock.autohide = true;
    finder.FXPreferredViewStyle = "Nlsv";  # list view by default
    finder.CreateDesktop = false;          # clean desktop
    trackpad.Clicking = true;              # tap to click
    # Restart comes back to a clean desktop. Without this, macOS relaunches
    # every app that was open (PersistentAppsSupport), causing a multi-minute
    # post-login load storm. See docs/slow-restart.md.
    # Both domains are needed: the system one governs loginwindow's own
    # decision, the user one is the per-session "reopen windows" state that
    # loginwindow consults for the logged-in user.
    CustomSystemPreferences."com.apple.loginwindow".TALLogoutSavesState = false;
    CustomUserPreferences."com.apple.loginwindow".TALLogoutSavesState = false;
  };
  nix-homebrew = {
    enable = true;
    autoMigrate = true;  # adopt existing /opt/homebrew (one-time; keeps installed packages)
    inherit user;
  };
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";  # remove anything not listed here
    onActivation.autoUpdate = true;
    onActivation.extraFlags = [ "--force" ];
    brews = [
      "herdr"
      "rtk"
      "lsusb"
      "mole"  # nixpkgs mole 2.0.0 is marked broken; brew build works
    ];
    casks = [
      "pearcleaner"
      "wireshark-app"  # Wireshark GUI; CLI moved to nix
    ];
  };
}
