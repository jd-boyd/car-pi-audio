#!/bin/bash
set -e

echo "Setting up audio support..."

# Install audio packages
apt-get install -y \
    alsa-utils \
    pulseaudio \
    pulseaudio-module-bluetooth \
    pulseaudio-utils \
    libasound2-dev \
    libasound2-plugins

# Add pi user to audio group
usermod -a -G audio pi

# Configure ALSA for I2S
cat > /home/pi/.asoundrc << 'EOF'
pcm.!default {
    type hw
    card 1
    device 0
}

ctl.!default {
    type hw
    card 1
}
EOF

chown pi:pi /home/pi/.asoundrc

# Configure PulseAudio for the pi user
mkdir -p /home/pi/.config/pulse
cat > /home/pi/.config/pulse/default.pa << 'EOF'
#!/usr/bin/pulseaudio -nF

# Load audio drivers
.include /etc/pulse/default.pa

# Make sure we always have a sink around, even if it is a null sink
load-module module-always-sink

# Load I2S audio
load-module module-alsa-sink device=hw:1,0 sink_name=i2s_output
load-module module-alsa-source device=hw:1,0 source_name=i2s_input

# Set I2S as default
set-default-sink i2s_output
set-default-source i2s_input

# Load Bluetooth modules
load-module module-bluetooth-policy
load-module module-bluetooth-discover
EOF

chown -R pi:pi /home/pi/.config

# Configure PulseAudio system settings
cat > /etc/pulse/daemon.conf << 'EOF'
# PulseAudio daemon configuration for Raspberry Pi
daemonize = no
fail = yes
allow-module-loading = yes
allow-exit = yes
use-pid-file = yes
system-instance = no
local-server-type = user
enable-shm = yes
shm-size-bytes = 0
lock-memory = no
cpu-limit = no
high-priority = yes
nice-level = -11
realtime-scheduling = yes
realtime-priority = 5
exit-idle-time = 20
scache-idle-time = 20
dl-search-path = /usr/lib/pulse-14.2/modules
default-script-file = /etc/pulse/default.pa
load-default-script-file = yes
log-target = syslog
log-level = notice
log-meta = no
log-time = no
log-backtrace = 0
resample-method = speex-float-1
avoid-resampling = no
enable-remixing = yes
remixing-use-all-sink-channels = yes
enable-lfe-remixing = no
default-sample-format = s16le
default-sample-rate = 44100
alternate-sample-rate = 48000
default-sample-channels = 2
default-channel-map = front-left,front-right
default-fragments = 4
default-fragment-size-msec = 25
enable-deferred-volume = yes
deferred-volume-safety-margin-usec = 8000
deferred-volume-extra-delay-usec = 0
flat-volumes = no
EOF

# Enable lingering for pi user so PulseAudio starts at boot
loginctl enable-linger pi

# Create systemd user service for PulseAudio
mkdir -p /home/pi/.config/systemd/user
cat > /home/pi/.config/systemd/user/pulseaudio.service << 'EOF'
[Unit]
Description=PulseAudio sound system
After=graphical-session.target
Requires=pulseaudio.socket

[Service]
Type=notify
ExecStart=/usr/bin/pulseaudio --daemonize=no --log-target=journal
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

chown -R pi:pi /home/pi/.config/systemd

# Enable PulseAudio service for pi user
sudo -u pi systemctl --user enable pulseaudio.service
sudo -u pi systemctl --user enable pulseaudio.socket

echo "Audio setup complete"