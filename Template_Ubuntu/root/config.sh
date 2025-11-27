#!/bin/bash

export http_proxy=http://host.docker.internal:${VPN_PORT}
export https_proxy=http://host.docker.internal:${VPN_PORT}
export all_proxy=http://host.docker.internal:${VPN_PORT}

cp  /etc/apt/sources.list.d/ubuntu.sources   /etc/apt/sources.list.d/ubuntu.sources.bak

# 替换为清华源
echo "Types: deb
URIs: http://mirrors.tuna.tsinghua.edu.cn/ubuntu
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" > /etc/apt/sources.list.d/ubuntu.sources

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y iputils-ping vim tzdata git curl netcat-openbsd openssh-server

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

git config --global http.proxy socks5://host.docker.internal:7890
git config --global https.proxy socks5://host.docker.internal:7890
git config --global user.email "test@test.com"
git config --global user.name "Ambition"

mkdir -p /root/.ssh
cp -r /data/host_ssh/* /root/.ssh/ 2>/dev/null || true
# 复制 Template_Ubuntu 目录下的文件到对应位置
#cp -rf /data/Template_Ubuntu/root/* /root/ 2>/dev/null || true
# 1. 显式覆盖文件，不保留原目录结构
cp -fv /data/Template_Ubuntu/root/.ssh/config /root/.ssh/config
chmod 600 /root/.ssh/* 2>/dev/null || true
chmod 700 /root/.ssh 2>/dev/null || true

cd /data/Git/DockerComposeGit
git push
echo "Configuration completed."
bash