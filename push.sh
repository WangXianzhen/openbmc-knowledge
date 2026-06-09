#!/bin/bash
# OpenBMC Knowledge 推送脚本

set -e

REPO_DIR="/home/simon/.claude/projects/-mnt-d-code-aspped-github/memory/openbmc-gitbook"
cd "$REPO_DIR"

echo "==============================================="
echo "🔧 OpenBMC Knowledge GitHub 推送脚本"
echo "==============================================="
echo ""

# 检查远程
if ! git remote get-url origin &>/dev/null; then
    echo "📡 添加远程仓库..."
    git remote add origin https://github.com/WangXianzhen/openbmc-knowledge.git
fi

# 检查 GitHub CLI
if command -v gh &>/dev/null; then
    echo "✅ GitHub CLI 已安装"

    # 检查是否已登录
    if gh auth status &>/dev/null; then
        echo "✅ 已登录 GitHub"
        echo "🚀 推送到 GitHub..."
        git push -u origin master
    else
        echo "⚠️ 请先登录 GitHub:"
        echo "   gh auth login"
        exit 1
    fi
else
    echo "⚠️ GitHub CLI 未安装"
    echo ""
    echo "请选择以下方式之一:"
    echo ""
    echo "方式1: 安装 gh 并登录"
    echo "   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
    echo "   echo 'deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
    echo "   sudo apt update && sudo apt install gh"
    echo "   gh auth login"
    echo ""
    echo "方式2: 在浏览器中手动上传"
    echo "   1. 打开 https://github.com/WangXianzhen/openbmc-knowledge"
    echo "   2. 点击 'uploading an existing file'"
    echo "   3. 拖拽 openbmc-gitbook 目录下的所有文件"
    echo ""
    echo "方式3: 直接用 Git 推送 (需要 Personal Access Token)"
    echo "   git remote set-url origin https://YOUR_TOKEN@github.com/WangXianzhen/openbmc-knowledge.git"
    echo "   git push -u origin master"
fi

echo ""
echo "==============================================="