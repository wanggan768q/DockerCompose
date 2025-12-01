#!/bin/bash

# 获取当前操作系统/环境信息
OS=$(uname -s)

# SOCKS代理地址和端口，保持与您Windows配置中的一致
PROXY_ADDR="${HOST_IP}:${VPN_PORT}"
echo "INFO: PROXY_ADDR: $PROXY_ADDR" >&2
HOST=$1
PORT=$2

echo "INFO: Detecting OS: $OS" >&2 # 打印调试信息到stderr

if [[ $OS == "Linux" ]]; then
    # --- Ubuntu/WSL/Linux 环境 ---
    echo "INFO: Running 'nc' command for Linux." >&2
    /usr/bin/nc -X 5 -x $PROXY_ADDR $HOST $PORT
    
elif [[ $OS == *"MINGW"* ]] || [[ $OS == *"MSYS"* ]] || [[ $OS == *"CYGWIN"* ]]; then
    # --- Windows/Git Bash 环境 ---
    echo "INFO: Running 'connect.exe' command for Windows." >&2
    
    CONNECT_PATH="/c/Git/mingw64/bin/connect.exe"
    
    "$CONNECT_PATH" -S $PROXY_ADDR $HOST $PORT
    
else
    echo "ERROR: Unknown OS/Environment ($OS). Proxy command failed." >&2
    exit 1
fi