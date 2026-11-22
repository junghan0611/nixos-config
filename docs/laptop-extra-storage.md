# 랩탑 보조 저장장치 사용

보조 SSD나 UFS 카드를 추가할 수 있는 랩탑에서는 시스템 디스크와 분리해 큰 파일과 작업 자료를 보관할 수 있다. 현재 삼성 `laptop`의 보조 매체는 GLG가 확인한 UFS 카드다. 일반 microSD보다 쓰기 편했다는 사용 경험이며, 벤치마크 수치는 아니다.

`laptop`의 [하드웨어 설정](../hosts/laptop/hardware-configuration.nix)은 보조 ext4 파티션을 UUID로 `/data`에 마운트한다. 현재 `/dev/sda1`로 보이지만 장치명은 바뀔 수 있으므로 다른 랩탑에 적용할 때는 `lsblk -f`로 해당 장치의 UUID를 확인한다. 다른 기기의 UUID나 초기 설치용 디스크 구성을 그대로 복사하지 않는다.

마운트 경로는 유지하고, 사용자 디렉터리만 자기 소유로 만든 뒤 홈에 링크한다. **`findmnt` 출력이 의도한 ext4 파티션인지 확인한 뒤** 설정한다.

```sh
findmnt --mountpoint /data -o SOURCE,FSTYPE,OPTIONS
```

```sh
mountpoint -q /data &&
  sudo install -d -m 0700 -o "$(id -u)" -g "$(id -g)" "/data/$(id -un)" &&
  ln -sT "/data/$(id -un)" "$HOME/data"
```

`-T`는 `~/data`가 이미 있는 경우 그 안에 링크를 만들지 않고 실패하게 한다. ext4의 소유권과 홈의 링크는 각각 디스크에 저장되어 재부팅이나 `switch` 뒤에도 남는다. 새 카드나 재포맷한 파티션은 다시 설정한다. 장치를 빼기 전에는 사용 중인 작업을 닫고 마운트를 해제한다. 이 절차에는 포맷이나 기존 파일의 재귀 권한 변경이 없다.
