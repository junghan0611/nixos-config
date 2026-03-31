# GTK theme configuration (desktop only)
# Adwaita Dark — Emacs GTK 위젯, 파일 다이얼로그, context-menu 등에 적용
{ config, lib, pkgs, currentSystemName ? "thinkpad", ... }:

let
  isHeadless = builtins.elem currentSystemName [ "oracle" "nuc" ];
in {
  # Desktop에서만 GTK 설정
  gtk = lib.mkIf (!isHeadless) {
    enable = true;

    theme = {
      name = "Adwaita-dark";
      package = pkgs.adwaita-icon-theme;  # gnome-themes-extra 포함
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # dconf는 i3wm에서 D-Bus 서비스가 없을 수 있으므로 사용하지 않음
  # GTK settings.ini + extraConfig만으로 충분
}
