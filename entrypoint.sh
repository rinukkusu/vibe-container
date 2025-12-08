#!/bin/bash
set -e

echo "=== Starting Remote Development Container ==="
echo ""

# Verify dev user exists
if ! id dev &>/dev/null; then
    echo "ERROR: User 'dev' does not exist!"
    echo "This should have been created in the Dockerfile."
    echo "Creating user now as fallback..."
    useradd -m -s /bin/bash -G sudo dev || true
    echo "dev:dev" | chpasswd || true
    echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers || true
fi

echo "✓ User 'dev' verified (UID: $(id -u dev), GID: $(id -g dev))"

# Fix ownership and permissions of /home/dev
echo "Fixing /home/dev ownership and permissions..."
chown -R dev:dev /home/dev 2>/dev/null || true
chmod 755 /home/dev
echo "✓ /home/dev ownership and permissions corrected"
echo ""

# Phase 2: SSH Configuration
echo "=== Phase 2: SSH Configuration ==="

# Ensure .ssh directory exists with correct permissions
mkdir -p /home/dev/.ssh
chown dev:dev /home/dev/.ssh
chmod 700 /home/dev/.ssh

if [ -f "$SSH_PUBLIC_KEY_PATH" ]; then
    echo "Configuring SSH public key..."
    set +e
    cp "$SSH_PUBLIC_KEY_PATH" /home/dev/.ssh/authorized_keys 2>&1
    CP_EXIT_CODE=$?
    set -e

    if [ $CP_EXIT_CODE -eq 0 ]; then
        chown dev:dev /home/dev/.ssh/authorized_keys
        chmod 600 /home/dev/.ssh/authorized_keys
        echo "✓ SSH key configured for user 'dev'"
    else
        echo "⚠ Failed to copy SSH public key (exit code: $CP_EXIT_CODE)"
        echo "  You can add your key manually after connecting"
    fi
else
    echo "⚠ WARNING: No SSH public key found at $SSH_PUBLIC_KEY_PATH"
    echo "  Container will start but you won't be able to SSH in"
    echo "  Mount your key at runtime or add it manually after exec'ing into the container"
    echo ""
    echo "  To add key manually:"
    echo "    docker exec -it <container> bash"
    echo "    echo 'your-public-key-here' > /home/dev/.ssh/authorized_keys"
    echo "    chown dev:dev /home/dev/.ssh/authorized_keys"
    echo "    chmod 600 /home/dev/.ssh/authorized_keys"
fi

echo ""

# Phase 3: GitHub CLI Configuration
echo "=== Phase 3: GitHub CLI Configuration ==="

if [ -n "$GITHUB_TOKEN" ]; then
    echo "Configuring GitHub CLI..."
    # Don't fail the entire script if gh auth fails
    set +e
    su - dev -c "echo '$GITHUB_TOKEN' | gh auth login --with-token" 2>&1
    GH_EXIT_CODE=$?
    set -e

    if [ $GH_EXIT_CODE -eq 0 ]; then
        echo "✓ GitHub CLI authenticated successfully"
    else
        echo "⚠ GitHub CLI authentication failed (exit code: $GH_EXIT_CODE)"
        echo "  You can authenticate manually after connecting: gh auth login"
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
if command -v python3 &> /dev/null; then
    echo "  - Python: $(python3 --version 2>&1)"
fi
if command -v node &> /dev/null; then
    echo "  - Node.js: $(node --version)"
    echo "  - npm: $(npm --version)"
fi
if command -v dart &> /dev/null; then
    echo "  - Dart: $(dart --version 2>&1 | head -n1)"
fi
if command -v dotnet &> /dev/null; then
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
