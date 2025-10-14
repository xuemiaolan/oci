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

# -------------------------------
# 3️⃣ 配置 OCI 环境变量
# -------------------------------
echo "==> Configuring OCI environment variables..."

COMPARTMENT_ID=$(curl -sf http://169.254.169.254/opc/v1/instance/ | jq -r .compartmentId)
TENANT_ID=$(curl -sf http://169.254.169.254/opc/v1/instance/ | jq -r .tenantId)

echo "export C=$COMPARTMENT_ID" >> ~/.bashrc
echo "export T=$TENANT_ID" >> ~/.bashrc

source ~/.bashrc

# 获取 OCI 用户 ID
USER_ID=$(oci iam user list --all | jq -r '.data[].id')
echo "export U=$USER_ID" >> ~/.bashrc
source ~/.bashrc

# 可用域
AVAILABLE_DOMAIN=$(oci iam availability-domain list -c $C | jq -r '.data[].name')
echo "export AD=$AVAILABLE_DOMAIN" >> ~/.bashrc

# 子网
SUBNET_ID=$(oci network subnet list -c $C | jq -r '.data[].id')
echo "export SI=$SUBNET_ID" >> ~/.bashrc

source ~/.bashrc

# 安全列表
SECURITY_LIST=$(oci network subnet get --subnet-id $SI | jq -r '.data["security-list-ids"][]')
echo "export SL=$SECURITY_LIST" >> ~/.bashrc

source ~/.bashrc

mkdir -p ~/.oci

echo "⚠️ IMPORTANT: Please copy your OCI config file, private key, and the cloud instance's public key to the ~/.oci/ directory."
echo "==> Setup complete! Please open a new terminal or run 'source ~/.bashrc' to start using the OCI CLI."
