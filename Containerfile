FROM ubuntu:22.04

# Set environment variables to prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PACKER_VERSION=1.9.4

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    qemu-user-static \
    qemu-utils \
    kpartx \
    parted \
    dosfstools \
    e2fsprogs \
    mount \
    util-linux \
    fdisk \
    git \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Packer
RUN wget https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip \
    && unzip packer_${PACKER_VERSION}_linux_amd64.zip \
    && mv packer /usr/local/bin/ \
    && rm packer_${PACKER_VERSION}_linux_amd64.zip

# Install Packer ARM Image plugin
RUN packer plugins install github.com/solo-io/arm-image

# Create workspace directory
WORKDIR /workspace

# Create images directory for output
RUN mkdir -p /workspace/images

# Set up qemu for ARM emulation
#RUN ln -sf /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static

# Copy entrypoint script
COPY --chmod=755 scripts/entrypoint.sh  /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD []
