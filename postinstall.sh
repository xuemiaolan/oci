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


echo "==> Setup complete! Please open a new terminal or run 'source ~/.bashrc' to start using the OCI CLI."
