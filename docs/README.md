# OpenBMC AST2700 知识库

欢迎使用 OpenBMC AST2700 知识库！本文档详细分析了 AST2700-default 机器的 BSP (Board Support Package) 源代码。

## 📖 内容概览

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

## 🔧 技术规格

- **SOC**: AST2700 (aspeed-g7)
- **CPU**: ARM Cortex-A35 (64-bit)
- **U-Boot**: v2023.10
- **内核**: 5.15 / 6.6 / 6.12 / 6.18
- **安全**: ECDSA384 + SHA384 + LMS

## 🚀 快速开始

1. 点击左侧目录导航
2. 或使用搜索功能查找内容
3. 阅读各模块的详细分析文档

## 📝 贡献

本知识库通过自动化系统持续更新。如有疑问，请提交 Issue。

## License

MIT License