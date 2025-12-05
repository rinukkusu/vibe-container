#!/bin/bash
set -e

echo "=== Starting Remote Development Container ==="
echo ""

# Phase 1: Language Runtime Installation
echo "=== Phase 1: Runtime Installation ==="

# Install Python if requested
if [ "$INSTALL_PYTHON" = "true" ] && ! command -v python3 &> /dev/null; then
    echo "Installing Python 3..."
    apt-get update -qq
    apt-get install -y python3 python3-pip python3-venv > /dev/null 2>&1
    echo "✓ Python $(python3 --version 2>&1 | awk '{print $2}') installed"
elif [ "$INSTALL_PYTHON" = "true" ]; then
    echo "✓ Python already installed: $(python3 --version 2>&1 | awk '{print $2}')"
fi

# Install Node.js if requested
if [ "$INSTALL_NODEJS" = "true" ] && ! command -v node &> /dev/null; then
    echo "Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - > /dev/null 2>&1
    apt-get install -y nodejs > /dev/null 2>&1
    echo "✓ Node.js $(node --version) installed"
elif [ "$INSTALL_NODEJS" = "true" ]; then
    echo "✓ Node.js already installed: $(node --version)"
fi

# Install Dart if requested
if [ "$INSTALL_DART" = "true" ] && ! command -v dart &> /dev/null; then
    echo "Installing Dart..."
    wget -qO- https://dl-ssl.google.com/linux/linux_signing_key.pub | \
        gpg --dearmor -o /usr/share/keyrings/dart.gpg 2>/dev/null
    echo "deb [signed-by=/usr/share/keyrings/dart.gpg arch=amd64] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" | \
        tee /etc/apt/sources.list.d/dart_stable.list > /dev/null
    apt-get update -qq
    apt-get install -y dart > /dev/null 2>&1
    echo "✓ Dart $(dart --version 2>&1 | head -n1) installed"
elif [ "$INSTALL_DART" = "true" ]; then
    echo "✓ Dart already installed: $(dart --version 2>&1 | head -n1)"
fi

# Install .NET SDK if requested
if [ "$INSTALL_DOTNET" = "true" ] && ! command -v dotnet &> /dev/null; then
    echo "Installing .NET SDK..."
    wget -q https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb > /dev/null 2>&1
    rm packages-microsoft-prod.deb
    apt-get update -qq
    # Try .NET 10, fall back to 9 or 8 if not available
    if apt-cache show dotnet-sdk-10.0 > /dev/null 2>&1; then
        apt-get install -y dotnet-sdk-10.0 > /dev/null 2>&1
    elif apt-cache show dotnet-sdk-9.0 > /dev/null 2>&1; then
        apt-get install -y dotnet-sdk-9.0 > /dev/null 2>&1
    else
        apt-get install -y dotnet-sdk-8.0 > /dev/null 2>&1
    fi
    echo "✓ .NET SDK $(dotnet --version) installed"
elif [ "$INSTALL_DOTNET" = "true" ]; then
    echo "✓ .NET SDK already installed: $(dotnet --version)"
fi

# Clean up apt cache
if [ "$INSTALL_PYTHON" = "true" ] || [ "$INSTALL_NODEJS" = "true" ] || \
   [ "$INSTALL_DART" = "true" ] || [ "$INSTALL_DOTNET" = "true" ]; then
    apt-get clean
    echo ""
fi

# Phase 2: SSH Configuration
echo "=== Phase 2: SSH Configuration ==="

if [ -f "$SSH_PUBLIC_KEY_PATH" ]; then
    echo "Configuring SSH public key..."
    cp "$SSH_PUBLIC_KEY_PATH" /home/dev/.ssh/authorized_keys
    chown dev:dev /home/dev/.ssh/authorized_keys
    chmod 600 /home/dev/.ssh/authorized_keys
    echo "✓ SSH key configured for user 'dev'"
else
    echo "⚠ WARNING: No SSH public key found at $SSH_PUBLIC_KEY_PATH"
    echo "  You will need to copy your public key manually or mount it at runtime"
fi

echo ""

# Phase 3: GitHub CLI Configuration
echo "=== Phase 3: GitHub CLI Configuration ==="

if [ -n "$GITHUB_TOKEN" ]; then
    echo "Configuring GitHub CLI..."
    su - dev -c "echo '$GITHUB_TOKEN' | gh auth login --with-token" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✓ GitHub CLI authenticated successfully"
    else
        echo "⚠ GitHub CLI authentication failed"
    fi
else
    echo "No GITHUB_TOKEN provided. Run 'gh auth login' manually after connecting."
fi

echo ""

# Phase 4: Workspace Setup
echo "=== Phase 4: Workspace Setup ==="
mkdir -p /home/dev/workspace
chown -R dev:dev /home/dev/workspace
echo "✓ Workspace ready at /home/dev/workspace"

echo ""

# Phase 5: Display Connection Information
echo "==================================="
echo "🚀 Container is ready!"
echo "==================================="
echo "SSH User: dev"
echo "Workspace: /home/dev/workspace"
echo ""
echo "Installed tools:"
echo "  - SSH Server: $(sshd -v 2>&1 | head -n1)"
echo "  - Git: $(git --version)"
echo "  - GitHub CLI: $(gh --version | head -n1)"
if command -v claude &> /dev/null; then
    echo "  - Claude Code: $(claude --version 2>/dev/null || echo 'installed (auth required)')"
else
    echo "  - Claude Code: installed (auth required)"
fi

# Display installed runtimes
if [ "$INSTALL_PYTHON" = "true" ] && command -v python3 &> /dev/null; then
    echo "  - Python: $(python3 --version 2>&1)"
fi
if [ "$INSTALL_NODEJS" = "true" ] && command -v node &> /dev/null; then
    echo "  - Node.js: $(node --version)"
    echo "  - npm: $(npm --version)"
fi
if [ "$INSTALL_DART" = "true" ] && command -v dart &> /dev/null; then
    echo "  - Dart: $(dart --version 2>&1 | head -n1)"
fi
if [ "$INSTALL_DOTNET" = "true" ] && command -v dotnet &> /dev/null; then
    echo "  - .NET: $(dotnet --version)"
fi

echo ""
echo "To connect via SSH:"
echo "  ssh -p <PORT> dev@<HOST>"
echo ""
echo "First-time setup (after SSH connection):"
echo "  claude auth    # Authenticate Claude Code"
echo "  gh auth status # Verify GitHub CLI"
echo "==================================="
echo ""

# Phase 6: Start SSH daemon
echo "Starting SSH daemon..."
exec "$@"
