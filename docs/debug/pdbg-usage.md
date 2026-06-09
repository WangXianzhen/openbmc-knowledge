# PDbg 使用说明

## 构建 PDbg

### 通过 OpenBMC 构建

```bash
# 在 OpenBMC 构建环境中
cd /path/to/openbmc
. setup ast2700-default

# 单独构建 pdbg
bitbake pdbg
```

### 源码编译

```bash
# 克隆源码
git clone https://github.com/open-power/pdbg.git
cd pdbg

# 编译
make
make install
```

## 基本命令

### 探测目标

```bash
# 列出可用的调试目标
pdbg -l
pdbg -L

# 示例输出
proc0
    core0
        thread0
        thread1
    core1
        thread0
        thread1
```

### 读取寄存器

```bash
# 读取通用寄存器 (GPR)
pdbg get SPR 0    # 读取 CTR 寄存器
pdbg get SPR 1    # 读取 LR 寄存器

# 读取特定核心/线程的寄存器
pdbg -p 0 -c 0 -t 0 get r1
pdbg -p 0 -c 0 -t 1 get r1
```

### 写入寄存器

```bash
# 写入寄存器
pdbg put r3 0x12345678
pdbg put SPR 9 0xDEADBEEF
```

### 内存访问 (APB)

```bash
# 通过 APB 读取内存
pdbg getmem 0x1e780000 4    # 读取 4 字节

# 通过 APB 写入内存
pdbg putmem 0x1e780000 4 0x12345678

# 读取字符串
pdbg getmem 0x1e780000 64
```

### 处理器控制

```bash
# 停止处理器
pdbg stop

# 启动处理器
pdbg start

# 单步执行
pdbg step

# 复位
pdbg reset
```

## JTAG 接口使用

### 指定 JTAG 路径

```bash
# 使用特定的 JTAG 设备
pdbg -d /dev/jtag0 get r1
```

### JTAG 频率配置

```bash
# 设置 JTAG 时钟频率
pdbg -f 1000000 get r1    # 1MHz
```

## AST2700 特定用法

### 访问 SCU 寄存器

```bash
# 读取 SCU ID
pdbg getmem 0x1e789000 4

# 读取 Timer 寄存器
pdbg getmem 0x1e781000 8
```

### 访问 LPC 控制器

```bash
# 访问 LPC 内存映射区域
pdbg getmem 0x1e789000 4
```

### 访问 GPIO

```bash
# 读取 GPIO 数据寄存器
pdbg getmem 0x1e780000 4

# 读取 GPIO 方向寄存器
pdbg getmem 0x1e780004 4
```

## 常用选项

| 选项 | 描述 |
|------|------|
| `-l, --list` | 列出所有处理器核心 |
| `-L, --list-all` | 列出所有处理器和线程 |
| `-p N` | 选择处理器 N |
| `-c N` | 选择核心 N |
| `-t N` | 选择线程 N |
| `-d PATH` | 指定 JTAG 设备路径 |
| `-f FREQ` | 设置 JTAG 频率 |
| `-v` | 输出详细调试信息 |

## 故障排查

### 常见问题

1. **无法连接到目标**
   ```bash
   # 检查 JTAG 设备
   ls -l /dev/jtag*
   
   # 检查权限
   groups
   sudo usermod -a -G jtag $USER
   ```

2. **读取返回错误值**
   - 检查地址是否正确
   - 确认目标处理器是否运行

3. **编译失败**
   ```bash
   # 安装依赖
   sudo apt install dtc libdt-dev
   ```

## 输出目录

构建完成后，pdbg 二进制文件位于：
```
${WORKDIR}/build/pdbg
```

或通过 bitbake 构建后：
```
build/tmp/work/*/pdbg/*/image/usr/bin/pdbg
```