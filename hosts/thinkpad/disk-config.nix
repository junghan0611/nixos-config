{
  disko.devices = {
    disk = {
      # NVMe 512GB - OS 전체 설치용 (부팅 + 루트 + 스왑)
      # ThinkPad P16s Gen 2 내장 NVMe
      nvme = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = "32G";  # RAM 32GB에 맞춰 스왑 32GB
              content = {
                type = "swap";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };

      # 외장 데이터 디스크 (선택사항 - 필요시 활성화)
      # sda = {
      #   type = "disk";
      #   device = "/dev/sda";
      #   content = {
      #     type = "gpt";
      #     partitions = {
      #       data = {
      #         size = "100%";
      #         content = {
      #           type = "filesystem";
      #           format = "ext4";
      #           mountpoint = "/data";
      #         };
      #       };
      #     };
      #   };
      # };
    };
  };
}
