#!/usr/bin/env bash
set -euo pipefail

# oci_pass_policy_update_and_reset.sh
#
# 用途:
#   1. 使用 Docker 方式 OCI CLI 修改 Identity Domain PasswordPolicy 的 password-expires-after
#   2. 生成所需 JSON 文件
#   3. 可选: 重置指定 USER_ID 的密码并发送重置邮件
#
# 前提:
#   export DOMAIN_URL=<identity_domain_url>
#   export USER_ID=<identity_domain_user_id>
#
# 可选:
#   export EXPIRE_DAYS=0              # 0 表示永不过期，120 表示 120 天，180 表示 180 天
#   export POLICY_ID=PasswordPolicy
#   export OCI_CONFIG_DIR=/home/ubuntu/.oci
#   export OCI_DOCKER_IMAGE=oci
#   export DO_RESET_PASSWORD=false    # true 时执行密码重置
#   export BYPASS_NOTIFICATION=false  # false 表示发送重置邮件，true 表示不发送通知
#
# 示例:
#   EXPIRE_DAYS=0 DO_RESET_PASSWORD=true ./oci_pass_policy_update_and_reset.sh

EXPIRE_DAYS="${EXPIRE_DAYS:-0}"
POLICY_ID="${POLICY_ID:-PasswordPolicy}"
OCI_CONFIG_DIR="${OCI_CONFIG_DIR:-/home/ubuntu/.oci}"
OCI_DOCKER_IMAGE="${OCI_DOCKER_IMAGE:-oci}"
DO_RESET_PASSWORD="${DO_RESET_PASSWORD:-false}"
BYPASS_NOTIFICATION="${BYPASS_NOTIFICATION:-false}"
WORKDIR="${WORKDIR:-$PWD}"

DOMAIN_URL="${DOMAIN_URL:-}"
USER_ID="${USER_ID:-}"

if [[ -z "$DOMAIN_URL" ]]; then
  echo "ERROR: DOMAIN_URL is empty."
  echo "Please run: export DOMAIN_URL=<identity_domain_url>"
  exit 1
fi

if [[ "$DO_RESET_PASSWORD" == "true" && -z "$USER_ID" ]]; then
  echo "ERROR: USER_ID is empty, but DO_RESET_PASSWORD=true."
  echo "Please run: export USER_ID=<identity_domain_user_id>"
  exit 1
fi

if [[ ! "$EXPIRE_DAYS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: EXPIRE_DAYS must be a number. Example: EXPIRE_DAYS=0"
  exit 1
fi

oci_docker() {
  docker run --rm \
    -e OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True \
    -v "${OCI_CONFIG_DIR}:/oracle/.oci" \
    -v "${WORKDIR}:/work" \
    -w /work \
    "${OCI_DOCKER_IMAGE}" "$@"
}

echo "============================================================"
echo "OCI Password Policy Update and User Password Reset"
echo "============================================================"
echo "DOMAIN_URL          = ${DOMAIN_URL}"
echo "POLICY_ID           = ${POLICY_ID}"
echo "EXPIRE_DAYS         = ${EXPIRE_DAYS}"
echo "OCI_CONFIG_DIR      = ${OCI_CONFIG_DIR}"
echo "OCI_DOCKER_IMAGE    = ${OCI_DOCKER_IMAGE}"
echo "DO_RESET_PASSWORD   = ${DO_RESET_PASSWORD}"
echo "BYPASS_NOTIFICATION = ${BYPASS_NOTIFICATION}"
if [[ -n "$USER_ID" ]]; then
  echo "USER_ID             = ${USER_ID}"
fi
echo

echo "[1/6] Generate JSON files..."

cat > password_policy_schemas.json <<'EOF'
[
  "urn:ietf:params:scim:api:messages:2.0:PatchOp"
]
EOF

cat > password_policy_operations.json <<EOF
[
  {
    "op": "replace",
    "path": "passwordExpiresAfter",
    "value": ${EXPIRE_DAYS}
  }
]
EOF

cat > reset_schemas.json <<'EOF'
[
  "urn:ietf:params:scim:schemas:oracle:idcs:UserPasswordResetter"
]
EOF

echo "Generated:"
echo "  ${WORKDIR}/password_policy_schemas.json"
echo "  ${WORKDIR}/password_policy_operations.json"
echo "  ${WORKDIR}/reset_schemas.json"
echo

echo "[2/6] Backup current password policy..."
BACKUP_FILE="PasswordPolicy.backup.$(date -u +%Y%m%dT%H%M%SZ).json"

oci_docker identity-domains password-policy get \
  --endpoint "$DOMAIN_URL" \
  --password-policy-id "$POLICY_ID" \
  --output json > "$BACKUP_FILE"

echo "Backup saved: ${WORKDIR}/${BACKUP_FILE}"
echo

echo "[3/6] Current password policy:"
oci_docker identity-domains password-policy get \
  --endpoint "$DOMAIN_URL" \
  --password-policy-id "$POLICY_ID" \
  --query 'data.{id:id,name:"display-name",passwordExpiresAfter:"password-expires-after",passwordExpireWarning:"password-expire-warning"}' \
  --output table

echo
echo "[4/6] Patch password policy..."
oci_docker identity-domains password-policy patch \
  --endpoint "$DOMAIN_URL" \
  --password-policy-id "$POLICY_ID" \
  --schemas file://password_policy_schemas.json \
  --operations file://password_policy_operations.json

echo
echo "[5/6] Verify password policy:"
oci_docker identity-domains password-policy get \
  --endpoint "$DOMAIN_URL" \
  --password-policy-id "$POLICY_ID" \
  --query 'data.{id:id,name:"display-name",passwordExpiresAfter:"password-expires-after",passwordExpireWarning:"password-expire-warning"}' \
  --output table

echo
if [[ "$DO_RESET_PASSWORD" == "true" ]]; then
  echo "[6/6] Reset user password..."
  echo "This will reset the password for USER_ID=${USER_ID}."
  echo "BYPASS_NOTIFICATION=${BYPASS_NOTIFICATION}"

  oci_docker identity-domains user-password-resetter put \
    --endpoint "$DOMAIN_URL" \
    --user-password-resetter-id "$USER_ID" \
    --schemas file://reset_schemas.json \
    --bypass-notification "$BYPASS_NOTIFICATION"

  echo
  echo "Password reset request submitted."
  if [[ "$BYPASS_NOTIFICATION" == "false" ]]; then
    echo "A reset notification email should be sent to the user."
  else
    echo "Notification was bypassed."
  fi
else
  echo "[6/6] Skip user password reset."
  echo "To reset user password as well, run:"
  echo "  DO_RESET_PASSWORD=true BYPASS_NOTIFICATION=false EXPIRE_DAYS=${EXPIRE_DAYS} ./oci_pass_policy_update_and_reset.sh"
fi

echo
echo "Completed."

