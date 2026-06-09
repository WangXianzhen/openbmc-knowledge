# OpenBMC AST2700 知识库

![GitHub stars](https://img.shields.io/github/stars/aspeedtech-bmc/openbmc-knowledge?style=social)
![GitHub watchers](https://img.shields.io/github/watchers/aspeedtech-bmc/openbmc-knowledge?style=social)
![License](https://img.shields.io/github/license/aspeedtech-bmc/openbmc-knowledge)

> 🔧 AST2700-default BSP 完整代码分析 · 持续学习系统

## 📖 在线文档

访问 **GitHub Pages**: https://aspeedtech-bmc.github.io/openbmc-knowledge

## ✨ 特性

- 📚 **完整覆盖** - 10+ BSP 模块，40+ 文档
- 🔍 **快速搜索** - GitBook 内置搜索
- 🌙 **深色模式** - 支持切换主题
- 📱 **响应式** - 支持手机/平板访问
- 🔄 **自动更新** - GitHub Actions 自动部署
- ⭐ **Star 支持** - 欢迎 Star 支持！

## 📦 内容模块

| 模块 | 描述 | 文档数 |
|------|------|--------|
| Bootloader | U-Boot 引导加载器 | 3 |
| BootMCU | BootMCU 固件 | 3 |
| Kernel | Linux 内核配置 | 4 |
| Drivers | 设备驱动 | 2 |
| Security | PFR 安全 | 3 |
| Communication | MCTP/SPDM | 3 |
| Services | IPMI/传感器/状态 | 9 |
| Graphics | 图形服务 | 2 |
| Debug | PDbg 调试 | 2 |
| SSP | 协处理器 | 3 |

## 🚀 快速开始

### 在线浏览
直接访问: https://aspeedtech-bmc.github.io/openbmc-knowledge

### 本地运行
```bash
# 克隆仓库
git clone https://github.com/aspeedtech-bmc/openbmc-knowledge.git
cd openbmc-knowledge

# 安装依赖
npm install gitbook-cli -g
gitbook install

# 本地预览
gitbook serve
```

### 构建 PDF
```bash
gitbook pdf
```

## 🔧 技术栈

- **框架**: GitBook
- **部署**: GitHub Pages
- **CI/CD**: GitHub Actions
- **内容**: Markdown

## 📝 技术规格

- **SOC**: AST2700 (aspeed-g7)
- **CPU**: ARM Cortex-A35 (64-bit)
- **U-Boot**: v2023.10
- **内核**: 5.15 / 6.6 / 6.12 / 6.18
- **安全**: ECDSA384 + SHA384 + LMS

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License