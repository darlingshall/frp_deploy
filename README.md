# FRP 内外网穿透部署 SOP
## 1. 概述
### 1.1 目的
通过FRP实现内网Ktouch设备（Linux ARM）的远程访问和管理。

### 1.2 架构说明
服务端：Windows Server 2025 std服务器（公网IP: X.X.X.X）

客户端：Linux ARM嵌入式设备（内网）

通信端口：9527

### 1.3 实现功能
内网设备Web服务穿透（端口8083 → 5XXXX）

SSH远程访问（通过stcp加密隧道）

## 2. 准备工作
### 2.1 软件下载
从GitHub下载对应版本：

服务端（Windows）：frps.exe

客户端（Linux ARM）：frpc

下载地址：https://github.com/darlingshall/frp_deploy

### 2.2 需要的文件清单

| 位置 | 文件 | 说明 |
| :--- | :--- | :--- |
| 服务端 | `frps.exe` | FRP服务端程序 |
| 服务端 | `frps.toml` | 服务端配置文件 |
| 客户端 | `frpc` | FRP客户端程序 |
| 客户端 | `frpc.toml` | 客户端配置文件 |
| 客户端 | `check_frpc.sh` | 健康检查脚本 |
## 3. 服务端部署（Windows）
[> 📌 **Linux用户请参考**：`Install_Frp_Server_In_Ubuntu.md`](Install_Frp_Server_In_Ubuntu.md)

### 3.1 目录结构
```text
D:\frps\
├── frps.exe          # 主程序
├── frps.toml         # 配置文件
├── log.frps          # 日志文件（自动生成）
├── frpc.exe          # 服务器上的客户端主程序（用来作为visitor远程访问客户端）
└── frpc.toml         # 客户端配置文件（供frpc主程序使用）

```

### 3.2 配置文件 frps.toml
```toml
bindPort = 9527
allowPorts = [
    { start = 50000, end = 65000 }
]

webserver.addr = "0.0.0.0"
webserver.port = 9999
webserver.user = "Demo"
webserver.password = "admin@Demo"

log.to = "log.frps"
log.level = "info"
log.maxDays = 30

transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 120

auth.method = "token"
auth.token = "admin@Demo"
```
### 3.3 启动服务端
方法一：命令行启动

```cmd
cd D:\frps
frps.exe -c frps.toml
```
方法二：创建启动脚本 start.bat

```batch
@echo off
cd /d D:\frps
start /b frps.exe -c frps.toml
echo FRPS已启动
pause
```
### 3.4 验证服务端运行
打开浏览器访问：http://47.106.134.141:9999

输入用户名：Demo，密码：admin@Demo

能看到Dashboard界面即表示成功

### 3.5 设置开机自启动
下载NSSM到frps目录
https://nssm.cc/download

```cmd
cd D:\frps

# 安装服务
nssm install "frp server" D:\frps\frps.exe

# 设置启动参数
nssm set "frp server" AppParameters -c D:\frps\frps.toml

# 设置启动目录
nssm set "frp server" AppDirectory D:\frps

# 设置自动重启（崩溃后5秒重启）
nssm set "frp server" AppExit Default Restart
nssm set "frp server" AppThrottle 5000
```
或者也可以一键安装
```cmd
cd D:\frps
nssm install "frp server" "D:\frps\frps.exe" -c "D:\frps\frps.toml"
```
## 4. 客户端部署（Linux ARM）
4.1 目录结构
```text
/opt/frpc/
├── frpc              # 主程序
├── frpc.toml         # 配置文件
├── check_frpc.sh     # 健康检查脚本
└── /var/log/
    └── frpc.log      # 日志文件
```
### 4.2 创建目录并上传文件
```bash
# 创建目录
mkdir -p /opt/frpc

# 上传文件（在PC上操作，使用scp或U盘）
# 假设通过scp上传：
scp frpc root@设备IP:/opt/frpc/
scp frpc.toml root@设备IP:/opt/frpc/
scp check_frpc.sh root@设备IP:/opt/frpc/

# 给执行权限
chmod +x /opt/frpc/frpc
chmod +x /opt/frpc/check_frpc.sh
```
### 4.3 配置文件 frpc.toml
```toml
serverAddr = "服务器IP"
serverPort = 9527

log.to = "/var/log/frpc.log"
log.level = "info"
log.maxDays = 5

webserver.addr = "0.0.0.0"
webserver.port = 9580

auth.method = "token"
auth.token = "admin@Demo"

# 设备序列号（自动获取，参考4.6节）


transport.tcpMux = true
transport.tcpMuxKeepaliveInterval = 120

# 穿透Web服务（端口8083 → 50021）
[[proxies]]
name = "wnet"
type = "tcp"
localIP = "127.0.0.1"
localPort = 8083
remotePort = 50021

# SSH加密隧道
[[proxies]]
name = "secret_tcp"
type = "stcp"
secretKey = "P@ssw0rd"
localIP = "127.0.0.1"
localPort = 22
allowUsers = ["*"]
```
### 4.4 健康检查脚本 check_frpc.sh
```bash
#!/bin/bash
# 检查frpc是否运行，如果没有则启动

CONF_PATH="/opt/frpc/frpc.toml"

# 检查进程是否存在
if ! pgrep -x "frpc" > /dev/null; then
    echo "[$(date)] FRPC未运行，正在启动..." >> /var/log/frpc.log
    nohup /opt/frpc/frpc -c "$CONF_PATH" >> /var/log/frpc.log 2>&1 &
fi
```

### 4.5 设置定时监控
```bash
# 编辑crontab
crontab -e

# 添加以下行（每5分钟检查一次）
*/5 * * * * /opt/frpc/check_frpc.sh
```
### 4.6 设置开机自启动
```bash
# 编辑rc.local
vi /etc/rc.local

# 在 exit 0 前面添加：
/opt/frpc/check_frpc.sh
```

注意：设备序列号首次运行check_frpc.sh时会自动获取

自动获取序列号的配置方法（已包含在check_frpc.sh代码中）：

```bash
if ! grep -q "^user =" "$CONF_PATH"; then
    if [ -f "$PARAM_FILE" ]; then
        SERIAL=$(grep '<Serial>' "$PARAM_FILE" | awk -F'[][]' '{print $2}')
        if [ -n "$SERIAL" ]; then
            # 在 token 下方自动插入 user 字段
            sed -i "/auth.token =/a \\\nuser = \"${SERIAL}\"" "$CONF_PATH"
            NEED_RESTART=1
        fi
    fi
fi
```
### 4.7 手动启动测试
```bash
# 前台运行（测试用）
/opt/frpc/frpc -c /opt/frpc/frpc.toml

# 后台运行
nohup /opt/frpc/frpc -c "$CONF_PATH" >> /var/log/frpc.log 2>&1 &
```
### 4.8 验证客户端运行
```bash
# 查看进程
ps aux | grep frpc

# 查看日志
tail -f /var/log/frpc.log

# 查看连接状态
netstat -tnp | grep frpc
```
## 5. 功能验证
### 5.1 Web服务穿透测试
在客户端设备上确认Web服务运行在端口8083

外部访问：http://服务器IP:客户端远程端口号

应能访问到内网设备的Web界面

## 5.2 SSH隧道测试
配置文件
```toml
serverAddr = "127.0.0.1"
serverPort = 9527

auth.method = "token"
auth.token = "admin@Demo"

[[visitors]]                                # 注意这里的代理名称
name = "SSH.secret_tcp"                     # 可以自定义，但多个[[visitors]]代理时不能重复
type = "stcp"
serverName = "K03-8644T1-xxxxxx.secret_tcp" # 必须和远端设备配置的名称一致
secretKey = "xxxxxxxx"
bindAddr = "127.0.0.1"
bindPort = xx22                             # 服务器上监听的端口，ssh localhost:xx22
```
```bash
# 通过stcp隧道连接（需要FRP客户端支持）
./frpc -c frpc.toml

# 或使用nc测试
ssh -p xx22 -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAcceptedAlgorithms=+ssh-rsa user@serverIP
```
5.3 客户端Web管理
访问客户端管理界面：http://设备IP:9580

## 6. 常见问题排查
### 6.1 连接失败
```bash
# 1. 检查服务器防火墙是否开放9527端口
# 2. 检查客户端网络是否能访问服务器
ping 47.106.134.141

# 3. 查看客户端日志
tail -n 50 /var/log/frpc.log
```
### 6.2 权限问题
```bash
# 给程序执行权限
chmod +x /opt/frpc/frpc
chmod +x /opt/frpc/check_frpc.sh
```
### 6.3 端口占用
```bash
# 检查端口是否被占用
netstat -tlnp | grep 9527
netstat -tlnp | grep 9580
```
### 6.4 查看系统日志
```bash
# 查看系统日志
dmesg | tail -n 20
# 查看cron日志
grep frpc /var/log/syslog
```
## 7. 维护操作
### 7.1 重启FRPC
```bash
# 停止
pkill -x frpc

# 启动
nohup /opt/frpc/frpc -c /opt/frpc/frpc.toml > /var/log/frpc.log 2>&1 &
```
### 7.2 更新客户端程序
```bash
# 1. 停止旧程序
pkill -x frpc

# 2. 备份旧程序
mv /opt/frpc/frpc /opt/frpc/frpc.bak

# 3. 上传新程序
# 使用scp或其他方式上传

# 4. 赋予权限并启动
chmod +x /opt/frpc/frpc
/opt/frpc/check_frpc.sh
```
### 7.3 查看运行状态
```bash
# 进程状态
ps aux | grep frpc

# 连接状态
netstat -tnp | grep frpc

# 最近日志
tail -n 20 /var/log/frpc.log
```
## 8. 附录
### 8.1 文件清单核对表
- 服务端：frps.exe 已上传
- 服务端：frps.toml 配置正确
- 服务端：防火墙开放端口 9527、50000-65000
- 客户端：frpc 已上传并赋予执行权限
- 客户端：frpc.toml 配置正确
- 客户端：check_frpc.sh 已上传并赋予执行权限
- 客户端：cron定时任务已设置
- 客户端：开机自启动已设置
- 功能验证：Web穿透正常
- 功能验证：SSH隧道正常
### 8.2 端口规划

| 端口    | 用途 | 位置 |
|:------| :--- | :--- |
| 9527  | FRP主连接端口 | 服务端 |
| 9999  | FRP Web管理界面 | 服务端 |
| 500xx | Web服务穿透端口 | 服务端 |
| 9580  | FRPC Web管理界面 | 客户端 |
| 8083  | 本地Web服务 | 客户端 |
| 22    | SSH服务 | 客户端 |
### 8.3
文档版本：V1.0
最后更新：2026-08-24