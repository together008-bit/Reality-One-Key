# Xray Reality One-Click Script

轻量、精简、安全的 Xray Reality 一键安装脚本。  
仅使用 Xray 官方 Core，不包含任何后门、订阅系统、面板组件或第三方魔改内容。

---

# Features

- 基于 Xray 官方 Core
- VLESS + REALITY + Vision
- 自动开启 BBR
- TCP Fast Open 优化
- TCP NoDelay 优化
- KeepAlive 优化
- 极简依赖
- 无数据库
- 无面板
- 无额外服务
- 无后门
- 无 telemetry
- 支持：
  - 安装
  - 更新 Xray Core
  - 重启服务
  - 查看配置
  - 查看分享链接
  - 完整卸载

---

# Why This Script

很多一键脚本：

- 集成大量无用组件
- 包含复杂面板
- 修改系统过多
- 依赖庞大
- 来源不透明

本项目目标：

> 只做一件事：  
> 提供一个干净、稳定、性能优化的 Reality 节点。

---

# Security

本脚本：

- 仅下载 Xray 官方 Release
- 不上传任何数据
- 不连接第三方 API
- 不包含订阅系统
- 不包含用户追踪
- 不包含后门

Xray 下载来源：

- https://github.com/XTLS/Xray-core

---

# Performance Optimization

已内置：

## BBR

自动开启：

```bash
net.ipv4.tcp_congestion_control=bbr
```

---

## TCP Fast Open

降低首次连接 RTT。

---

## TCP NoDelay

降低小包延迟。

---

## TCP KeepAlive

提升移动网络稳定性。

---

## Vision Flow

使用：

```text
xtls-rprx-vision
```

获得更好的性能与伪装效果。

---

# Install

## One Command Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/together008-bit/Reality-One-Key/main/install.sh)
```

---

# Menu

```text
1. Install Xray
2. Update Xray Core
3. Restart Xray
4. Show Config
5. Show VLESS Link
6. Uninstall Xray
0. Exit
```

---

# Default Configuration

| Item | Value |
|---|---|
| Protocol | VLESS |
| Transport | TCP |
| TLS | REALITY |
| Flow | xtls-rprx-vision |
| Port | 443 |
| TCP Fast Open | Enabled |
| BBR | Enabled |
| Mux | Disabled |

---

# Recommended Client Settings

## Enable

- TCP Fast Open
- UDP Relay

## Disable

- Mux
- Allow Insecure
- Fragment

---

# Supported Systems

- Ubuntu 20+
- Ubuntu 22+
- Debian 11+
- Debian 12+

---

# Uninstall

脚本菜单：

```text
6. Uninstall Xray
```

将完整删除：

- Xray Core
- Config
- Systemd Service
- Performance Config
- Temporary Files

---

# Disclaimer

本项目仅供：

- 学习
- 研究
- 网络技术测试

请遵守当地法律法规。

---

# Credits

- Xray Core Official Project  
  https://github.com/XTLS/Xray-core

- XTLS Official Documentation  
  https://xtls.github.io/
