# Emacs configuration
# Based on ElleNajit's Doom Emacs setup
{ config, lib, pkgs, ... }:

let
  # Doom Emacs paths
  doomEmacsPath = "${config.home.homeDirectory}/.emacs.d";
  doomConfigPath = "${config.home.homeDirectory}/.doom.d";
in {
  # Enable Emacs
  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [
      epkgs.vterm
      epkgs.mu4e
    ];
  };

  # Session variables
  home.sessionVariables = {
    EDITOR = "emacsclient";
  };

  # Add Doom Emacs bin to PATH
  home.sessionPath = [
    "${doomEmacsPath}/bin"
    "${doomConfigPath}/bin"
  ];

  # Note: current-task file is created by Emacs function (junghan/update-org-clocked-in-task-file)
  # Not pre-created to avoid symlink issues with with-temp-file

  # Emacs dependencies
  home.packages = with pkgs; [
    # Spell checking
    (aspellWithDicts (dicts: with dicts; [ en en-computers ]))
    ispell

    hunspell
    hunspellDicts.ko_KR

    # Email (mu4e)
    mu
    isync
    offlineimap

    # Search and navigation
    ripgrep
    fd
    coreutils

    # Compiler and build tools
    clang
    cmake
    gnumake
    libtool

    # Document processing
    pandoc
    imagemagick
    asciidoctor-with-extensions  # AsciiDoc processor (hwpx conversion)

    # Node.js (for LSP servers)
    nodejs_22

    # Terminal emulation (vterm)
    libvterm

    # Writing tools
    languagetool

    # Doom Emacs Desktop entries
    (makeDesktopItem {
      name = "Doom Emacs";
      desktopName = "Doom Emacs";
      icon = "emacs";
      exec = "${pkgs.emacs}/bin/emacs";
      categories = [ "Development" "TextEditor" ];
    })

    (makeDesktopItem {
      name = "Doom Emacs (Debug Mode)";
      desktopName = "Doom Emacs (Debug Mode)";
      icon = "emacs";
      exec = "${pkgs.emacs}/bin/emacs --debug-init";
      categories = [ "Development" "TextEditor" ];
    })

    (makeDesktopItem {
      name = "Sync Doom";
      desktopName = "Sync Doom";
      icon = "emacs";
      exec = "${pkgs.kitty}/bin/kitty ${
          pkgs.writeShellScript "doom-sync" ''
            if ! ${doomEmacsPath}/bin/doom sync; then
              echo 'Doom sync failed'
              exec bash
            fi
          ''
        }";
      categories = [ "Development" "System" ];
    })

    (makeDesktopItem {
      name = "Doctor Doom";
      desktopName = "Doctor Doom";
      icon = "emacs";
      exec = "${pkgs.kitty}/bin/kitty ${
          pkgs.writeShellScript "doom-doctor" ''
            ${doomEmacsPath}/bin/doom doctor
            exec bash
          ''
        }";
      categories = [ "Development" "System" ];
    })

    (makeDesktopItem {
      name = "Upgrade Doom";
      desktopName = "Upgrade Doom";
      icon = "emacs";
      exec = "${pkgs.kitty}/bin/kitty ${
          pkgs.writeShellScript "doom-upgrade" ''
            if ! ${doomEmacsPath}/bin/doom upgrade; then
              echo 'Doom upgrade failed'
              exec bash
            fi
          ''
        }";
      categories = [ "Development" "System" ];
    })

    # edit-input: Edit input fields with Emacs
    # (Stolen from aspen - https://github.com/aspen)
    (pkgs.writeShellApplication {
      name = "edit-input";
      runtimeInputs = [ xdotool xclip ];
      text = ''
        set -euo pipefail

        sleep 0.2
        xdotool key ctrl+a ctrl+c
        xclip -out -selection clipboard > /tmp/EDIT
        emacsclient -c /tmp/EDIT
        xclip -in -selection clipboard < /tmp/EDIT
        sleep 0.2
        xdotool key ctrl+v
        rm /tmp/EDIT
      '';
    })
  ];

  # Doom Emacs desktop entry for application launcher
  xdg.desktopEntries.doomemacs = {
    name = "Doom Emacs";
    genericName = "Text Editor";
    comment = "Doom Emacs - Edit text";
    exec = "env GTK_IM_MODULE=emacs XMODIFIERS=@im=emacs EMACS=emacs DOOMDIR=${doomConfigPath} ${config.home.homeDirectory}/doomemacs/bin/doom run";
    icon = "emacs";
    terminal = false;
    categories = [ "Development" "TextEditor" ];
    mimeType = [
      "text/english"
      "text/plain"
      "text/x-makefile"
      "text/x-c++hdr"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-csrc"
      "text/x-java"
      "text/x-moc"
      "text/x-pascal"
      "text/x-tcl"
      "text/x-tex"
      "application/x-shellscript"
      "text/x-c"
      "text/x-c++"
    ];
    settings = {
      StartupNotify = "true";
      StartupWMClass = "DoomEmacs";
    };
  };
}
