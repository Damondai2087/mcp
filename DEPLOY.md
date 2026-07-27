# JumpServer MCP Server 部署指南

部署目标：Linux 服务器，Docker 方式。所有代码/过滤/修复已在本仓库（master 最新 commit）。

## 前置条件（服务器上）

- Docker 已安装并可运行：`docker info` 能输出即可。
  未安装：`curl -fsSL https://get.docker.com | sh && systemctl enable --now docker`
- git 已安装（用于拉源码）。
- 服务器能访问 JumpServer `https://192.168.100.113`。
- 服务器开放 8099 端口（给 MCP 客户端用）。

## 部署步骤

### 1. 拉取部署脚本

```bash
# 方式 A：直接 clone 整个仓库（推荐，脚本和源码一起拿）
git clone https://github.com/Damondai2087/mcp.git jms-mcp
cd jms-mcp

# 方式 B：只下脚本（脚本会自己 clone 源码）
curl -fsSL -o deploy-jms-mcp.sh https://raw.githubusercontent.com/Damondai2087/mcp/master/deploy-jms-mcp.sh
chmod +x deploy-jms-mcp.sh
```

### 2. 确认配置（脚本顶部，已预填）

`deploy-jms-mcp.sh` 顶部变量已填好当前环境的值：
```bash
JMP_URL="https://192.168.100.113"
JMP_TOKEN="StaXSIur17xfMGt61gPKROmUpGcjm9M6r6we"   # W0268 管理员长效 token
MCP_API_KEY=""                                       # 留空 = 客户端无需额外鉴权
PORT=8099
```
如需改动直接编辑脚本。`include_tags` 在脚本生成的 `.env` 里（ops + 资产查询，约 197 个工具）。

### 3. 一键部署

```bash
bash deploy-jms-mcp.sh
```

脚本会自动：检查 Docker → clone/更新源码 → 生成 `.env` → `docker build` → `docker run -d -p 8099:8099 --restart unless-stopped` → 打印启动日志。

### 4. 验证

```bash
# 启动日志应出现：Loaded N tools / Filtered to N tools / MCP server listening at /sse
docker logs -f jms_mcp

# 本机测 SSE 端点（应返回 text/event-stream + endpoint 事件，不是 401/500）
curl -i -N -H "Authorization: Bearer StaXSIur17xfMGt61gPKROmUpGcjm9M6r6we" http://127.0.0.1:8099/sse
```

### 5. 配置 MCP 客户端

> 重要：服务会把**客户端的 Bearer 转发**给 JumpServer，所以 header 里的 Bearer 必须是 JumpServer token（不是别的 key）。

```json
{
  "type": "sse",
  "url": "http://<服务器IP>:8099/sse",
  "headers": {
    "Authorization": "Bearer StaXSIur17xfMGt61gPKROmUpGcjm9M6r6we"
  }
}
```

## 运维命令

```bash
docker logs -f jms_mcp                 # 实时日志
docker restart jms_mcp                 # 重启（改了 .env 后）
docker stop jms_mcp && docker rm jms_mcp   # 停止并删除
# 重新部署（拉最新代码 + 重建）：
cd jms-mcp && git pull && bash deploy-jms-mcp.sh
```

## 调整暴露的工具

编辑服务器上 `jms-mcp/.env` 的 `include_tags`（逗号分隔的 swagger tag），改完 `docker restart jms_mcp` 即可，**不用重建镜像**。
- 当前默认：`ops_*`（作业执行）+ `assets_*`/`accounts_*`（资产搜索）。
- 全量 tag 列表见 JumpServer swagger；管理员 token 下 swagger 暴露约 1010 个操作。
- 另有手写工具 `list_assets_all`（全量资产列表，swagger 未暴露该端点）。

## 注意事项

- **token 权限**：当前用 `W0268` 管理员账号的 token，能调全部暴露的工具。若换低权限账号，部分工具会返回 403。
- **token 时效**：JumpServer 的 DRF session token 长期有效，不会自动过期；除非在 JumpServer UI 重新生成。重新生成后需更新 `.env` 的 `api_token` 和客户端 header 的 Bearer。
- **MCP 客户端 Bearer**：必须等于 `.env` 里的 `api_token`（即 JumpServer token），服务会转发它调用 JumpServer API。
