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
      # 실제 EDID fingerprint 사용 - 다른 디바이스와 구분
      "thinkpad" = {
        fingerprint = {
          eDP-1 = "00ffffffffffff0030aeb541000000000f1f0104a5221678e73755965d58922920505400000001010101010101010101010101010101333f80dc70b03c403020360059d71000001a000000fd00283c4c4c10010a2020202020200000000f00d10a3cd10a281e0a0009e5310a000000fe004e5631363057554d2d4e34330a00a7";
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

      # ThinkPad + LG HDR 4K (HDMI 듀얼: 4K 위 + 노트북 아래)
      # 실제 EDID fingerprint 사용 - HDMI connected 상태와 단독 사용 구분
      "thinkpad-dual-hdmi" = {
        fingerprint = {
          eDP-1 = "00ffffffffffff0030aeb541000000000f1f0104a5221678e73755965d58922920505400000001010101010101010101010101010101333f80dc70b03c403020360059d71000001a000000fd00283c4c4c10010a2020202020200000000f00d10a3cd10a281e0a0009e5310a000000fe004e5631363057554d2d4e34330a00a7";
          HDMI-1 = "00ffffffffffff001e6d0677b2be0200081f0103803c2278ea3e31ae5047ac270c50542108007140818081c0a9c0d1c08100010101014dd000a0f0703e803020350058542100001aa36600a0f0701f803020350058542100001a000000fd00383d1e873c000a202020202020000000fc004c472048445220344b0a202020014002033b714d9022201f1203040161605d5e5f230907076d030c001000b83c20006001020367d85dc401788003e30f0003e305c000e606050152485d023a801871382d40582c450058542100001e565e00a0a0a029503020350058542100001a000000ff003130384e54585235393839300a0000000000000000000000000000e6";
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
