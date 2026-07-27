#!/usr/bin/env bash
# JumpServer MCP Server - Linux 部署脚本
# 用法: bash deploy-jms-mcp.sh
set -euo pipefail

# ====== 配置区（按需修改）======
JMP_URL="https://192.168.100.113"
JMP_TOKEN="StaXSIur17xfMGt61gPKROmUpGcjm9M6r6we"
# 给 MCP 客户端用的 Bearer key（留空 = 不校验客户端；生产建议设值）
MCP_API_KEY=""
PORT=8099
CONTAINER_NAME="jms_mcp"
IMAGE_NAME="jms-mcp:latest"
# ==============================

REPO_URL="https://github.com/Damondai2087/mcp.git"
WORK_DIR="jms-mcp"

echo "[1/6] 检查 Docker..."
command -v docker >/dev/null 2>&1 || { echo "未安装 Docker，先装: curl -fsSL https://get.docker.com | sh"; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker daemon 未运行: systemctl start docker"; exit 1; }

echo "[2/6] 拉取源码..."
if [ -d "$WORK_DIR/.git" ]; then
  echo "  目录已存在，git pull..."
  cd "$WORK_DIR" && git pull --ff-only
else
  git clone "$REPO_URL" "$WORK_DIR"
  cd "$WORK_DIR"
fi

echo "[3/6] 生成 .env..."
cat > .env <<EOF
jumpserver_url=${JMP_URL}
api_token=${JMP_TOKEN}
api_key=${MCP_API_KEY}
server_port=${PORT}
base_path=/sse
log_level=INFO
debug=false

# Tool filtering: comma-separated OpenAPI tags. Only set one of include/exclude.
# Default exposes only 作业执行 (ops) capabilities. Edit to widen/narrow.
include_tags=ops_adhocs,ops_ansible,ops_celery,ops_job-execution,ops_job-executions,ops_jobs,ops_playbook,ops_playbooks,ops_task-executions,ops_username-hints,ops_variables
exclude_tags=
EOF
chmod 600 .env

echo "[4/6] 构建镜像..."
docker build -t "$IMAGE_NAME" .

echo "[5/6] 启动/重建容器..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${PORT}:8099" \
  --env-file .env \
  --restart unless-stopped \
  "$IMAGE_NAME"

echo "[6/6] 启动日志（Ctrl+C 退出查看，容器继续后台运行）..."
sleep 3
docker logs --tail 50 "$CONTAINER_NAME"

echo ""
echo "========================================="
echo "部署完成"
echo "  MCP SSE 端点: http://<服务器IP>:${PORT}/sse"
if [ -n "$MCP_API_KEY" ]; then
  echo "  客户端需带 Header: Authorization: Bearer ${MCP_API_KEY}"
else
  echo "  api_key 为空，客户端无需鉴权"
fi
echo "  查看日志: docker logs -f ${CONTAINER_NAME}"
echo "  重启:     docker restart ${CONTAINER_NAME}"
echo "========================================="
