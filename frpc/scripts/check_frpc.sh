#!/bin/bash

CONF_PATH="/opt/frpc/frpc.toml"
PARAM_FILE="/opt/KolbOven/bin/txt/parameter.txt"

# 1. 如果配置文件里还没有配置 user，则动态写入
if ! grep -q "^user =" "$CONF_PATH"; then
    if [ -f "$PARAM_FILE" ]; then
        SERIAL=$(grep '<Serial>' "$PARAM_FILE" | awk -F'[][]' '{print $2}')
        if [ -n "$SERIAL" ]; then
            # 在 token 下方自动插入 user 字段
            sed -i "/auth.token =/a \\\nuser = \"${SERIAL}\"" "$CONF_PATH"
            pkill -x frpc # 重启让配置生效
        fi
    fi
fi

# 2. 常规健康检查与守护
# 先检查进程是不是根本不在
PID=$(pgrep -x "frpc")
NEED_RESTART=0

if [ -z "$PID" ]; then
    NEED_RESTART=1
else
    # 进程存在，检查它是否有对外建立的established连接（假设你的frps端口是你的frp连接端口，这里以检查是否有向外发起的TCP连接为例）
    # 或者用更简单可靠的方法：检查日志最后更新时间，或者直接结合你的实际情况
    # 如果 frpc 卡死，通常它与服务端的 TCP 链接会断开或变成 TIME_WAIT / CLOSE_WAIT
    # 这里我们检查系统里是否存在 frpc 相关的活跃 tcp 连接：
    ACTIVE_CONN=$(netstat -tnp 2>/dev/null | grep 'frpc' | grep -E 'ESTAB')
    
    if [ -z "$ACTIVE_CONN" ]; then
        # 进程虽然活着，但没有 ESTABLISHED 的连接，说明卡死或断连了
        NEED_RESTART=1
    fi
fi

# 如果需要重启
if [ "$NEED_RESTART" -eq 1 ]; then
    # 使用 -9 确保能杀掉卡住或处于等待状态的进程
    pkill -9 -x frpc 2>/dev/null
    sleep 1
    nohup /opt/frpc/frpc -c "$CONF_PATH" >> /var/log/frpc.log 2>&1 &
fi
