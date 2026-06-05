# 📷 LegacyCam - iOS 7 IP Camera (armv7 / iPhone 4 compatible)

LegacyCam is a lightweight MJPEG IP camera server designed for older iOS devices (iOS 7 / iPhone 4 / armv7).

It exposes a simple HTTP interface usable with Home Assistant, browsers, curl, and LAN tools.

## Features
- MJPEG stream over HTTP (/stream)
- Snapshot endpoint (/snapshot.jpg)
- Flash control (/flash/on, /flash/off)
- Lightweight, optimized for iPhone 4
- LAN streaming on port 8080

## API

Stream:
http://DEVICE_IP:8080/stream

Snapshot:
http://DEVICE_IP:8080/snapshot.jpg

Flash:
http://DEVICE_IP:8080/flash/on
http://DEVICE_IP:8080/flash/off

## Home Assistant

camera:
  - platform: mjpeg
    name: LegacyCam
    mjpeg_url: http://192.168.1.8:8080/stream

## Build Requirements

Install Theos:
https://theos.dev/docs/installation

iOS SDK:
iPhoneOS7.1.sdk placed in $THEOS/sdks/

## Build
make clean
make package

## Install (jailbroken device)

scp packages/*.deb iphone4:/var/root

ssh iphone4
dpkg -i /var/root/*.deb

If app not appears on home screen:
su - mobile
uicache -a

If needed:
killall -9 SpringBoard

## Notes
- iPhone 4 optimized (armv7)
- No audio stream (by design)
- Recording handled externally (Home Assistant recommended)
