FROM ubuntu:24.04

LABEL maintainer="vibe-container"
LABEL description="Remote development environment with SSH, Git, GitHub CLI, and Claude Code"
LABEL version="1.0"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and SSH server
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    build-essential \
    apt-transport-https \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/apt/keyrings

# Install GitHub CLI from official repository
RUN wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | \
    tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Create non-root dev user with sudo privileges
RUN useradd -m -s /bin/bash -G sudo dev && \
    echo "dev:dev" | chpasswd && \
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Set up SSH directory for dev user
RUN mkdir -p /home/dev/.ssh && \
    chown -R dev:dev /home/dev/.ssh && \
    chmod 700 /home/dev/.ssh

# Create workspace and config directories
RUN mkdir -p /home/dev/workspace && \
    mkdir -p /home/dev/.config && \
    mkdir -p /home/dev/.claude && \
    chown -R dev:dev /home/dev/workspace /home/dev/.config /home/dev/.claude

# Switch to dev user for Claude installation
USER dev

# Install Claude Code CLI using official install script as dev user
RUN curl -fsSL https://claude.ai/install.sh | bash -s latest

# Add Claude bin directory to PATH in .bashrc
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/dev/.bashrc

# Switch back to root for remaining configuration
USER root

# Configure SSH daemon
RUN mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# SSH security hardening
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config && \
    echo "AllowUsers dev" >> /etc/ssh/sshd_config && \
    echo "Protocol 2" >> /etc/ssh/sshd_config && \
    echo "StrictModes yes" >> /etc/ssh/sshd_config && \
    echo "MaxAuthTries 3" >> /etc/ssh/sshd_config && \
    echo "MaxSessions 2" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config && \
    echo "LoginGraceTime 60" >> /etc/ssh/sshd_config && \
    echo "PubkeyAcceptedAlgorithms +ssh-rsa" >> /etc/ssh/sshd_config && \
    echo "HostKeyAlgorithms +ssh-rsa" >> /etc/ssh/sshd_config

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables
ENV GITHUB_TOKEN=""
ENV SSH_PUBLIC_KEY_PATH="/ssh-keys/authorized_keys"
ENV INSTALL_PYTHON="false"
ENV INSTALL_NODEJS="false"
ENV INSTALL_DART="false"
ENV INSTALL_DOTNET="false"

# Expose SSH port
EXPOSE 22

# Set entrypoint and default command
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e"]
