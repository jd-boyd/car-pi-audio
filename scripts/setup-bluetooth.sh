#!/bin/bash
set -e

echo "Setting up Bluetooth audio receiver..."

# Install Bluetooth packages
apt-get install -y \
    bluetooth \
    bluez \
    bluez-tools \
    pi-bluetooth

# Add pi user to bluetooth group
usermod -a -G bluetooth pi

# Copy Bluetooth configuration
cp /tmp/main.conf /etc/bluetooth/main.conf

# Configure Bluetooth to be discoverable and accept connections
cat > /etc/systemd/system/bluetooth-agent.service << 'EOF'
[Unit]
Description=Bluetooth Agent
Requires=bluetooth.service
After=bluetooth.service

[Service]
ExecStart=/usr/bin/bt-agent -c NoInputNoOutput
Type=simple
Restart=always
RestartSec=1
KillMode=mixed
KillSignal=SIGINT
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create script to make device discoverable and pairable
cat > /usr/local/bin/bluetooth-setup.sh << 'EOF'
#!/bin/bash
# Make Bluetooth discoverable and pairable
sleep 5
bluetoothctl <<END_SCRIPT
power on
discoverable on
pairable on
agent NoInputNoOutput
default-agent
END_SCRIPT
EOF

chmod +x /usr/local/bin/bluetooth-setup.sh

# Create systemd service to run Bluetooth setup
cat > /etc/systemd/system/bluetooth-setup.service << 'EOF'
[Unit]
Description=Setup Bluetooth for audio receiving
After=bluetooth.service pulseaudio.service
Requires=bluetooth.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/bluetooth-setup.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

# Create a script to automatically accept Bluetooth pairings
cat > /usr/local/bin/bluetooth-accept.py << 'EOF'
#!/usr/bin/env python3
import sys
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

BUS_NAME = 'org.bluez'
AGENT_INTERFACE = 'org.bluez.Agent1'
AGENT_PATH = "/test/agent"

class Agent(dbus.service.Object):
    exit_on_release = True

    def set_exit_on_release(self, exit_on_release):
        self.exit_on_release = exit_on_release

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="", out_signature="")
    def Release(self):
        print("Release")
        if self.exit_on_release:
            mainloop.quit()

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        print(f"AuthorizeService ({device}, {uuid})")
        return

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print(f"RequestPinCode ({device})")
        return "0000"

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        print(f"RequestPasskey ({device})")
        return dbus.UInt32("0000")

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print(f"DisplayPasskey ({device}, {passkey:06d} entered {entered})")

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        print(f"DisplayPinCode ({device}, {pincode})")

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print(f"RequestConfirmation ({device}, {passkey:06d})")
        return

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print(f"RequestAuthorization ({device})")
        return

    @dbus.service.method(AGENT_INTERFACE,
                         in_signature="", out_signature="")
    def Cancel(self):
        print("Cancel")

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    bus = dbus.SystemBus()
    agent = Agent(bus, AGENT_PATH)

    obj = bus.get_object(BUS_NAME, "/org/bluez")
    manager = dbus.Interface(obj, "org.bluez.AgentManager1")
    manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")

    print("Agent registered - accepting all connections")
    manager.RequestDefaultAgent(AGENT_PATH)

    mainloop = GLib.MainLoop()
    mainloop.run()
EOF

chmod +x /usr/local/bin/bluetooth-accept.py

# Create systemd service for automatic pairing acceptance
cat > /etc/systemd/system/bluetooth-accept.service << 'EOF'
[Unit]
Description=Bluetooth Auto Accept Agent
After=bluetooth.service
Requires=bluetooth.service

[Service]
ExecStart=/usr/local/bin/bluetooth-accept.py
Type=simple
Restart=always
RestartSec=1
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable Bluetooth services
systemctl enable bluetooth.service
systemctl enable bluetooth-agent.service
systemctl enable bluetooth-setup.service
systemctl enable bluetooth-accept.service

# Configure PulseAudio Bluetooth policy
mkdir -p /home/pi/.config/pulse
cat >> /home/pi/.config/pulse/default.pa << 'EOF'

# Bluetooth audio policy - automatically switch to Bluetooth when available
load-module module-switch-on-connect
EOF

chown -R pi:pi /home/pi/.config

echo "Bluetooth setup complete"