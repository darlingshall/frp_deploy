# 📝 Ubuntu服务端部署手册（独立文档）

# FRP 服务端部署手册（Ubuntu）

## 1. 概述

本文档说明如何在Ubuntu服务器上部署FRP服务端。

### 1.1 适用环境

| 项目 | 说明                           |
|------|------------------------------|
| 操作系统 | Ubuntu 18.04 / 20.04 / 22.04 |
| 架构 | x86_64 (amd64)               |
| 公网IP | X.X.X.X                      |

### 1.2 与其他平台的关系

本手册与Windows服务端部署手册实现相同功能，请根据实际服务器操作系统选择参考。

[> 📌 **Windows用户请参考**：`FRP服务端部署手册（Windows）.md`](README.md)


---

## 2. 准备工作

### 2.1 软件下载

从GitHub下载ubuntu版本：
服务端（ubuntu）：frps

### 2.2 需要的文件
| 文件 | 说明 |
| :--- | :--- |
| frps	| FRP服务端主程序 |
| frps.toml	| 配置文件|
## 3. 部署步骤
### 3.1 创建目录
```bash
sudo mkdir -p /opt/frps
```
### 3.2 上传文件
方法一：使用scp（从本地PC上传）

```bash
# 在本地PC执行（将文件上传到服务器）
scp frps root@X.X.X.X:/opt/frps/
scp frps.toml root@X.X.X.X:/opt/frps/
```
方法二：直接在服务器操作（如果已解压）

```bash
# 复制文件到目标目录
sudo cp frps /opt/frps/
sudo cp frps.toml /opt/frps/
```
### 3.3 设置执行权限
```bash
sudo chmod +x /opt/frps/frps
```
### 3.4 配置文件 frps.toml
创建 /opt/frps/frps.toml：

```toml
# 服务端配置
bindPort = 9527
allowPorts = [
    { start = 50000, end = 50100 }
]

# Web管理界面
webserver.addr = "0.0.0.0"
webserver.port = 9999
webserver.user = "Demo"
webserver.password = "admin@Demo"

# 日志配置
log.to = "/opt/frps/frps.log"
log.level = "info"
log.maxDays = 30

# 传输配置
transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 120

# 认证配置
auth.method = "token"
auth.token = "admin@Demo"
```
### 3.5 目录结构确认
```text
/opt/frps/
├── frps              # 主程序（可执行文件）
├── frps.toml         # 配置文件
└── frps.log          # 日志文件（自动生成）
```
## 4. 启动与测试
### 4.1 手动启动测试
```bash
# 前台运行（用于测试，Ctrl+C停止）
cd /opt/frps
./frps -c frps.toml

# 后台运行（测试用）
nohup /opt/frps/frps -c /opt/frps/frps.toml > /opt/frps/frps.log 2>&1 &
```
### 4.2 验证服务端运行
打开浏览器访问：http://X.X.X.X:9999

输入用户名：Demo，密码：admin@Demo

看到Dashboard界面即表示成功

### 4.3 防火墙配置
```bash
# 开放端口
sudo ufw allow 9527/tcp
sudo ufw allow 9999/tcp
sudo ufw allow 50000:50100/tcp

# 查看防火墙状态
sudo ufw status
```
注意：如果使用云服务器（如阿里云、腾讯云），还需要在安全组中开放上述端口。

## 5. 开机自启动配置
### 5.1 使用 systemd（推荐）
创建服务文件
创建 /etc/systemd/system/frps.service：

```bash
sudo vim /etc/systemd/system/frps.service
```
写入以下内容：

```ini
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/frps
ExecStart=/opt/frps/frps -c /opt/frps/frps.toml
Restart=always
RestartSec=10
StandardOutput=append:/opt/frps/frps.log
StandardError=append:/opt/frps/frps.log

[Install]
WantedBy=multi-user.target
```
启动并启用服务
```bash
# 重新加载systemd配置
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start frps

# 设置开机自启
sudo systemctl enable frps

# 查看运行状态
sudo systemctl status frps
```
### 5.2 使用 rc.local（备选方案）
```bash
# 编辑 rc.local
sudo vi /etc/rc.local

# 在 exit 0 前面添加：
/opt/frps/frps -c /opt/frps/frps.toml > /opt/frps/frps.log 2>&1 &
```
## 6. 日常管理命令
### 6.1 systemd 管理（推荐）
| 操作 | 命令 |
| :--- | :--- |
| 启动 | `sudo systemctl start frps` |
| 停止 | `sudo systemctl stop frps` |
| 重启 | `sudo systemctl restart frps` |
| 查看状态 | `sudo systemctl status frps` |
| 查看日志 | `sudo journalctl -u frps -f` |
| 禁用开机自启 | `sudo systemctl disable frps` |


### 6.2 进程管理
| 操作 | 命令 |
| :--- | :--- |
| 查看进程 | `ps aux \| grep frps` |
| 终止进程 | `pkill -x frps` |
| 查看日志 | `tail -f /opt/frps/frps.log` |
| 查看端口 | `netstat -tlnp \| grep frps` |


## 7. 故障排查
### 7.1 常见问题
端口被占用
```bash
# 查看端口占用
sudo netstat -tlnp | grep 9527

# 结束占用进程
sudo kill -9 PID
```
权限不足
```bash
# 添加执行权限
sudo chmod +x /opt/frps/frps

# 检查文件所有者
ls -l /opt/frps/
```
防火墙未开放
```bash
# 查看防火墙规则
sudo ufw status verbose

# 临时关闭防火墙测试（生产环境不建议）
sudo ufw disable
```
### 7.2 查看日志
```bash
# 查看服务日志
sudo journalctl -u frps -n 50

# 查看程序日志
tail -n 50 /opt/frps/frps.log
```
## 8. 更新与维护
8.1 更新FRP版本
```bash
# 1. 停止服务
sudo systemctl stop frps

# 2. 备份旧程序
sudo mv /opt/frps/frps /opt/frps/frps.bak

# 3. 上传新版本
# （参考3.2节的上传方法）

# 4. 设置权限并启动
sudo chmod +x /opt/frps/frps
sudo systemctl start frps
sudo systemctl status frps
```
## 8.2 健康检查脚本（可选）
创建 /opt/frps/check_frps.sh：

```bash
#!/bin/bash
# 检查frps是否运行，如果没有则启动

if ! pgrep -x "frps" > /dev/null; then
    echo "[$(date)] FRPS未运行，正在启动..." >> /opt/frps/frps.log
    nohup /opt/frps/frps -c /opt/frps/frps.toml >> /opt/frps/frps.log 2>&1 &
fi
赋予权限并添加定时任务：

bash
chmod +x /opt/frps/check_frps.sh
crontab -e
# 添加：*/5 * * * * /opt/frps/check_frps.sh
```
9. 检查清单
- frps 已上传到 /opt/frps/ 并赋予执行权限
- frps.toml 配置正确
- 防火墙已开放端口：9527、9999、50000-50100
- 云服务器安全组已开放上述端口
- 手动启动测试通过
- Web管理界面可正常访问（http://47.106.134.141:9999）
- systemd服务已配置并启用
- 服务端日志正常输出