# Remote Development Container

A secure, SSH-accessible remote development environment with on-demand language runtime installation. Built for CI/CD pipelines with a small base image (~800MB) that installs runtimes on first start based on your needs.

## Features

- **Ubuntu 24.04 LTS** base image
- **OpenSSH server** with security hardening
- **Git** for version control
- **GitHub CLI (gh)** with token authentication
- **Claude Code CLI** (latest version)
- **On-demand language runtimes**:
  - Python 3 with pip and venv
  - Node.js LTS with npm
  - Dart (latest stable)
  - .NET SDK (8.0/9.0/10.0)
- **Non-root user** (dev) with sudo access
- **Persistent workspace** and configuration
- **Security-first** design

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- SSH public key (recommended: Ed25519, but RSA also supported)
  - **Generate Ed25519 key (recommended):** `ssh-keygen -t ed25519 -C "your_email@example.com"`
  - **Or use existing RSA key:** `~/.ssh/id_rsa.pub`
- GitHub Personal Access Token (optional, for GitHub CLI)

### Local Testing Setup

1. **Create SSH keys directory and copy your public key:**

```bash
mkdir -p ssh-keys
cp ~/.ssh/id_rsa.pub ssh-keys/authorized_keys
chmod 644 ssh-keys/authorized_keys
```

2. **Configure environment variables:**

```bash
cp .env.example .env
# Edit .env and configure:
# - GITHUB_TOKEN (optional)
# - INSTALL_PYTHON, INSTALL_NODEJS, etc. (set to "true" for needed runtimes)
```

3. **Build and start the container:**

```bash
docker-compose up -d
```

4. **Connect via SSH:**

```bash
ssh -p 2222 dev@localhost
```

5. **First-time configuration (inside container):**

```bash
# Authenticate Claude Code
claude auth

# Verify GitHub CLI (if GITHUB_TOKEN was set)
gh auth status

# Check installed runtimes
python3 --version   # if INSTALL_PYTHON=true
node --version      # if INSTALL_NODEJS=true
dart --version      # if INSTALL_DART=true
dotnet --version    # if INSTALL_DOTNET=true
```

## CI/CD Usage

This project includes automated GitHub Actions workflow that builds and pushes images to GitHub Container Registry.

### Using Pre-built Images from GitHub Container Registry

```bash
# Pull the latest image
docker pull ghcr.io/rinukkusu/vibe-container:latest

# Pull a specific version
docker pull ghcr.io/rinukkusu/vibe-container:v1.0.0

# Run the pre-built image
docker run -d \
  --name remote-dev-env \
  -p 2222:22 \
  -e INSTALL_PYTHON=true \
  -e INSTALL_NODEJS=true \
  -v ~/.ssh/id_rsa.pub:/ssh-keys/authorized_keys:ro \
  -v dev-workspace:/home/dev/workspace \
  ghcr.io/rinukkusu/vibe-container:latest
```

### Building Your Own Image

```bash
# Build the image
docker build -t your-registry/dev-container:latest .

# Tag for versioning
docker tag your-registry/dev-container:latest your-registry/dev-container:v1.0.0

# Push to registry
docker push your-registry/dev-container:latest
docker push your-registry/dev-container:v1.0.0
```

### Automated Builds

This repository includes a GitHub Actions workflow (`.github/workflows/build-and-push.yml`) that automatically:

- **Builds** the Docker image on every push to main
- **Pushes** to GitHub Container Registry (ghcr.io)
- **Tags** with multiple strategies:
  - `latest` - latest build from main branch
  - `main-<sha>` - commit SHA from main branch
  - `v1.0.0` - semantic version tags
  - `1.0`, `1` - major.minor and major version tags

**Creating a Release:**

```bash
# Tag a new version
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will automatically build and push:
# - ghcr.io/rinukkusu/vibe-container:v1.0.0
# - ghcr.io/rinukkusu/vibe-container:1.0
# - ghcr.io/rinukkusu/vibe-container:1
# - ghcr.io/rinukkusu/vibe-container:latest
```

### Running the Built Image

```bash
docker run -d \
  --name remote-dev-env \
  -p 2222:22 \
  -e GITHUB_TOKEN=${GITHUB_TOKEN} \
  -e INSTALL_PYTHON=true \
  -e INSTALL_NODEJS=true \
  -e INSTALL_DART=false \
  -e INSTALL_DOTNET=false \
  -v /path/to/authorized_keys:/ssh-keys/authorized_keys:ro \
  -v dev-workspace:/home/dev/workspace \
  -v ssh-host-keys:/etc/ssh \
  -v gh-config:/home/dev/.config/gh \
  -v claude-config:/home/dev/.claude \
  -v apt-cache:/var/cache/apt \
  -v apt-lib:/var/lib/apt \
  --security-opt no-new-privileges:true \
  your-registry/dev-container:latest
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `GITHUB_TOKEN` | GitHub personal access token | - | No |
| `INSTALL_PYTHON` | Install Python 3 on first start | `false` | No |
| `INSTALL_NODEJS` | Install Node.js LTS on first start | `false` | No |
| `INSTALL_DART` | Install Dart on first start | `false` | No |
| `INSTALL_DOTNET` | Install .NET SDK on first start | `false` | No |
| `SSH_PUBLIC_KEY_PATH` | Path to mounted authorized_keys | `/ssh-keys/authorized_keys` | No |

### Ports

- **Container:** 22 (SSH)
- **Host mapping:** 2222:22 (configurable in docker-compose.yml)

### Volumes

**Required:**
- SSH keys: `./ssh-keys/authorized_keys:/ssh-keys/authorized_keys:ro`

**Recommended for persistence:**
- Workspace: `dev-workspace:/home/dev/workspace`
- SSH host keys: `ssh-host-keys:/etc/ssh`
- GitHub config: `gh-config:/home/dev/.config/gh`
- Claude config: `claude-config:/home/dev/.claude`
- APT cache: `apt-cache:/var/cache/apt`
- APT lib: `apt-lib:/var/lib/apt`

## On-Demand Runtime Installation

This container uses a unique approach: language runtimes are installed on **first start** based on environment variables, not baked into the image.

### Benefits

- **Smaller base image**: ~800MB instead of ~2GB
- **Faster CI/CD builds**: Only core tools in the image
- **Flexible**: Same image, different runtime combinations
- **On-demand**: Only install what you need

### How It Works

1. Set environment variables (e.g., `INSTALL_PYTHON=true`)
2. On first start, entrypoint script installs requested runtimes
3. Installations persist via volume mounts
4. Subsequent starts are fast (~5 seconds)

### First Start Time

- Without runtimes: ~5 seconds
- With all 4 runtimes: ~2-5 minutes (one-time installation)

## Security Features

### SSH Hardening

- Root login disabled
- Password authentication disabled
- Public key authentication only
- User whitelist (only 'dev' can login)
- SSH Protocol 2 only
- Max 3 authentication attempts
- Session timeouts (idle disconnect after 10 minutes)
- Login grace time: 60 seconds

### Container Security

- Non-root default user with sudo access
- No privilege escalation (`no-new-privileges:true`)
- Resource limits to prevent DoS
- Health monitoring
- Read-only SSH key mount
- Secrets not baked into image layers

### Best Practices

- Never commit `.env` files or SSH keys
- Rotate credentials regularly
- Use Docker secrets for production
- Keep base image updated
- Monitor container logs

## Usage Examples

### Connect via SSH

```bash
# Local
ssh -p 2222 dev@localhost

# Remote
ssh -p 2222 dev@your-server.com
```

### Transfer Files

```bash
# Copy file to container
scp -P 2222 myfile.txt dev@localhost:~/workspace/

# Copy file from container
scp -P 2222 dev@localhost:~/workspace/myfile.txt ./
```

### Execute Commands

```bash
# Direct command execution
ssh -p 2222 dev@localhost "git status"

# Interactive shell
ssh -p 2222 dev@localhost
```

### View Container Logs

```bash
# Docker Compose
docker-compose logs -f

# Docker
docker logs -f remote-dev-env
```

### Stop/Start Container

```bash
# Docker Compose
docker-compose down
docker-compose up -d

# Docker
docker stop remote-dev-env
docker start remote-dev-env
```

## Troubleshooting

### Cannot connect via SSH

**Symptoms:** `Connection refused` error

**Solutions:**
1. Verify container is running: `docker ps`
2. Check port mapping: `docker port remote-dev-env`
3. Verify SSH daemon: `docker exec remote-dev-env pgrep sshd`
4. Check logs: `docker logs remote-dev-env`
5. Verify firewall isn't blocking port 2222

### Permission Denied (publickey)

**Symptoms:** SSH rejects connection

**Solutions:**
1. Verify public key exists: `cat ssh-keys/authorized_keys`
2. Check file permissions: `ls -la ssh-keys/`
3. Verify key match: `ssh-keygen -lf ~/.ssh/id_rsa.pub`
4. Use verbose mode: `ssh -vvv -p 2222 dev@localhost`
5. Check container logs for SSH errors

### GitHub CLI not authenticated

**Symptoms:** `gh` commands fail with auth error

**Solutions:**
1. Verify `GITHUB_TOKEN` in `.env` file
2. Check token hasn't expired
3. Ensure token has correct scopes (repo, read:org, gist)
4. Manually authenticate: `gh auth login` inside container

### Claude Code authentication failed

**Symptoms:** `claude` commands fail

**Solutions:**
1. Run `claude auth` inside container
2. Follow OAuth flow in browser
3. Ensure container has internet access
4. Check Anthropic service status

### Container exits immediately

**Symptoms:** Container starts then stops

**Solutions:**
1. Check exit code: `docker inspect remote-dev-env --format='{{.State.ExitCode}}'`
2. View logs: `docker logs remote-dev-env`
3. Test entrypoint: `docker run --rm -it --entrypoint bash your-image`
4. Verify entrypoint.sh has execute permissions

### Runtimes not installing

**Symptoms:** Languages not available after first start

**Solutions:**
1. Check environment variables are set correctly
2. View entrypoint logs: `docker logs remote-dev-env`
3. Verify volume mounts for apt-cache and apt-lib
4. Check internet connectivity from container
5. Try manual installation to see error messages

## Advanced Configuration

### Custom SSH Port

Edit `docker-compose.yml`:

```yaml
ports:
  - "3333:22"  # Use port 3333 instead
```

### Resource Limits

Edit `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

### Additional Runtimes

Add to `entrypoint.sh` before Phase 2:

```bash
# Install Go if requested
if [ "$INSTALL_GO" = "true" ] && ! command -v go &> /dev/null; then
    echo "Installing Go..."
    # Add installation commands
fi
```

## Project Structure

```
vibe-container/
├── Dockerfile           # Primary: Container image definition
├── entrypoint.sh        # Runtime configuration and installation
├── docker-compose.yml   # Optional: Local testing
├── .dockerignore        # Exclude files from build
├── .gitignore          # Exclude sensitive files from git
├── .env.example        # Environment variable template
├── README.md           # This file
└── ssh-keys/
    └── authorized_keys # Your SSH public key (not in git)
```

## Contributing

This is a personal project, but suggestions and improvements are welcome!

## License

This project is provided as-is for use in your own infrastructure.

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review container logs: `docker logs remote-dev-env`
3. Test with verbose SSH: `ssh -vvv -p 2222 dev@localhost`
4. Verify all prerequisites are met
