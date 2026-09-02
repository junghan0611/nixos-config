# Emacs configuration
# Based on ElleNajit's Doom Emacs setup
{ config, lib, pkgs, currentSystemName ? "thinkpad", ... }:

let
  # Doom Emacs paths
  doomEmacsPath = "${config.home.homeDirectory}/.emacs.d";
  doomConfigPath = "${config.home.homeDirectory}/.doom.d";

  # Server (headless) vs Desktop
  isHeadless = builtins.elem currentSystemName [ "oracle" "nuc" ];
  emacsPackage = if isHeadless then pkgs.emacs-nox else pkgs.emacs-gtk;
in {
  # Enable Emacs
  # - Desktop (thinkpad/laptop): emacs-gtk (GTK3 + X11) — 마우스 커서, 파일 다이얼로그, context-menu가 GTK 테마 따름
  # - Server (oracle/nuc): emacs-nox — GUI 불필요, X11 의존성 제거
  # - emacs-pgtk는 Wayland용이라 i3wm(X11)에서는 gtk가 적합
  # - 2026-09-02부터 emacs-gtk/emacs-nox 는 flake.nix 오버레이에서 unstable
  #   emacs31-gtk3 / emacs31-nox 로 잡힌다 (26.05는 30.2에 멈춰 있음)
  programs.emacs = {
    enable = true;
    package = emacsPackage;
    # 2026-09-02: 둘 다 주석 처리. doom 쪽에서 이미 꺼져 있어
    # (doomemacs-config/init.el:136 `;; vterm`, :210 `;; (mu4e +org +gmail
    # +mbsync)`) 여기서 site-lisp 로 실어봐야 아무도 require 하지 않는다.
    # 되살릴 때는 init.el 의 해당 모듈부터 켤 것. mu4e(elisp)는 아래
    # home.packages 의 mu 와 버전이 lockstep 이어야 한다.
    extraPackages = epkgs: [
      # epkgs.vterm
      # epkgs.mu4e
    ];
  };

  # Session variables
  home.sessionVariables = {
    # GUI Emacs는 "user" 소켓, agent daemon은 "server" 소켓
    EDITOR = "emacsclient -s user";
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

    enchant
    hunspell
    hunspellDicts.ko_KR

    # Email (mu4e) — 2026-09-02 주석 처리. 이메일은 Emacs 밖에서 본다
    # (doomemacs-config/init.el:208 ":email 비활성"). 되살릴 때는
    # mu 와 위 epkgs.mu4e 를 같은 nixpkgs 에서 함께 켜야 버전이 맞는다.
    # mu
    # isync
    # offlineimap

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
    ghostscript  # PDF viewer (doc-view-mode)
    asciidoctor-with-extensions  # AsciiDoc processor (hwpx conversion)

    # Node.js (for LSP servers)
    nodejs

    # Terminal emulation (vterm)
    libvterm

    # Writing tools
    languagetool
  ] ++ (lib.optionals (!isHeadless) [
    # === Desktop-only packages (GUI required) ===

    # Doom Emacs Desktop entries
    (makeDesktopItem {
      name = "Doom Emacs";
      desktopName = "Doom Emacs";
      icon = "emacs";
      exec = "${emacsPackage}/bin/emacs";
      categories = [ "Development" "TextEditor" ];
    })

    (makeDesktopItem {
      name = "Doom Emacs (Debug Mode)";
      desktopName = "Doom Emacs (Debug Mode)";
      icon = "emacs";
      exec = "${emacsPackage}/bin/emacs --debug-init";
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
        emacsclient -s user -c /tmp/EDIT
        xclip -in -selection clipboard < /tmp/EDIT
        sleep 0.2
        xdotool key ctrl+v
        rm /tmp/EDIT
      '';
    })
  ]);

  # Doom Emacs desktop entry for application launcher (desktop only)
  xdg.desktopEntries = lib.mkIf (!isHeadless) {
    # emacsclient: nixpkgs 기본 desktop entry 오버라이드 (-s user 추가)
    emacsclient = {
      name = "Emacs (Client)";
      genericName = "Text Editor";
      comment = "Connect to Doom Emacs user server";
      exec = "${emacsPackage}/bin/emacsclient -s user --create-frame %F";
      icon = "emacs";
      terminal = false;
      categories = [ "Development" "TextEditor" ];
      settings = {
        StartupWMClass = "Emacs";
      };
    };
    doomemacs = {
      name = "Doom Emacs Stable";
      genericName = "Text Editor";
      comment = "Doom Emacs - Edit text";
      exec = "env GTK_IM_MODULE=emacs XMODIFIERS=@im=emacs EMACS=emacs DOOMDIR=${doomConfigPath} ${config.home.homeDirectory}/doomemacs/bin/doom emacs";
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
  };
}
