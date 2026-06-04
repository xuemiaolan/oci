#!/bin/bash
set -e

echo "==> Installing Docker CE on RHEL ..."

# Remove conflicting packages if present
for pkg in \
  docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine \
  podman \
  podman-docker \
  buildah \
  containerd \
  runc
do
  sudo dnf remove -y "$pkg" || true
done

# Install required tools
sudo dnf install -y dnf-plugins-core ca-certificates curl jq

# Add Docker official RHEL repo
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# Install Docker Engine and plugins
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
sudo systemctl enable --now docker

# Add current user to docker group
sudo usermod -aG docker "$USER"

echo "==> Installing OCI CLI Docker image..."

# Use sudo docker now, because current shell may not have refreshed docker group membership yet
sudo docker pull ghcr.io/oracle/oci-cli:latest
sudo docker tag ghcr.io/oracle/oci-cli:latest oci

# Create OCI config directory
mkdir -p "$HOME/.oci"
chmod 700 "$HOME/.oci"

# Add OCI alias to ~/.bashrc
if ! grep -q "alias oci=" "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'EOF'

# OCI CLI via Docker
alias oci='docker run --rm -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True -v "$HOME/.oci:/oracle/.oci" oci'
EOF
fi

echo "==> Setup complete!"
echo
echo "IMPORTANT:"
echo "1. Log out and log back in, or run: newgrp docker"
echo "2. Copy your OCI config file and private key into: $HOME/.oci/"
echo "3. Example files:"
echo "   $HOME/.oci/config"
echo "   $HOME/.oci/oci_api_key.pem"
echo
echo "After re-login or newgrp docker, test with:"
echo "  docker run --rm oci --version"
echo "  oci --version"
