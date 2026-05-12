#!/usr/bin/env bash
# 白夜数据库备份：pg_dump → gzip → Cloudflare R2
# 用法：
#   手动：bash backup.sh
#   cron：0 3 * * * /root/baiye-scripts/backup.sh >> /var/log/baiye-backup.log 2>&1

set -euo pipefail

BACKUP_DIR="/tmp/baiye-backups"
RCLONE_REMOTE="r2:baiye-backups"
KEEP_DAYS=7

# ── 从 .env.prod 读取数据库配置 ────────────────────────────
ENV_FILE="/root/baiye/.env.prod"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "[ERROR] $ENV_FILE not found" >&2
  exit 1
fi

get_env() { grep "^$1=" "$ENV_FILE" | cut -d= -f2- | tr -d '"'; }

PGPASSWORD=$(get_env POSTGRES_PASSWORD)
PGUSER=$(get_env POSTGRES_USER)
PGDATABASE=$(get_env POSTGRES_DB)
PGHOST="127.0.0.1"
PGPORT="5432"

export PGPASSWORD

# ── 备份 ────────────────────────────────────────────────────
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILE="$BACKUP_DIR/baiye_${TIMESTAMP}.sql.gz"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始备份..."

pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" "$PGDATABASE" | gzip > "$FILE"

SIZE=$(du -sh "$FILE" | cut -f1)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份完成：$(basename "$FILE") ($SIZE)"

# ── 上传 R2 ─────────────────────────────────────────────────
if ! command -v rclone &>/dev/null; then
  echo "[ERROR] rclone 未安装，请先运行：curl https://rclone.org/install.sh | bash" >&2
  exit 1
fi

rclone copy "$FILE" "$RCLONE_REMOTE/" --s3-no-check-bucket
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 已上传至 $RCLONE_REMOTE/$(basename "$FILE")"

# ── 清理本地临时文件 ─────────────────────────────────────────
rm -f "$FILE"

# ── 清理 R2 中超过 N 天的旧备份 ──────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 清理 ${KEEP_DAYS} 天前的旧备份..."
rclone delete "$RCLONE_REMOTE/" \
  --min-age "${KEEP_DAYS}d" \
  --include "baiye_*.sql.gz"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 备份流程完成"
