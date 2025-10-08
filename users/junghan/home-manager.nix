{ inputs, ... }:

{ config, lib, pkgs, ... }:

let
  isLinux = pkgs.stdenv.isLinux;
  # Import vars from the appropriate host - fallback to nuc for now
  # TODO: Make this dynamic based on currentSystemName
  vars = import ../../hosts/nuc/vars.nix;
in {
  # Import modular configuration
  imports = [
    ./modules
  ];

  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # This value determines the Home Manager release that your
  # configuration is compatible with.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable XDG base directories
  xdg.enable = true;

  #---------------------------------------------------------------------
  # Packages
  #---------------------------------------------------------------------
  home.packages = with pkgs; [
    # CLI tools
    bat
    eza
    fd
    fzf
    gh
    htop
    jq
    ripgrep
    tree
    watch
    ncdu
    duf
    procs

    # Development
    lazygit
    delta
    git-lfs
    direnv

    # System tools
    neofetch

    # Editors
    emacs

    # Email and password management
    gnupg
    pass
    passExtensions.pass-otp
    notmuch
    isync
    afew
  ] ++ (lib.optionals isLinux [
    # Linux-specific packages
    xclip
    wl-clipboard
    firefox
  ]);

  #---------------------------------------------------------------------
  # Dotfiles
  #---------------------------------------------------------------------
  home.file = {
    ".config/i3/config".text = builtins.readFile ./i3;
    # i3status is configured via programs.i3status below
    ".config/rofi/config.rasi".text = builtins.readFile ./configs/rofi;
    ".config/ghostty/config".text = builtins.readFile ./configs/ghostty.linux;
    ".config/kitty/kitty.conf".text = builtins.readFile ./configs/kitty;
    ".inputrc".text = builtins.readFile ./configs/inputrc;
    # Wallpaper for i3
    ".config/nixos-wallpaper.png".source = ./../../assets/indistractable.png;
  };

  # X resources configuration
  xresources.extraConfig = builtins.readFile ./configs/Xresources;

  #---------------------------------------------------------------------
  # X11 and Desktop configuration
  # (Shell configuration moved to modules/shell.nix)
  #---------------------------------------------------------------------

  # Cursor theme (96 DPI에 적합한 크기)
  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 32;
    x11.enable = true;
  };

  # i3status configuration (Tomorrow Night 색상 스키마)
  programs.i3status = {
    enable = true;
    general = {
      colors = true;
      interval = 5;
      color_good = "#8C9440";      # 녹색
      color_bad = "#A54242";       # 빨간색
      color_degraded = "#DE935F";  # 주황색
    };

    modules = {
      ipv6.enable = false;
      "wireless _first_".enable = false;
      "battery all".enable = false;

      "ethernet _first_" = {
        position = 1;
        settings = {
          format_up = "E: %ip (%speed)";
          format_down = "E: down";
        };
      };

      "disk /" = {
        position = 2;
        settings = {
          format = "/ %avail";
        };
      };

      "load" = {
        position = 3;
        settings = {
          format = "%1min";
        };
      };

      "memory" = {
        position = 4;
        settings = {
          format = "%used / %total";
          threshold_degraded = "1G";
          format_degraded = "MEMORY < %available";
        };
      };

      "tztime local" = {
        position = 5;
        settings = {
          format = "%Y-%m-%d %H:%M:%S";
        };
      };
    };
  };
}
