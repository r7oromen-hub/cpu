# 实验三：算术逻辑与条件转移指令扩展

工作分支：`experiment-3`。依赖实验二的数据相关、前递、load-use 阻塞和转移清空实现。

## 要求与设计记录

依据《计组课设指导书 LA 版 2025》PDF 第 23-24 页，实验三包括 `ex4_obj` 的算术逻辑扩展和 `ex5_obj` 的条件转移扩展。依据随课程提供的《龙芯架构 32 位精简版参考手册》2.2.1、2.2.2、2.2.3 节核对功能。

| 新指令 | 运算与操作数 | 对控制逻辑的影响 |
| --- | --- | --- |
| `slti` | rj 与符号扩展 si12 做有符号小于比较 | 使用 SLT ALU，只读 rj |
| `sltui` | rj 与符号扩展 si12 做无符号小于比较 | 使用 SLTU ALU，只读 rj；立即数仍符号扩展 |
| `andi/ori/xori` | rj 与零扩展 ui12 做按位运算 | 复用逻辑 ALU，只读 rj |
| `sll.w/srl.w/sra.w` | rj 按 rk 的低 5 位移位 | 复用移位 ALU，读 rj/rk |
| `pcaddu12i` | 当前指令 PC + `{si20,12'b0}` | 复用加法 ALU，不读 rj/rk |
| `blt/bge` | rj、rd 做有符号比较，分支偏移 si16 左移 2 位 | 读 rj/rd，不写寄存器 |
| `bltu/bgeu` | rj、rd 做无符号比较 | 读 rj/rd，不写寄存器 |

源寄存器使用掩码必须随新译码同步更新。立即数字段不能误当成 rk；PC 相对指令的字段不能误当成 rj。条件分支必须使用与前递路径相同的 rj/rd 数据。

## 文件修改清单

- `tests/isa_extensions_tb.v`：独立 CPU 级定向测试，不依赖交叉汇编器。通过实际执行指令建立操作数，逐条检查写回 PC、目标寄存器和结果；检查转移错误路径存储无副作用。
- `cdp_ede_local-master/mycpu_env/myCPU/id_stage.v`：增加 13 条指令译码；复用既有 12 位 ALU 操作码；增加逻辑立即数零扩展选择；PCADDU12I 选择指令 PC；扩展真实源寄存器使用掩码、写寄存器许可；增加有符号/无符号比较和条件分支分组，复用实验二的前递操作数和发射握手限定。
- `scripts/run_lab3_directed.sh`：用 forward/stall 两模式运行定向检查。
- `.gitignore`：忽略临时 PDF 渲染及 Icarus 编译产物，测试源码与汇总仍保留在 Git 中。

本次没有改变级间总线宽度、EXE/MEM/WB 数据通路及 ALU。新增控制通过原有总线传递。实验二核心提交 `cc5ada7` 与其文档提交通过主任务合入本分支。

## 测试计划与结果

定向测试覆盖 SLTUI 的负立即数符号扩展、逻辑立即数最高位为 1 的零扩展、32/63 移位量低 5 位截取、PC 正负偏移、signed/unsigned 分支异号与相等边界、负偏移循环及错误路径写寄存器/存储清空。

完整回归计划：`ex1_obj` 至 `ex5_obj`，forward 模式；`ex4_obj`、`ex5_obj` 再使用 stall 模式核对无前递实现。官方程序使用独立参考核生成写回轨迹并逐条对比，不仅依据最终测试点计数。

2026-10-14 定向测试实际输出（forward 与 stall 均相同）：

```text
DIRECTED ISA PASS: 43 writes, 601 cycles
```

601 周期包含末尾等待检查错误路径副作用的时间，不是性能测量。

2026-10-14 完整镜像 forward 回归全部通过：

| 镜像 | 功能点 | 独立参考核有效写回逐条一致 |
| --- | ---: | ---: |
| `ex1_obj` | 20/20 | 46,534 |
| `ex2_obj` | 20/20 | 46,534 |
| `ex3_obj` | 20/20 | 46,534 |
| `ex4_obj` | 29/29 | 62,377 |
| `ex5_obj` | 33/33 | 71,332 |

复现命令：

```bash
bash scripts/run_lab3_directed.sh
python3 scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj ex4_obj ex5_obj --mode forward
python3 scripts/run_regression.py --image ex4_obj ex5_obj --mode stall
```

纯阻塞模式 `ex4_obj` 29/29 点、62,377 次有效写回通过，`ex5_obj` 33/33 点、71,332 次有效写回通过。两种相关处理方式均能正确运行新增指令。

前递回归汇总为 `test-results/regression-forward-ex1_obj-ex2_obj-ex3_obj-ex4_obj-ex5_obj.json`，阻塞汇总为 `test-results/regression-stall-ex4_obj-ex5_obj.json`。原始编译/运行日志与参考轨迹位于 `test-results/raw/`（生成物不纳入 Git）。

## 问题记录

- SLTUI 的 U 指比较无符号，不表示立即数零扩展。
- 本实验复用既有 ALU，不需要为了寄存器移位重新添加运算单元。
- 分支比较不能直接读取未经前递修正的寄存器堆值。
- 硬件综合、实现、时序已单独验收；它们不等同于实物上板或线上结果。

## Vivado 最终验收

2026-10-14 已用 Vivado 2018.3 完成 CPU-only 综合及 `xc7a200tfbg676-1`
远程 BRAM SoC 顶层综合、布局布线和 bitstream 生成。实际 CPU 50 MHz，
timer 100 MHz。最终 WNS=0.172 ns、WHS=0.112 ns、WPWS=4.500 ns，
全部 TNS/THS/TPWS=0，DRC 违规为 0。当前镜像为 ex5，两块 RAM 的生成 MIF
与选定 COE 逐字一致。

证据：[验收摘要](../test-results/vivado-remote/summary.json)、
[最终时序](../test-results/vivado-remote/timing-summary.txt)、
[DRC](../test-results/vivado-remote/drc.txt)、
[CPU-only 综合资源](../test-results/cpu-synthesis/utilization.rpt)。
工程在 `build/vivado-remote/loongson.xpr`，输出在
`build/vivado-remote/loongson.runs/impl_1/looongson_remote_top.bit`。
FPGA 实物上板和校内线上测评未执行，不标 PASS。
