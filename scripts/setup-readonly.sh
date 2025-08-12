#!/bin/bash
set -e

echo "Setting up read-only root filesystem..."

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    busybox-syslogd \
    overlayroot \
    rsync

# Remove rsyslog to avoid conflicts with busybox-syslogd
apt-get remove --purge -y rsyslog

# Configure overlayroot for read-only filesystem
cat > /etc/overlayroot.conf << 'EOF'
overlayroot="tmpfs"
overlayroot_cfgdisk="disabled"
EOF

# Create systemd service to remount root as read-only
cat > /etc/systemd/system/readonly-root.service << 'EOF'
[Unit]
Description=Mount root filesystem read-only
DefaultDependencies=false
Conflicts=shutdown.target
After=systemd-remount-fs.service
Before=systemd-sysusers.service sysinit.target shutdown.target
Wants=systemd-remount-fs.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/mount -o remount,ro /
TimeoutSec=0

[Install]
WantedBy=sysinit.target
EOF

# Enable the readonly root service
systemctl enable readonly-root.service

# Setup tmpfs for writable directories
cat >> /etc/fstab << 'EOF'
# Temporary filesystems for read-only root
tmpfs /tmp tmpfs defaults,noatime,nosuid,size=100m 0 0
tmpfs /var/tmp tmpfs defaults,noatime,nosuid,size=30m 0 0
tmpfs /var/log tmpfs defaults,noatime,nosuid,nodev,noexec,size=30m 0 0
tmpfs /var/spool/cron/crontabs tmpfs defaults,noatime,nosuid,nodev,noexec,size=1m 0 0
tmpfs /var/cache/apt/archives tmpfs defaults,noatime,nosuid,nodev,noexec,size=50m 0 0
tmpfs /var/lib/systemd/coredump tmpfs defaults,noatime,nosuid,nodev,noexec,size=10m 0 0
EOF

# Disable swap to prevent writes
systemctl disable dphys-swapfile

# Configure SSH for readonly filesystem
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Disable services that write frequently
systemctl disable \
    apt-daily.timer \
    apt-daily-upgrade.timer \
    man-db.timer \
    logrotate.timer

# Configure systemd to avoid writes
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/readonly.conf << 'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=30M
RuntimeMaxFileSize=5M
EOF

# Create startup script to prepare tmpfs directories
cat > /usr/local/bin/prepare-tmpfs.sh << 'EOF'
#!/bin/bash
# Create necessary directories in tmpfs after boot
mkdir -p /var/log/apt
mkdir -p /var/cache/apt/archives/partial
chmod 755 /var/log/apt
chmod 755 /var/cache/apt/archives
chmod 755 /var/cache/apt/archives/partial
EOF

chmod +x /usr/local/bin/prepare-tmpfs.sh

# Create systemd service to run tmpfs preparation
cat > /etc/systemd/system/prepare-tmpfs.service << 'EOF'
[Unit]
Description=Prepare tmpfs directories
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/prepare-tmpfs.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

systemctl enable prepare-tmpfs.service

# Prevent log rotation from failing on readonly filesystem
rm -f /etc/cron.daily/logrotate
rm -f /etc/cron.daily/apt-compat
rm -f /etc/cron.daily/dpkg
rm -f /etc/cron.daily/man-db

echo "Read-only filesystem setup complete"