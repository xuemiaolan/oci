#!/bin/bash
set -e

# -------------------------------
# 1️⃣ 安装 Docker CE
# -------------------------------
echo "==> Installing Docker CE..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
  sudo apt-get remove -y $pkg || true
done

sudo apt-get update
sudo apt-get install -y ca-certificates curl jq
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
newgrp docker

# -------------------------------
# 2️⃣ 安装 OCI CLI Docker
# -------------------------------
echo "==> Installing OCI CLI Docker..."
docker pull ghcr.io/oracle/oci-cli:latest
docker tag ghcr.io/oracle/oci-cli:latest oci

# 添加 alias 到 bashrc
if ! grep -q "alias oci=" ~/.bashrc; then
  echo "alias oci='docker run --rm -it -e \"OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True\" -v \"$HOME/.oci:/oracle/.oci\" oci'" >> ~/.bashrc
fi
source ~/.bashrc

mkdir -p ~/.oci
echo 'export PATH=$PATH:~/oci' >> ~/.bashrc
echo "⚠️ IMPORTANT: Please copy your OCI config file, private key, and the cloud instance's public key to the ~/.oci/ directory."
echo "==> Setup complete! Please open a new terminal or run 'source ~/.bashrc' to start using the OCI CLI."
