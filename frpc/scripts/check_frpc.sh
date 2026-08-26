#!/bin/bash

CONF_PATH="/opt/frpc/frpc.toml"
PARAM_FILE="/opt/KolbOven/bin/txt/parameter.txt"
LOG_FILE="/var/log/frpc_check.log"
FLAG_FILE="/tmp/frpc_temp_file"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# 0. 首次启动等待网络（标志文件不存在时）
if [ ! -f "$FLAG_FILE" ]; then
    log "首次启动，等待网络连接..."

    # 自动获取网卡名称
    NET_IF=$(ip route | grep default | awk '{print $5}')

    # 先 ping 一次，不通则重启网卡
    if ! ping -c 1 -W 1 47.106.134.141 >/dev/null 2>&1; then
        log "网络不通，尝试重启网卡: $NET_IF"
        ifdown "$NET_IF" 2>/dev/null
        sleep 2
        ifup "$NET_IF" 2>/dev/null
        sleep 3
    fi

    for i in $(seq 1 60); do
        if ping -c 1 -W 1 47.106.134.141 >/dev/null 2>&1; then
            log "网络已连通（耗时 ${i} 秒）"
            touch "$FLAG_FILE"
            NETWORK_READY=1
            break
        fi
        if [ $i -eq 60 ]; then
            log "网络等待超时（60秒），继续尝试启动..."
            touch "$FLAG_FILE"
        fi
        sleep 1
    done
fi

# 1. 如果配置文件里还没有配置 user，则动态写入
if ! grep -q "^user =" "$CONF_PATH"; then
    if [ -f "$PARAM_FILE" ]; then
        SERIAL=$(grep '<Serial>' "$PARAM_FILE" | awk -F'[][]' '{print $2}')
        if [ -n "$SERIAL" ]; then
            sed -i "/auth.token =/a \\\nuser = \"${SERIAL}\"" "$CONF_PATH"
            NEED_RESTART=1
        fi
    fi
fi

# 2. 常规健康检查与守护
PID=$(pgrep -x "frpc")
NEED_RESTART=0

if [ -z "$PID" ]; then
    log "frpc进程不存在"
    NEED_RESTART=1
else
    CONN_COUNT=$(netstat -tnp 2>/dev/null | grep 'frpc' | grep -E 'ESTABLISHED|SYN_SENT' | wc -l)
    if [ "$CONN_COUNT" -eq 0 ]; then
        log "frpc进程存在但无活跃连接"
        NEED_RESTART=1
    fi
fi

# 3. 如果需要重启
if [ "$NEED_RESTART" -eq 1 ]; then
    log "正在重启frpc..."
    pkill -x frpc 2> /dev/null
    sleep 2
    pkill -9 -x frpc 2>/dev/null
    sleep 1
    nohup /opt/frpc/frpc -c "$CONF_PATH" >> /var/log/frpc.log 2>&1 &
    log "frpc已重启"
fi