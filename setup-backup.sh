#!/usr/bin/env bash
# 在 VPS 上一次性配置备份环境：安装 rclone、配置 R2、注册 cron
# 用法：bash setup-backup.sh

set -euo pipefail

SCRIPT_DIR="/root/baiye-scripts"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
LOG_FILE="/var/log/baiye-backup.log"
CRON_JOB="0 3 * * * $BACKUP_SCRIPT >> $LOG_FILE 2>&1"

# ── 1. 安装 rclone ───────────────────────────────────────────
if ! command -v rclone &>/dev/null; then
  echo "安装 rclone..."
  curl -fsSL https://rclone.org/install.sh | bash
else
  echo "rclone 已安装：$(rclone version | head -1)"
fi

# ── 2. 配置 R2（交互式） ─────────────────────────────────────
if ! rclone listremotes | grep -q "^r2:"; then
  echo ""
  echo "请输入 Cloudflare R2 凭证（在 CF Dashboard → R2 → Manage API Tokens 获取）"
  read -rp "Account ID: " CF_ACCOUNT_ID
  read -rp "Access Key ID: " R2_ACCESS_KEY
  read -rp "Secret Access Key: " R2_SECRET_KEY

  mkdir -p ~/.config/rclone
  cat >> ~/.config/rclone/rclone.conf <<EOF

[r2]
type = s3
provider = Cloudflare
access_key_id = $R2_ACCESS_KEY
secret_access_key = $R2_SECRET_KEY
endpoint = https://${CF_ACCOUNT_ID}.r2.cloudflarestorage.com
acl = private
EOF
  echo "rclone R2 配置完成"
else
  echo "rclone R2 已配置"
fi

# ── 3. 确保 baiye-backups bucket 存在 ───────────────────────
echo "检查 R2 bucket..."
rclone mkdir r2:baiye-backups 2>/dev/null || true
echo "bucket 就绪：r2:baiye-backups"

# ── 4. 确保脚本可执行 ────────────────────────────────────────
chmod +x "$BACKUP_SCRIPT"

# ── 5. 注册 cron（幂等） ─────────────────────────────────────
if crontab -l 2>/dev/null | grep -qF "$BACKUP_SCRIPT"; then
  echo "cron 已配置，跳过"
else
  (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
  echo "cron 已注册：每天 03:00 自动备份"
fi

# ── 6. 立即跑一次验证 ────────────────────────────────────────
echo ""
read -rp "立即执行一次备份验证？[y/N] " RUN_NOW
if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
  bash "$BACKUP_SCRIPT"
fi

echo ""
echo "配置完成。查看日志：tail -f $LOG_FILE"
