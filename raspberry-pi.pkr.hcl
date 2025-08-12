packer {
  required_plugins {
    arm-image = {
      version = ">= 0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "base_image_url" {
  type        = string
  description = "URL to download the base Raspberry Pi OS image"
  default     = "https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2023-12-11/2023-12-11-raspios-bookworm-armhf-lite.img.xz"
}

variable "ssh_public_key_file" {
  type        = string
  description = "Path to SSH public key file"
  default     = "./files/ssh/authorized_keys"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "arm-image" "raspberry_pi" {
  iso_url      = var.base_image_url
  iso_checksum = "sha256:58a3ec57402c86332e67789a6b8f149aeeb4e7bb0a16c9388a66ea6e07012e45"

  output_filename = "raspberry-pi-readonly-${local.timestamp}.img"

  target_image_size = 4294967296  # 4GB
}

build {
  name    = "raspberry-pi-readonly"
  sources = ["source.arm-image.raspberry_pi"]

  # Enable SSH for provisioning
  provisioner "shell" {
    inline = [
      "sleep 10",
      "systemctl enable ssh",
      "systemctl start ssh"
    ]
  }

  # Copy configuration files
  provisioner "file" {
    source      = "./files/config/config.txt"
    destination = "/boot/config.txt"
  }

  provisioner "file" {
    source      = "./files/config/cmdline.txt"
    destination = "/boot/cmdline.txt"
  }

  provisioner "file" {
    source      = "./files/bluetooth/main.conf"
    destination = "/tmp/main.conf"
  }

  # Setup SSH keys
  provisioner "shell" {
    inline = [
      "mkdir -p /home/pi/.ssh",
      "chown pi:pi /home/pi/.ssh",
      "chmod 700 /home/pi/.ssh"
    ]
  }

  provisioner "file" {
    source      = var.ssh_public_key_file
    destination = "/home/pi/.ssh/authorized_keys"
  }

  provisioner "shell" {
    inline = [
      "chown pi:pi /home/pi/.ssh/authorized_keys",
      "chmod 600 /home/pi/.ssh/authorized_keys"
    ]
  }

  # Run setup scripts
  provisioner "file" {
    source      = "./scripts/"
    destination = "/tmp/"
  }

  provisioner "shell" {
    scripts = [
      "/tmp/setup-readonly.sh",
      "/tmp/setup-audio.sh",
      "/tmp/setup-bluetooth.sh"
    ]
  }

  # Final cleanup and configuration
  provisioner "shell" {
    inline = [
      "rm -rf /tmp/setup-*.sh",
      "rm -rf /tmp/main.conf",
      "apt-get clean",
      "apt-get autoremove -y",
      "systemctl enable ssh",
      "systemctl disable dhcpcd",  # Will be handled by systemd-networkd
      "systemctl enable systemd-networkd",
      "sync"
    ]
  }

  post-processor "shell-local" {
    inline = [
      "echo 'Build completed successfully!'",
      "echo 'Image saved as: ${build.PackerRunUUID}.img'",
      "ls -la *.img"
    ]
  }
}
