# Autorandr configuration for automatic display management
# Profiles for laptop-only and dual-monitor setups
{ config, lib, pkgs, ... }:

{
  programs.autorandr = {
    enable = true;

    profiles = {
      # Samsung NT930SBE (1920x1080)
      "laptop" = {
        fingerprint = {
          eDP-1 = "*";
        };
        config = {
          eDP-1 = {
            enable = true;
            primary = true;
            position = "0x0";
            mode = "1920x1080";
            rate = "59.98";
          };
        };
      };

      # ThinkPad P16s Gen 2 (16:10 WUXGA 1920x1200)
      "thinkpad" = {
        fingerprint = {
          eDP-1 = "*";
        };
        config = {
          eDP-1 = {
            enable = true;
            primary = true;
            position = "0x0";
            mode = "1920x1200";
            rate = "60.00";
          };
        };
      };

      # Dual monitor: 외부 모니터(위) + 노트북(아래) - 세로 배치
      # 레이아웃: 위에 큰 모니터, 아래 노트북 (시선 상하 이동)
      # 연결 후 위치 조정: autorandr --save dual-vertical --force
      "dual-vertical" = {
        fingerprint = {
          eDP-1 = "*";
          DP-1 = "*";
        };
        config = {
          DP-1 = {
            enable = true;
            position = "0x0";  # 위쪽
          };
          eDP-1 = {
            enable = true;
            primary = true;
            position = "0x2160";  # 4K 기준, 다른 해상도면 재저장
          };
        };
      };

      # DP-2 연결용 (동일 레이아웃)
      "dual-vertical-dp2" = {
        fingerprint = {
          eDP-1 = "*";
          DP-2 = "*";
        };
        config = {
          DP-2 = {
            enable = true;
            position = "0x0";  # 위쪽
          };
          eDP-1 = {
            enable = true;
            primary = true;
            position = "0x2160";  # 4K 기준
          };
        };
      };

      # ThinkPad + HDMI 듀얼 (4K 위 + 노트북 아래)
      "thinkpad-dual-hdmi" = {
        fingerprint = {
          eDP-1 = "*";
          HDMI-1 = "*";
        };
        config = {
          HDMI-1 = {
            enable = true;
            position = "0x0";  # 위쪽 (4K)
            mode = "3840x2160";
            rate = "60.00";
          };
          eDP-1 = {
            enable = true;
            primary = true;
            position = "960x2160";  # 아래, 가로 센터 (3840-1920)/2
            mode = "1920x1200";
            rate = "60.00";
          };
        };
      };
    };

    hooks = {
      postswitch = {
        "notify" = ''
          ${pkgs.libnotify}/bin/notify-send "Display" "Profile switched"
        '';
        "reset-wallpaper" = ''
          ${pkgs.feh}/bin/feh --bg-scale ~/.config/nixos-wallpaper.png
        '';
      };
    };
  };

  # Auto-detect on login and hotplug
  services.autorandr = {
    enable = true;
  };
}
