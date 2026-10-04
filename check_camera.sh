#!/bin/bash
set -e
echo "== 카메라 목록"
rpicam-hello --list-cameras
mkdir -p ~/rpi5-camera-bsp/shots
name=~/rpi5-camera-bsp/shots/$(date +%m%d-%H%M%S).jpg
echo "== 사진 찍기 → $name"
rpicam-still -n -t 2000 -o "$name"
ls -lh "$name"