一键实现gost的最基础功能，小白友好款！！！

# GOST 一键管理脚本

<p align="center">
  <img src="https://img.shields.io/badge/version-1.0.0-blue.svg" alt="version">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="license">
  <img src="https://img.shields.io/badge/platform-linux-lightgrey.svg" alt="platform">
</p>

<p align="center">
  一个简单易用的 GOST 代理服务管理脚本，支持一键安装、配置和管理。
</p>

---

## ✨ 功能特性

- 🚀 **一键安装** - 自动下载安装 GOST，无需手动配置
- 🔄 **双模式支持** - 落地鸡(SS服务端) / 中转鸡(端口转发)
- 📝 **交互式配置** - 引导式输入，支持默认值
- 🛠️ **便捷管理** - 启动/停止/重启/状态/日志一键操作
- ⚙️ **配置修改** - 随时修改端口、密码等参数
- 🗑️ **完整卸载** - 一键清理所有相关文件
- 🎨 **美观界面** - 彩色输出，状态一目了然

---

## 📦 一键安装

```bash
bash <(curl -sL https://raw.githubusercontent.com/shuang-wanna123/gost-manager/main/gost.sh)
```

或者：

```bash
wget -O gost.sh https://raw.githubusercontent.com/shuang-wanna123/gost-manager/main/gost.sh && chmod +x gost.sh && ./gost.sh
```

---

## 🖥️ 使用方法

### 交互式菜单

安装后直接运行：

```bash
gost
```

将显示管理菜单：

```
  ██████╗  ██████╗ ███████╗████████╗
 ██╔════╝ ██╔═══██╗██╔════╝╚══██╔══╝
 ██║  ███╗██║   ██║███████╗   ██║ 
 ██║   ██║██║   ██║╚════██║   ██║ 
 ╚██████╔╝╚██████╔╝███████║   ██║ 
  ╚═════╝  ╚═════╝ ╚══════╝   ╚═╝ 

      GOST 一键管理脚本 v1.0

  当前状态: ● 运行中

==================== 菜单 ====================

  1. 安装 - 落地鸡 (SS服务端)
  2. 安装 - 中转鸡 (端口转发)

  3. 查看状态
  4. 修改配置
  5. 查看日志

  6. 启动服务
  7. 停止服务
  8. 重启服务

  9. 卸载 GOST

  0. 退出

===============================================
```

### 快捷命令

```bash
gost              # 打开管理菜单
gost status       # 查看运行状态
gost start        # 启动服务
gost stop         # 停止服务
gost restart      # 重启服务
gost log          # 查看实时日志
gost uninstall    # 卸载 GOST
```

---

## 🔧 部署架构

```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│              │      │              │      │              │
│    客户端    │ ──── │    中转鸡    │ ──── │    落地鸡    │
│   (v2rayN)   │      │  (端口转发)  │      │  (SS服务端)  │
│              │      │              │      │              │
└──────────────┘      └──────────────┘      └──────────────┘
                           :51520     ────►    :8443
```

### 落地鸡配置

落地鸡运行 Shadowsocks 服务端：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 端口 | 8443 | SS 监听端口 |
| 加密 | chacha20-ietf-poly1305 | 加密方式 |
| 密码 | Qwert1470 | 连接密码 |

### 中转鸡配置

中转鸡负责端口转发：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| 本地端口 | 51520 | 本地监听端口 |
| 落地鸡IP | - | 必填 |
| 落地鸡端口 | 8443 | 转发目标端口 |

---

## 📱 客户端配置 (v2rayN)

| 配置项 | 填写内容 |
|--------|----------|
| 地址 | 中转鸡IP |
| 端口 | 51520 (中转鸡监听端口) |
| 密码 | Qwert1470 |
| 加密 | chacha20-ietf-poly1305 |

---

## 📁 文件说明

| 路径 | 说明 |
|------|------|
| `/usr/local/bin/gost` | GOST 可执行文件 |
| `/usr/local/bin/gost-manager` | 管理脚本 |
| `/etc/systemd/system/gost.service` | Systemd 服务文件 |
| `/etc/gost/config.json` | 配置信息 |

---

## ❓ 常见问题

### 1. 端口被占用怎么办？

脚本会自动检测并清理端口占用，如仍有问题：

```bash
# 查看端口占用
ss -tlnp | grep 51520

# 手动清理
fuser -k 51520/tcp
```

### 2. 如何查看运行日志？

```bash
# 实时日志
journalctl -u gost -f

# 最近50条日志
journalctl -u gost -n 50
```

### 3. 开机自启动？

脚本已自动配置 systemd 开机自启，无需额外设置。

### 4. 如何更新 GOST 版本？

```bash
# 卸载后重装
gost uninstall
gost
```

---

## 🔗 相关链接

- [GOST 官方仓库](https://github.com/ginuerzh/gost)
- [GOST 官方文档](https://gost.run/)

---

## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。

---

## ⭐ Star History

如果这个项目对你有帮助，请给个 Star ⭐ 支持一下！

---

## 🙏 致谢

- [ginuerzh/gost](https://github.com/ginuerzh/gost) - GOST 代理工具
