#!/bin/bash
set -e

# Ensure we're in the workspace
cd /workspace

# Check if packer configuration exists
if [ ! -f "raspberry-pi.pkr.hcl" ]; then
    echo "Error: raspberry-pi.pkr.hcl not found in workspace"
    echo "Please mount your project directory to /workspace"
    exit 1
fi

# Check if SSH key exists
if [ ! -f "files/ssh/authorized_keys" ]; then
    echo "Warning: SSH authorized_keys not found"
    echo "Creating example SSH key..."
    mkdir -p files/ssh
    ssh-keygen -t ed25519 -f files/ssh/pi_key -N "" -C "pi@raspberry"
    cp files/ssh/pi_key.pub files/ssh/authorized_keys
    echo "SSH key created. Public key:"
    cat files/ssh/authorized_keys
fi

# Run the build
echo "Starting Packer build..."
echo packer build $@ raspberry-pi.pkr.hcl
exec packer build $@ raspberry-pi.pkr.hcl
