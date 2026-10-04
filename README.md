# rpi5-camera-bsp

Raspberry Pi 5의 카메라 모듈 3(IMX708)를 자동 인식 없이 커널 단부터 다시 올리고, 센서 드라이버의 영상 시작 시간을 재서 줄인 기록입니다.
Bringing up the IMX708 (Camera Module 3) on a Raspberry Pi 5 from the kernel level, without auto-detection, and measuring and cutting the sensor driver's stream start time.

## 결과

사진 한 장을 찍을 때 일어나는 모드 전환(2304×1296 → 4608×2592)에서 센서 드라이버가 영상을 다시 시작하는 데 걸린 시간입니다. 드라이버 안에서 `ktime` 으로 쟀습니다.

| 단계 | 모드 전환 1회 평균 | 측정 |
|---|---|---|
| 기준 — 실행 중인 커널과 같은 판의 드라이버 | 75.1 ms | 20회 |
| + 전원 관리 수정 백포트 (5초 autosuspend) | 45.7 ms | 10회 |
| + 카메라 I2C 버스 100 kHz → 400 kHz (Device Tree) | 14.3 ms | 25회 |

- 기준 드라이버는 영상을 멈출 때마다 센서를 리셋해서, 다시 켤 때 레지스터를 처음부터 다시 썼습니다.
- 백포트한 수정은 Raspberry Pi 커널의 커밋 [6b7a0deb](https://github.com/raspberrypi/linux/commit/6b7a0deb1c500741973928195ef63ac128edb232)입니다. 손으로 옮긴 뒤 원본과 `diff` 로 대조했습니다.
- 백포트 뒤 남은 시간을 쓰기 횟수로 나눈 값(쓰기 1회 약 0.42 ms)이 100 kHz I2C 한 번 쓰기 시간과 맞아서 버스 속도를 올렸습니다. 400 kHz에서는 쓰기 1회 약 0.13 ms(추정)입니다.
- 400 kHz는 이 모듈과 케이블에서 영상 시작 50회 동안 I2C 오류가 없었다는 것까지만 확인했습니다. Raspberry Pi가 기본을 100 kHz로 둔 이유는 확인하지 못했습니다.

## 환경

Raspberry Pi 5 (4GB) · Raspberry Pi OS (Debian 13) · 커널 `6.12.47+rpt-rpi-2712` · libcamera v0.6.0 · Camera Module 3 Wide (IMX708) · CAM/DISP 1

## 한 일

1. `camera_auto_detect=0` 으로 자동 인식을 끄고, 직접 쓴 Device Tree Overlay(`my-imx708.dts`)로 센서·렌즈 모터·CSI-2 수신기를 다시 등록
2. 실행 중인 커널과 같은 판의 `imx708.c` 를 찾아 빌드 — 모듈 지문(`srcversion`)으로 기본 모듈과 같은 소스임을 확인
3. 부팅 때 직접 빌드한 모듈이 올라가도록 배치(`updates/` + `depmod` override). 실행 중 교체는 CSI-2 수신기 드라이버가 센서 재결합을 처리하지 못해 커널 oops가 나서 쓰지 않음
4. 드라이버에 구간별 시간 기록을 넣고 측정 → 백포트 → 재측정 → I2C 400 kHz → 재측정

커밋을 순서대로 보면 원본 → 계측 → 백포트 → 400 kHz 순서로 바뀐 줄만 보입니다.

## 파일

| 경로 | 내용 |
|---|---|
| `my-imx708.dts` | 직접 쓴 오버레이 (I2C 400 kHz 포함) |
| `imx708-stock.dts` | 비교용 — 기본 오버레이(`imx708.dtbo`)를 `dtc` 로 되돌린 것 |
| `driver/imx708.c` | Raspberry Pi 커널의 IMX708 드라이버(686f5708) + 백포트 + 계측 로그 |
| `driver/imx708-autosuspend.c` | 비교용 upstream 판(6b7a0deb) |
| `driver/Makefile` | 외부 모듈 빌드 (Kbuild) |
| `check_camera.sh` | 카메라 인식과 사진 한 장 확인 |
| `measure/` | 측정 로그 (`[bsp]` 줄) |

## 빌드와 적용

```bash
cd driver && make
sudo cp imx708.ko /lib/modules/$(uname -r)/updates/
echo "override imx708 * updates" | sudo tee /etc/depmod.d/imx708-override.conf
sudo depmod -a
cd .. && dtc -@ -I dts -O dtb -o my-imx708.dtbo my-imx708.dts
sudo cp my-imx708.dtbo /boot/firmware/overlays/
# /boot/firmware/config.txt: camera_auto_detect=0, dtoverlay=my-imx708
sudo reboot
```

## 라이선스

`driver/` 의 두 `.c` 파일은 Raspberry Pi 커널(GPL-2.0) 소스를 바탕으로 합니다.
