# Raspberry Pi Car Audio Player

This project uses Packer to build a customized Raspberry Pi OS image with a read-only root filesystem, pre-configured SSH access, and audio capabilities including I2S audio pihat and Bluetooth receiver functionality.

Currently it is targetting a Raspberry Pi Zero 2w, and is bluetooth audio only. There are issues with using Bluetooth and Wifi at the same time using some Pi onboard wifi/bt, so I'm starting simple with the minimum useful for my car.

## Prerequisites

- Podman for containerized builds

## Quick Start

The containerized build eliminates the need to install Packer and its dependencies on your host system. The container includes all necessary tools and ARM emulation support.

Build the container image:
```bash
podman build -t car-pi-builder .
```

Run the build inside the container:
```bash
podman run --rm -it \
  -v $(pwd):/workspace:Z \
  --privileged \
  car-pi-builder
```

The privileged flag is required for loop device access during image modification. If you don't have SSH keys set up, the container will automatically generate them for you.

## Configuration

Place your public key in `files/ssh/authorized_keys`. The build process will install this key for the `pi` user and disable password authentication.

## Build Output

The completed image will be saved as `raspberry-pi-readonly-[timestamp].img` in the current directory. Flash this image to an SD card using your preferred method:

```bash
sudo dd if=raspberry-pi-readonly-[timestamp].img of=/dev/sdX bs=4M status=progress
```

### Bluetooth Configuration

Edit `files/bluetooth/main.conf` to change the Bluetooth device name or other settings.
