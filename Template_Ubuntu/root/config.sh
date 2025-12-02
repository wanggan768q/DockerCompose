#!/bin/bash

export http_proxy=http://host.docker.internal:${VPN_PORT}
export https_proxy=http://host.docker.internal:${VPN_PORT}
export all_proxy=http://host.docker.internal:${VPN_PORT}

rsync -av /data/host_ssh/ /root/.ssh --exclude=ssh-proxy-wrapper.sh
dos2unix /root/.ssh/ssh-proxy-wrapper.sh
chmod 600 /root/.ssh/* 2>/dev/null || true
#chmod 700 /root/.ssh 2>/dev/null || true
chmod +x ~/.ssh/ssh-proxy-wrapper.sh

# 调试信息：显示环境变量值
echo "DEBUG: HOST_IP = ${HOST_IP}"
echo "DEBUG: VPN_PORT = ${VPN_PORT}"
echo "DEBUG: PROXY_ADDR will be: ${HOST_IP}:${VPN_PORT}"

cd /data/Git/DockerComposeGit
git status
echo "Configuration completed."
bash