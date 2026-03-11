
# RV32I 单周期 CPU 工程说明

这个仓库包含一个基于 Verilog 实现的 RV32I 单周期 CPU、片上指令/数据存储器、UART、按钮输入控制器、LED/七段数码管控制器，以及对应的程序编译脚本和仿真 testbench。

README 重点覆盖以下内容：

- 工程整体结构
- 硬件与软件的编程框架
- 现有测试例子
- 如何编译程序、加载程序并运行仿真

## 1. 工程整体结构

```text
cpu_sources/
├── src/              Verilog RTL 源码
├── sim/              仿真 testbench、脚本和说明文档
├── prog/             RISC-V 程序、运行时、编译脚本
├── build/            构建产物目录
├── simv              已编译的 Icarus 仿真可执行文件
└── tb_top.vcd        示例波形输出
```

### 1.1 RTL 目录

`src/` 下是核心硬件模块：

- `cpu.v`：单周期 RV32I CPU 核心
- `alu.v`：算术逻辑单元
- `reg_file.v`：寄存器堆
- `imem.v`：指令存储器，支持 `$readmemh` 加载程序
- `ram.v`：数据 RAM
- `mem_cont.v`：统一管理 IMEM/DRAM 的访问
- `uart_cont.v`：UART 控制器
- `btn_cont.v`：按钮输入控制器
- `seg7_cont.v`：LED/七段数码管控制器
- `top_circuit.v`：系统顶层，将 CPU、存储器和外设连接起来

### 1.2 仿真目录

`sim/` 目录下有两类验证内容：

- 模块级 testbench
	- `tb_rv32i_alu.v`
	- `tb_uart_cont.v`
	- `tb_uart_cpu.v`
	- `tb_uart_cpu_rx.v`
	- `tb_btn_cont.v`
	- `tb_seg7_cont.v`
	- `tb_load_store.v`
	- `tb_control.v`
	- `tb_fibnaco.v`
	- `test_reg_file.v`
- 整机级 testbench
	- `tb_top.v`：最常用的整机仿真入口，支持加载程序、UART 交互、按钮输入、LED/数码管观察、脚本驱动

此外还有脚本和配套说明：

- `tiggle_led.script`：按钮 + 数码管示例脚本
- `btn_probe.script`：按钮测试脚本
- `seg7_demo.script`：七段数码管演示脚本
- `SEG7_TESTBENCH_GUIDE.md`：七段数码管测试完整说明
- `SEG7_QUICK_REFERENCE.md`：七段数码管命令速查

### 1.3 程序目录

`prog/` 目录用于放置运行在 CPU 上的程序，以及配套运行时：

- `compile.sh`：编译 RV32I 汇编程序
- `compile_c.sh`：编译 RV32I C 程序
- `linker.ld`：链接脚本
- `runtime/`
	- `runtime.s`：启动代码，负责初始化栈、`.data`、`.bss`
	- `runtime.h`：地址映射和统一运行时头文件
	- `uart.c/.h`：UART 访问接口
	- `seg7.c/.h`：七段数码管接口
	- `button.c` / `buttons.h`：按钮接口
	- `soft_div.c`：软除法支持
- `test/`
	- `framework/`：C 框架示例
	- `uart/`：UART 汇编示例
	- `fib/`：已有的 fib 产物示例

## 2. 系统架构与地址映射

该工程的地址空间大致如下：

```text
0x0000_0000 - 0x0000_0FFF   IMEM，指令存储器，只读
0x0000_1000 - 0x0000_1FFF   DRAM，数据存储器，读写
0x1000_0000 - 0x1000_0FFF   MMIO 外设区
```

其中 MMIO 主要分为三部分：

- UART：`0x1000_0000`
- Buttons：`0x1000_0100`
- LED / 7-seg：`0x1000_0200`

运行时头文件 `prog/runtime/runtime.h` 已经把这些地址封装成了宏和访问函数，写 C 程序时通常直接包含：

```c
#include "runtime.h"
```

## 3. 编程框架

### 3.1 汇编程序框架

如果写纯汇编，可以直接自己定义 `_start`，例如 `prog/test/uart/hello_uart.s` 和 `prog/test/uart/uart_echo.s`。

编译方式：

```bash
cd prog
./compile.sh test/uart/hello_uart.s hello_uart
./compile.sh test/uart/uart_echo.s uart_echo
```

生成产物包括：

- `.elf`
- `.bin`
- `.hex`：供 Verilog 的 `$readmemh` 使用
- `.dump`：反汇编结果

### 3.2 C 程序框架

`compile_c.sh` 提供了两种编程模式。

#### 模式 A：`init()` / `always()`

启动代码 `runtime/runtime.s` 的行为是：

1. 初始化栈指针
2. 拷贝 `.data`
3. 清零 `.bss`
4. 调用一次 `init()`
5. 进入死循环，不断调用 `always()`

因此最常见的 C 程序框架是：

```c
#include "runtime.h"

void init(void) {
		// 初始化外设、变量等
}

void always(void) {
		// 主循环逻辑
}
```

这两个符号是 weak 的，所以只实现自己需要的函数即可。

编译示例：

```bash
cd prog
./compile_c.sh test/framework/hello_cpu.c --output hello_cpu
./compile_c.sh test/framework/tiggle_led.c --output tiggle_led
```

#### 模式 B：普通 `main()`

如果更习惯标准 C 入口，可以使用 `--with-main`，脚本会自动生成一个 shim，在 `init()` 中调用 `main()`：

```bash
cd prog
./compile_c.sh your_program.c --with-main --output your_program
```

### 3.3 运行时可用接口

运行时已经封装了常用外设访问接口：

- UART
	- `uart_init()`
	- `uart_putc()`
	- `uart_puts()`
	- `uart_getc()`
	- `uart_getc_nonblock()`
- Buttons
	- `btn_read()`
	- `btn_edge_pending()`
	- `btn_clear_edge()`
- 7-seg
	- `seg7_show_hex()`
	- `seg7_show_dec_digit()`
	- `seg7_show_u32()`
	- `seg7_clear_all()`

## 4. 现有程序示例

### 4.1 UART 汇编示例

- `prog/test/uart/hello_uart.s`
	- 周期性输出 `Hello, UART!`
- `prog/test/uart/uart_echo.s`
	- 从 UART 接收一个字节，再回显该字节

### 4.2 C 框架示例

- `prog/test/framework/hello_cpu.c`
	- 在 `always()` 中不断通过 UART 输出 `Hello, CPU!`
- `prog/test/framework/tiggle_led.c`
	- 检测按钮边沿
	- 每次按键事件发生时计数加一
	- 使用 `seg7_show_u32()` 将计数显示到四个七段数码管上

### 4.3 预编译产物

仓库中已经有部分产物可直接用于仿真，例如：

- `prog/hello_uart.dump`
- `prog/tiggle_led.dump`
- `prog/uart_echo.dump`
- `prog/test/framework/hello_cpu.dump`

如果缺少对应 `.hex`，建议重新运行编译脚本生成，避免文档和实际产物脱节。

## 5. 如何运行整机仿真

整机仿真推荐使用 `sim/tb_top.v`。

### 5.1 编译 testbench

在仓库根目录执行：

```bash
iverilog -g2005-sv -o simv sim/tb_top.v src/*.v
```

也可以输出到其他路径：

```bash
mkdir -p build
iverilog -g2005-sv -o build/simv sim/tb_top.v src/*.v
```

### 5.2 运行空载仿真

```bash
vvp simv
```

默认行为：

- 执行复位
- 打开 UART TX 监视器
- 若未设置 `+NO_TIMEOUT`，默认运行 `2_000_000` 个周期后退出
- 默认生成 `tb_top.vcd`

### 5.3 常用 plusargs

`tb_top.v` / `top_circuit.v` 支持如下参数：

- `+PROG=<file>`：将指定 `.hex` 文件加载进 IMEM
- `+SCRIPT=<file>`：执行脚本驱动的输入刺激
- `+TIMEOUT=<n>`：设置超时周期数
- `+NO_TIMEOUT`：不超时，持续运行
- `+TRACE_MMIO`：打印 MMIO 读写轨迹
- `+VCD=<file>`：指定 VCD 文件名
- `+NO_VCD`：不输出波形

### 5.4 加载程序运行

例如先编译一个 C 程序：

```bash
cd prog
./compile_c.sh test/framework/hello_cpu.c --output hello_cpu
```

然后回到工程根目录运行：

```bash
vvp simv +PROG=prog/hello_cpu.hex +TIMEOUT=200000 +TRACE_MMIO
```

如果程序是长期循环的，可以改用：

```bash
vvp simv +PROG=prog/hello_cpu.hex +NO_TIMEOUT +NO_VCD
```

### 5.5 UART 回显示例

```bash
cd prog
./compile.sh test/uart/uart_echo.s uart_echo
cd ..
vvp simv +PROG=prog/uart_echo.hex +NO_VCD
```

如果需要给 echo 程序注入 UART 输入，可以写一个只含 UART 命令的脚本，例如：

```text
uart_rx 41
uart_recv
finish
```

上面的含义是注入字节 `0x41`，然后等待 CPU 从 UART TX 回传一个字节。

实际运行时可保存为任意脚本文件，再通过 `+SCRIPT=<file>` 传入。

## 6. 脚本驱动仿真

`tb_top.v` 内置了脚本解析器，适合做回归测试或交互验证。

脚本文件每行一条命令，支持的主要命令有：

```text
wait <cycles>
btn_set <dev> <val_hex>
btn_press <dev> <bit>
btn_release <dev> <bit>
btn_pulse <dev> <bit> <hold_cycles>
btn_clear
uart_rx <byte_hex>
uart_recv
led_print
led_wait <dev> <mask_hex> <expected_hex> <max_cycles>
seg7_write <dev> <pattern_hex>
seg7_show_hex <dev> <hex_digit>
seg7_show_dec <dev> <dec_digit>
seg7_show_u32 <value>
seg7_wait <dev> <pattern_hex> <max_cycles>
seg7_clear
finish
```

运行脚本示例：

```bash
vvp simv +SCRIPT=sim/seg7_demo.script +NO_VCD
```

这个命令已经在当前仓库环境下验证通过，可以直接用于演示数码管功能。

## 7. 七段数码管测试示例

仓库已经提供完整的七段数码管验证支持。

### 7.1 直接运行官方示例脚本

```bash
vvp simv +SCRIPT=sim/seg7_demo.script +NO_VCD
```

### 7.2 按钮驱动计数示例

先编译：

```bash
cd prog
./compile_c.sh test/framework/tiggle_led.c --output tiggle_led
cd ..
```

再运行：

```bash
vvp simv +PROG=prog/tiggle_led.hex +SCRIPT=sim/tiggle_led.script +TRACE_MMIO
```

这个例子会：

1. 等待程序初始化
2. 观察数码管初始值
3. 通过脚本脉冲按钮 `btn0[0]`
4. 等待数码管从 `0` 变到 `1`

## 8. 模块级 testbench 运行方式

如果只想验证某个模块，不必走整机流程，可以直接编译相应 testbench。

例如运行 ALU testbench：

```bash
mkdir -p build
iverilog -g2005-sv -o build/tb_rv32i_alu sim/tb_rv32i_alu.v src/*.v
vvp build/tb_rv32i_alu
```

例如运行 UART 控制器 testbench：

```bash
iverilog -g2005-sv -o build/tb_uart_cont sim/tb_uart_cont.v src/*.v
vvp build/tb_uart_cont
```

同理可以替换为：

- `sim/tb_btn_cont.v`
- `sim/tb_seg7_cont.v`
- `sim/tb_load_store.v`
- `sim/test_reg_file.v`

## 9. 推荐开发流程

比较顺手的一条流程如下：

1. 在 `prog/test/` 下写汇编或 C 程序
2. 用 `compile.sh` 或 `compile_c.sh` 生成 `.hex`
3. 用 `iverilog` 编译 `sim/tb_top.v`
4. 用 `vvp simv +PROG=...` 加载程序运行
5. 需要外设输入时，加 `+SCRIPT=...`
6. 需要看总线行为时，加 `+TRACE_MMIO`
7. 需要调波形时，保留 VCD 输出并用 GTKWave 打开

示例：

```bash
cd /home/ll06/info/cpu_sources
iverilog -g2005-sv -o simv sim/tb_top.v src/*.v

cd prog
./compile_c.sh test/framework/hello_cpu.c --output hello_cpu
cd ..

vvp simv +PROG=prog/hello_cpu.hex +TIMEOUT=200000 +VCD=hello_cpu.vcd
```

## 10. 依赖工具

建议安装以下工具：

- `iverilog`
- `vvp`
- `gtkwave`：查看波形
- RISC-V GNU Toolchain，至少包含以下之一：
	- `riscv32-unknown-elf-gcc`
	- `riscv64-unknown-elf-gcc`
	- `riscv64-linux-gnu-gcc`

## 11. 备注

- 仿真时，`+PROG=<file>` 是由 `top_circuit.v` 直接对 IMEM 执行 `$readmemh` 完成加载的。
- `imem.v` 在未加载程序时会默认填充 RV32I NOP，便于做空载启动和调试。
- 加载较短的 `.hex` 文件时，Icarus 可能提示 `$readmemh` 的 `Not enough words`，这通常只是说明文件没有填满整个 IMEM；其余空间仍会保留为 NOP。
- 若程序长期运行，建议配合 `+NO_TIMEOUT` 和 `+NO_VCD`，避免仿真文件过大。
- 若只想快速看 UART 输出，`tb_top.v` 自带 UART TX 监视器，会直接把可打印字符输出到控制台。

