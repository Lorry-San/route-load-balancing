
# 拼好线 - Multi-Line Load Balancer

<div align="center">

[![GitHub release](https://img.shields.io/github/release/Lorry-San/route-load-balancing.svg)](https://github.com/Lorry-San/route-load-balancing/releases)
[![License](https://img.shields.io/github/license/Lorry-San/route-load-balancing.svg)](LICENSE)
[![Python Version](https://img.shields.io/badge/python-3.6+-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Unix-lightgrey.svg)]()

[English](#english) | [中文](#chinese)

一个强大的多线路负载均衡器，支持TCP和UDP协议，支持大小包分流

A powerful multi-line load balancer supporting TCP/UDP protocols , support large and small packet splitting

</div>

---

<a name="chinese"></a>
## 🇨🇳 中文文档

### 📖 简介

**拼好线**是一个轻量级但功能强大的多线路负载均衡器，专为需要同时管理多条网络线路的场景设计。支持TCP和UDP协议，可同时管理最多6条线路，实现智能流量分发。

### ✨ 核心特性

- 🚀 **多线路支持**: 支持2-6条线路同时运行
- 🔄 **双协议**: 同时支持TCP和UDP转发
- ⚡ **智能分流**: 
  - 自动轮询模式（默认）- 平均分配流量
  - 按包大小分流模式 - 小包走主线路，大包轮询
- 🎯 **主线路指定**: 可自定义单线程默认线路
- 🌙 **后台运行**: 支持守护进程模式，无需screen/tmux
- 📊 **实时统计**: 自动记录流量分配情况，每分钟输出统计
- 📝 **日志轮转**: 自动管理日志文件（10MB轮转，保留5个文件）
- 🛠️ **进程管理**: 启动/停止/状态查询一键完成
- 🔒 **会话保持**: UDP会话自动保持一致性
- 💪 **高性能**: 多线程并发处理，支持大量并发连接

### 🔧 系统要求

- Python 3.6+
- Linux/Unix 系统（Ubuntu、Debian、CentOS、RHEL等）
- root权限（用于后台运行和日志写入，也可使用普通用户）

### 📦 一键安装

#### 方法1: 使用一键安装脚本（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/Lorry-San/route-load-balancing/main/install.sh | sudo bash
```

#### 方法2: 手动安装

```bash
# 下载主程序
wget https://raw.githubusercontent.com/Lorry-San/route-load-balancing/main/bs2.py

# 添加执行权限
chmod +x bs2.py

# 移动到系统路径（需要root权限）
sudo mv bs2.py /usr/local/bin/bs2

# 或者不使用root，添加到用户bin目录
mkdir -p ~/bin
mv bs2.py ~/bin/bs2
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 🚀 快速开始

#### 1. 基础使用（2线路）

```bash
# 前台运行 - 适合测试
bs2 -l 40001 -t 40002 40003

# 后台运行 - 适合生产环境
bs2 -l 40001 -t 40002 40003 -d
```

#### 2. 3线路配置

```bash
bs2 -l 40001 -t 40002 40003 40004 -d
```

#### 3. 6线路最大配置

```bash
bs2 -l 40001 -t 40002 40003 40004 40005 40006 40007 -d
```

#### 4. 指定主线路

```bash
# 从第2条线路开始轮询（单线程第一个请求走第2条线）
bs2 -l 40001 -t 40002 40003 40004 --primary 2 -d
```

#### 5. 不同主机配置

```bash
# 3条不同服务器的线路
bs2 -l 40001 \
  -t 192.168.1.10:40002 \
     192.168.1.11:40003 \
     192.168.1.12:40004 \
  -d
```

### 📋 完整参数说明

| 参数 | 说明 | 默认值 | 示例 |
|------|------|--------|------|
| `-l, --listen-port` | 监听端口 | 必需 | `-l 40001` |
| `-t, --targets` | 目标列表（2-6个） | 必需 | `-t 40002 40003` |
| `-p, --protocol` | 协议类型 | both | `-p tcp` |
| `-m, --mode` | 分流模式 | auto | `-m size` |
| `-s, --size` | 小包阈值（字节） | 1024 | `-s 2048` |
| `-H, --host` | 监听地址 | 0.0.0.0 | `-H 127.0.0.1` |
| `--target-host` | 目标主机 | 127.0.0.1 | `--target-host 192.168.1.1` |
| `--primary` | 主线路编号（1-6） | 1 | `--primary 2` |
| `-d, --daemon` | 后台运行 | 否 | `-d` |
| `--log-file` | 日志文件路径 | auto | `--log-file /tmp/lb.log` |
| `--stop` | 停止服务 | - | `--stop -l 40001` |
| `--status` | 查看状态 | - | `--status -l 40001` |
| `-v, --version` | 查看版本 | - | `-v` |

### 🎮 进程管理

```bash
# 查看运行状态
bs2 --status -l 40001

# 停止服务
bs2 --stop -l 40001

# 查看实时日志
tail -f /var/log/loadbalancer_40001.log

# 查看最近100行日志
tail -n 100 /var/log/loadbalancer_40001.log

# 搜索错误日志
grep ERROR /var/log/loadbalancer_40001.log
```

### 🌟 使用场景

#### 场景1: 游戏服务器负载均衡（3条线路）
```bash
# 3条不同运营商线路，玩家连接自动分配
bs2 -l 25565 \
  -t game1.example.com:25565 \
     game2.example.com:25565 \
     game3.example.com:25565 \
  --primary 1 -d
```

#### 场景2: 代理服务器池（6条线路）
```bash
# 6条代理线路轮询，最大化利用带宽
bs2 -l 1080 \
  -t proxy1.com:1080 \
     proxy2.com:1080 \
     proxy3.com:1080 \
     proxy4.com:1080 \
     proxy5.com:1080 \
     proxy6.com:1080 \
  -d
```

#### 场景3: DNS负载均衡（UDP）
```bash
# 3条DNS服务器，提高查询速度和可用性
bs2 -l 53 \
  -t 8.8.8.8:53 \
     1.1.1.1:53 \
     223.5.5.5:53 \
  -p udp -d
```

#### 场景4: Web服务器负载均衡（按包大小分流）
```bash
# 小请求(<1KB)走高速线路，大请求轮询所有线路
bs2 -l 8080 \
  -t high-speed.com:8080 \
     normal1.com:8080 \
     normal2.com:8080 \
  -m size -s 1024 --primary 1 -d
```

#### 场景5: 视频流媒体分发
```bash
# 4条CDN线路负载均衡
bs2 -l 1935 \
  -t cdn1.example.com:1935 \
     cdn2.example.com:1935 \
     cdn3.example.com:1935 \
     cdn4.example.com:1935 \
  --primary 1 -p tcp -d
```

### 📊 统计信息示例

```
============================================================
负载均衡统计 [模式:auto] - 2025-01-20 18:35:00
============================================================

TCP协议:
  总连接/包数: 3000
  目标1 ('192.168.1.10', 40002): 1000 (33.3%)
  目标2 ('192.168.1.11', 40003): 1000 (33.3%) [主线路]
  目标3 ('192.168.1.12', 40004): 1000 (33.3%)

UDP协议:
  总连接/包数: 1500
  目标1 ('192.168.1.10', 40002): 500 (33.3%)
  目标2 ('192.168.1.11', 40003): 500 (33.3%) [主线路]
  目标3 ('192.168.1.12', 40004): 500 (33.3%)

UDP活跃会话: 45
============================================================
```

### 🔍 故障排查

#### 问题1: 权限不足无法写入日志

```bash
# 方法1: 修改日志目录权限
sudo chown -R $USER:$USER /var/log/

# 方法2: 使用自定义日志路径
bs2 -l 40001 -t 40002 40003 -d --log-file ~/loadbalancer.log

# 方法3: 使用临时目录
bs2 -l 40001 -t 40002 40003 -d --log-file /tmp/loadbalancer.log
```

#### 问题2: 端口已被占用

```bash
# 检查端口占用
sudo netstat -tlnp | grep 40001
sudo lsof -i :40001

# 杀死占用进程
sudo kill -9 <PID>

# 或者选择其他端口
bs2 -l 40002 -t 40003 40004 -d
```

#### 问题3: 服务无法启动

```bash
# 检查防火墙
sudo ufw status
sudo ufw allow 40001

# 临时关闭防火墙测试
sudo ufw disable

# CentOS/RHEL 检查 SELinux
sudo setenforce 0

# 检查系统日志
sudo journalctl -xe
```

#### 问题4: 连接无法转发

```bash
# 测试目标服务器是否可达
telnet 192.168.1.10 40002
nc -vz 192.168.1.10 40002

# 检查路由
traceroute 192.168.1.10

# 查看详细日志
tail -f /var/log/loadbalancer_40001.log
```

### 🐛 常见问题 FAQ

**Q: 如何实现开机自启动？**

A: 使用systemd服务（见下方systemd配置章节）

**Q: 支持IPv6吗？**

A: 当前版本仅支持IPv4，IPv6支持计划在v2.0版本中加入

**Q: 最多支持多少并发连接？**

A: 理论上无限制，实际受系统资源限制（可通过`ulimit -n`查看和调整）

**Q: 可以动态添加或删除线路吗？**

A: 当前需要重启服务，动态配置功能在开发路线图中

**Q: UDP会话超时时间可以调整吗？**

A: 当前默认60秒，暂不支持配置，计划在后续版本中添加

**Q: 如何监控负载均衡器性能？**

A: 可通过日志查看统计信息，或配合Prometheus等监控工具（集成功能开发中）

**Q: 单个目标服务器down了会怎样？**

A: 当前版本会记录错误日志，后续版本会添加健康检查和自动剔除功能

**Q: 支持加权轮询吗？**

A: 当前不支持，计划在v1.5版本中添加

### ⚙️ Systemd服务配置

创建文件 `/etc/systemd/system/loadbalancer@.service`:

```ini
[Unit]
Description=PinHaoXian Load Balancer on port %i
After=network.target
Documentation=https://github.com/Lorry-San/route-load-balancing

[Service]
Type=forking
User=root
Group=root
ExecStart=/usr/local/bin/bs2 -l %i -t 40002 40003 40004 -d
ExecStop=/usr/local/bin/bs2 --stop -l %i
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/tmp/loadbalancer_%i.pid
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# 安全加固
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

#### 使用方法：

```bash
# 重载systemd配置
sudo systemctl daemon-reload

# 启动服务（端口40001）
sudo systemctl start loadbalancer@40001

# 停止服务
sudo systemctl stop loadbalancer@40001

# 重启服务
sudo systemctl restart loadbalancer@40001

# 开机自启
sudo systemctl enable loadbalancer@40001

# 禁用开机自启
sudo systemctl disable loadbalancer@40001

# 查看状态
sudo systemctl status loadbalancer@40001

# 查看服务日志
sudo journalctl -u loadbalancer@40001 -f

# 查看最近100行日志
sudo journalctl -u loadbalancer@40001 -n 100
```

#### 多端口配置：

```bash
# 启动多个实例
sudo systemctl start loadbalancer@40001
sudo systemctl start loadbalancer@50001
sudo systemctl start loadbalancer@60001

# 全部开机自启
sudo systemctl enable loadbalancer@40001
sudo systemctl enable loadbalancer@50001
sudo systemctl enable loadbalancer@60001
```

### 🔧 高级配置

#### 调整系统限制

```bash
# 增加文件描述符限制
sudo vim /etc/security/limits.conf

# 添加以下行
* soft nofile 65535
* hard nofile 65535

# 立即生效
ulimit -n 65535

# 永久生效（需要重新登录）
```

#### 优化网络参数

```bash
sudo vim /etc/sysctl.conf

# 添加以下配置
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# 应用配置
sudo sysctl -p
```

### 🎯 性能优化建议

1. **使用SSD存储**: 日志文件建议存放在SSD上
2. **关闭不需要的协议**: 如只需TCP，使用`-p tcp`
3. **调整包大小阈值**: 根据实际情况调整`-s`参数
4. **使用专用服务器**: 不要与其他重负载服务共享
5. **监控系统资源**: 定期检查CPU、内存、网络使用情况

### 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

### 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 📞 联系方式

- Issues: [GitHub Issues](https://github.com/Lorry-San/route-load-balancing/issues)
- Discussions: [GitHub Discussions](https://github.com/Lorry-San/route-load-balancing/discussions)
- Author: Lorry-San

### 🗺️ 开发路线图

- [x] v1.0: 基础负载均衡功能
- [ ] v1.1: 健康检查和自动故障转移
- [ ] v1.2: Web管理界面
- [ ] v1.3: API接口
- [ ] v1.4: 性能监控和Prometheus集成
- [ ] v1.5: 加权轮询支持
- [ ] v2.0: IPv6支持
- [ ] v2.1: 配置文件支持
- [ ] v2.2: 热重载配置

### 🙏 致谢

感谢所有贡献者和用户的支持！

---

<a name="english"></a>
## 🇬🇧 English Documentation

### 📖 Introduction

**PinHaoXian** (Multi-Line Load Balancer) is a lightweight yet powerful load balancer designed for scenarios requiring simultaneous management of multiple network lines. It supports TCP and UDP protocols and can manage up to 6 lines simultaneously for intelligent traffic distribution.

### ✨ Core Features

- 🚀 **Multi-Line Support**: Supports 2-6 lines simultaneously
- 🔄 **Dual Protocol**: Supports both TCP and UDP forwarding
- ⚡ **Smart Distribution**: 
  - Auto round-robin mode (default) - evenly distributes traffic
  - Size-based distribution mode - small packets to primary line, large packets round-robin
- 🎯 **Primary Line**: Customizable default line for single-thread scenarios
- 🌙 **Background Mode**: Daemon process support, no need for screen/tmux
- 📊 **Real-time Stats**: Automatic traffic distribution recording with minute-by-minute statistics
- 📝 **Log Rotation**: Automatic log file management (10MB rotation, keeps 5 files)
- 🛠️ **Process Management**: One-command start/stop/status query
- 🔒 **Session Persistence**: Automatic UDP session consistency
- 💪 **High Performance**: Multi-threaded concurrent processing, supports massive concurrent connections

### 🔧 System Requirements

- Python 3.6+
- Linux/Unix system (Ubuntu, Debian, CentOS, RHEL, etc.)
- Root privileges (for daemon mode and log writing, can also run as regular user)

### 📦 Quick Installation

#### Method 1: One-Click Install Script (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Lorry-San/route-load-balancing/main/install.sh | sudo bash
```

#### Method 2: Manual Installation

```bash
# Download main program
wget https://raw.githubusercontent.com/Lorry-San/route-load-balancing/main/bs2.py

# Add execute permission
chmod +x bs2.py

# Move to system path (requires root)
sudo mv bs2.py /usr/local/bin/bs2

# Or without root, add to user bin directory
mkdir -p ~/bin
mv bs2.py ~/bin/bs2
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 🚀 Quick Start

#### 1. Basic Usage (2 Lines)

```bash
# Foreground - suitable for testing
bs2 -l 40001 -t 40002 40003

# Background - suitable for production
bs2 -l 40001 -t 40002 40003 -d
```

#### 2. 3-Line Configuration

```bash
bs2 -l 40001 -t 40002 40003 40004 -d
```

#### 3. Maximum 6-Line Configuration

```bash
bs2 -l 40001 -t 40002 40003 40004 40005 40006 40007 -d
```

#### 4. Specify Primary Line

```bash
# Start round-robin from line 2 (first request in single-thread goes to line 2)
bs2 -l 40001 -t 40002 40003 40004 --primary 2 -d
```

#### 5. Different Hosts Configuration

```bash
# 3 lines from different servers
bs2 -l 40001 \
  -t 192.168.1.10:40002 \
     192.168.1.11:40003 \
     192.168.1.12:40004 \
  -d
```

### 📋 Complete Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `-l, --listen-port` | Listen port | Required | `-l 40001` |
| `-t, --targets` | Target list (2-6) | Required | `-t 40002 40003` |
| `-p, --protocol` | Protocol type | both | `-p tcp` |
| `-m, --mode` | Distribution mode | auto | `-m size` |
| `-s, --size` | Small packet threshold (bytes) | 1024 | `-s 2048` |
| `-H, --host` | Listen address | 0.0.0.0 | `-H 127.0.0.1` |
| `--target-host` | Target host | 127.0.0.1 | `--target-host 192.168.1.1` |
| `--primary` | Primary line (1-6) | 1 | `--primary 2` |
| `-d, --daemon` | Background mode | No | `-d` |
| `--log-file` | Log file path | auto | `--log-file /tmp/lb.log` |
| `--stop` | Stop service | - | `--stop -l 40001` |
| `--status` | Show status | - | `--status -l 40001` |
| `-v, --version` | Show version | - | `-v` |

### 🎮 Process Management

```bash
# Check status
bs2 --status -l 40001

# Stop service
bs2 --stop -l 40001

# View real-time logs
tail -f /var/log/loadbalancer_40001.log

# View last 100 lines
tail -n 100 /var/log/loadbalancer_40001.log

# Search error logs
grep ERROR /var/log/loadbalancer_40001.log
```

### 🌟 Use Cases

#### Case 1: Game Server Load Balancing (3 Lines)
```bash
# 3 different ISP lines, player connections auto-distributed
bs2 -l 25565 \
  -t game1.example.com:25565 \
     game2.example.com:25565 \
     game3.example.com:25565 \
  --primary 1 -d
```

#### Case 2: Proxy Server Pool (6 Lines)
```bash
# 6 proxy lines round-robin, maximize bandwidth utilization
bs2 -l 1080 \
  -t proxy1.com:1080 \
     proxy2.com:1080 \
     proxy3.com:1080 \
     proxy4.com:1080 \
     proxy5.com:1080 \
     proxy6.com:1080 \
  -d
```

#### Case 3: DNS Load Balancing (UDP)
```bash
# 3 DNS servers, improve query speed and availability
bs2 -l 53 \
  -t 8.8.8.8:53 \
     1.1.1.1:53 \
     223.5.5.5:53 \
  -p udp -d
```

#### Case 4: Web Server Load Balancing (Size-based)
```bash
# Small requests(<1KB) to high-speed line, large requests round-robin
bs2 -l 8080 \
  -t high-speed.com:8080 \
     normal1.com:8080 \
     normal2.com:8080 \
  -m size -s 1024 --primary 1 -d
```

#### Case 5: Video Streaming Distribution
```bash
# 4 CDN lines load balancing
bs2 -l 1935 \
  -t cdn1.example.com:1935 \
     cdn2.example.com:1935 \
     cdn3.example.com:1935 \
     cdn4.example.com:1935 \
  --primary 1 -p tcp -d
```

### 📊 Statistics Example

```
============================================================
Load Balancer Stats [mode:auto] - 2025-01-20 18:35:00
============================================================

TCP Protocol:
  Total connections/packets: 3000
  Target1 ('192.168.1.10', 40002): 1000 (33.3%)
  Target2 ('192.168.1.11', 40003): 1000 (33.3%) [PRIMARY]
  Target3 ('192.168.1.12', 40004): 1000 (33.3%)

UDP Protocol:
  Total connections/packets: 1500
  Target1 ('192.168.1.10', 40002): 500 (33.3%)
  Target2 ('192.168.1.11', 40003): 500 (33.3%) [PRIMARY]
  Target3 ('192.168.1.12', 40004): 500 (33.3%)

UDP Active Sessions: 45
============================================================
```

### 🔍 Troubleshooting

#### Issue 1: Permission denied for log writing

```bash
# Method 1: Change log directory permissions
sudo chown -R $USER:$USER /var/log/

# Method 2: Use custom log path
bs2 -l 40001 -t 40002 40003 -d --log-file ~/loadbalancer.log

# Method 3: Use temp directory
bs2 -l 40001 -t 40002 40003 -d --log-file /tmp/loadbalancer.log
```

#### Issue 2: Port already in use

```bash
# Check port usage
sudo netstat -tlnp | grep 40001
sudo lsof -i :40001

# Kill process
sudo kill -9 <PID>

# Or choose another port
bs2 -l 40002 -t 40003 40004 -d
```

#### Issue 3: Service won't start

```bash
# Check firewall
sudo ufw status
sudo ufw allow 40001

# Temporarily disable firewall for testing
sudo ufw disable

# CentOS/RHEL check SELinux
sudo setenforce 0

# Check system logs
sudo journalctl -xe
```

#### Issue 4: Connection forwarding fails

```bash
# Test if target server is reachable
telnet 192.168.1.10 40002
nc -vz 192.168.1.10 40002

# Check routing
traceroute 192.168.1.10

# View detailed logs
tail -f /var/log/loadbalancer_40001.log
```

### 🐛 FAQ

**Q: How to enable auto-start on boot?**

A: Use systemd service (see systemd configuration section below)

**Q: Does it support IPv6?**

A: Current version supports IPv4 only, IPv6 support is planned for v2.0

**Q: What's the maximum concurrent connections?**

A: Theoretically unlimited, practically limited by system resources (check/adjust with `ulimit -n`)

**Q: Can I dynamically add or remove lines?**

A: Currently requires service restart, dynamic configuration is on the roadmap

**Q: Can UDP session timeout be adjusted?**

A: Currently fixed at 60 seconds, configuration option planned for future versions

**Q: How to monitor load balancer performance?**

A: View statistics in logs, or integrate with Prometheus (integration feature in development)

**Q: What happens if a target server goes down?**

A: Current version logs errors, health check and automatic removal planned for future versions

**Q: Does it support weighted round-robin?**

A: Not currently, planned for v1.5

### ⚙️ Systemd Service Configuration

Create file `/etc/systemd/system/loadbalancer@.service`:

```ini
[Unit]
Description=PinHaoXian Load Balancer on port %i
After=network.target
Documentation=https://github.com/Lorry-San/route-load-balancing

[Service]
Type=forking
User=root
Group=root
ExecStart=/usr/local/bin/bs2 -l %i -t 40002 40003 40004 -d
ExecStop=/usr/local/bin/bs2 --stop -l %i
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/tmp/loadbalancer_%i.pid
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

#### Usage:

```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Start service (port 40001)
sudo systemctl start loadbalancer@40001

# Stop service
sudo systemctl stop loadbalancer@40001

# Restart service
sudo systemctl restart loadbalancer@40001

# Enable auto-start
sudo systemctl enable loadbalancer@40001

# Disable auto-start
sudo systemctl disable loadbalancer@40001

# Check status
sudo systemctl status loadbalancer@40001

# View service logs
sudo journalctl -u loadbalancer@40001 -f

# View last 100 lines
sudo journalctl -u loadbalancer@40001 -n 100
```

#### Multiple Ports:

```bash
# Start multiple instances
sudo systemctl start loadbalancer@40001
sudo systemctl start loadbalancer@50001
sudo systemctl start loadbalancer@60001

# Enable all for auto-start
sudo systemctl enable loadbalancer@40001
sudo systemctl enable loadbalancer@50001
sudo systemctl enable loadbalancer@60001
```

### 🔧 Advanced Configuration

#### Adjust System Limits

```bash
# Increase file descriptor limit
sudo vim /etc/security/limits.conf

# Add these lines
* soft nofile 65535
* hard nofile 65535

# Apply immediately
ulimit -n 65535

# Permanent (requires re-login)
```

#### Optimize Network Parameters

```bash
sudo vim /etc/sysctl.conf

# Add these configurations
net.core.somaxconn = 32768
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30

# Apply configuration
sudo sysctl -p
```

### 🎯 Performance Optimization Tips

1. **Use SSD Storage**: Store log files on SSD
2. **Disable Unused Protocols**: Use `-p tcp` if only TCP is needed
3. **Adjust Packet Size Threshold**: Tune `-s` parameter based on actual traffic
4. **Use Dedicated Server**: Don't share with other heavy-load services
5. **Monitor System Resources**: Regularly check CPU, memory, network usage

### 📄 License

MIT License - see [LICENSE](LICENSE) file for details

### 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### 📞 Contact

- Issues: [GitHub Issues](https://github.com/Lorry-San/route-load-balancing/issues)
- Discussions: [GitHub Discussions](https://github.com/Lorry-San/route-load-balancing/discussions)
- Author: Lorry-San

### 🗺️ Roadmap

- [x] v1.0: Basic load balancing functionality
- [ ] v1.1: Health checks and automatic failover
- [ ] v1.2: Web management interface
- [ ] v1.3: API interface
- [ ] v1.4: Performance monitoring and Prometheus integration
- [ ] v1.5: Weighted round-robin support
- [ ] v2.0: IPv6 support
- [ ] v2.1: Configuration file support
- [ ] v2.2: Hot reload configuration

### 🙏 Acknowledgments

Thanks to all contributors and users for their support!

---

<div align="center">

Made with ❤️ by [Lorry-San](https://github.com/Lorry-San)

[⬆ Back to top](#top)

</div>
```

由于README太长,我将继续提供安装脚本...
