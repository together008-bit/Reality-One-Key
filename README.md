# Reality-One-Key

一个适用于个人使用的 Xray 一键安装脚本。

本项目基于官方 Xray Core，自动部署：

- VLESS + REALITY
- Vision Flow
- BBR 加速
- systemd 服务管理

无需：

- 域名
- SSL 证书
- nginx
- 面板
- Docker

适用于：

- Debian
- Ubuntu

---

# 功能特性

- 自动安装官方最新版 Xray
- 自动开启 BBR
- 自动生成 UUID
- 自动生成 Reality 密钥
- 自动生成 shortId
- 自动生成 VLESS 分享链接
- 自动创建 systemd 服务
- 支持 x86_64 / ARM64
- 仅使用官方 GitHub Release

---

# 支持系统

- Debian 11 / 12
- Ubuntu 20.04 / 22.04 / 24.04

---

# 一键安装

执行以下命令：

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/together008-bit/Reality-One-Key/main/install.sh)"
```

安装过程中会询问：

- 监听端口
- Reality SNI

安装完成后会自动输出：

- Server IP
- Port
- UUID
- Public Key
- shortId
- VLESS 分享链接

---

# 手动安装方式

```bash
# 下载脚本
curl -o install.sh https://raw.githubusercontent.com/together008-bit/Reality-One-Key/main/install.sh

# 添加执行权限
chmod +x install.sh

# 运行安装
sudo bash install.sh
```

---

# systemd 管理

查看状态：

```bash
systemctl status xray
```

重启：

```bash
systemctl restart xray
```

停止：

```bash
systemctl stop xray
```

开机自启：

```bash
systemctl enable xray
```

---

# 配置文件位置

```bash
/usr/local/etc/xray/config.json
```

---

# Reality 默认配置

默认：

```text
SNI:
www.cloudflare.com
```

支持自定义。

---

# 卸载 Xray

后续将提供：

```bash
uninstall.sh
```

---

# 项目目标

本项目仅用于：

- 个人使用
- 学习研究
- 极简部署

不支持：

- 多用户
- 面板
- VMess
- Trojan
- Clash
- sing-box
- Docker
- nginx

保持：

- 简洁
- 透明
- 可维护
- 官方化

---

# 安全说明

本项目：

- 仅从官方 Xray Release 下载程序
- 不使用第三方编译 Core
- 不包含后门
- 不修改 routing
- 不植入 DNS 配置

Xray 官方项目：

https://github.com/XTLS/Xray-core

---

# 免责声明

请遵守当地法律法规。

本项目仅供学习与技术研究使用。
