# 实验一：不处理相关冲突的五级流水 CPU

分支：`experiment-1`。范围按指导书第一章，验收镜像为 `for_test_obj/ex1_obj`。
实验目录只使用 `计组课设la版`，名字带 `1` 的对照目录没有改动。

## CPU 修改清单

本分支继承 2026-09-22 已实现的 CPU，完整代码已经纳入 Git 基线，因此这次的
新增提交主要是复现验证和工程配置；不能把基线已存在的源码误当成本次新增。

| 文件 | 实现内容和目的 |
| --- | --- |
| `myCPU/mycpu_top.v` | 单周期数据通路改成 IF/ID/EXE/MEM/WB 五级，连接 valid/allowin、各级总线、分支总线、WB 写回和 SRAM 接口 |
| `myCPU/mycpu_head.v` | 统一总线位宽：33/64/148/71/70/38，并增加 include guard |
| `myCPU/if_stage.v` | 维护 PC 和 valid；用 nextpc 请求同步指令 SRAM，使下一周期的指令与 fs_pc 对齐 |
| `myCPU/id_stage.v` | 20 条基础指令译码、寄存器读、立即数/源操作数/目的寄存器生成，在 ID 判断分支 |
| `myCPU/exe_stage.v` | ALU 运算、load/store 地址和写数据生成，片选与写使能受 es_valid 限定 |
| `myCPU/mem_stage.v` | 使用同步数据 SRAM 返回值，选择 load 数据或 ALU 结果 |
| `myCPU/wb_stage.v` | 寄存器写回和调试输出，写使能受 ws_valid 限定 |
| `myCPU/alu.v` | 修复 OR 组合环、移位操作数方向、算术右移符号扩展及有/无符号比较 |
| `myCPU/regfile.v` | 拒绝写 `$r0`，两个读取零寄存器的端口恒返回 0 |

20 条基础指令为 `add.w/sub.w/slt/sltu/nor/and/or/xor/slli.w/srli.w/srai.w/` 
`addi.w/ld.w/st.w/jirl/b/bl/beq/bne/lu12i.w`。`bl` 写回 `$r1`，
`jirl/bl` 的链接数据为当前 PC+4。`st.w` 四个字节使能，指令 SRAM 始终只读。

## 流水时序和边界

每级保存独立 valid 和流水数据寄存器；允许输入时复制上一级 to_next_valid，
握手成功时才锁存总线。全部 ready_go 在本实验固定为 1。EXE 计算地址并在
EXE→MEM 时钟沿访问同步 RAM，MEM 使用返回数据，WB 写寄存器。

该版本不检测 RAW、不做数据前递、不清空分支错误路径。课程 ex1 程序插入
空操作规避相关冲突，因此不能声称已通过有依赖的任意指令流。实验二同时实现
阻塞、控制冲突和前递，分别测试 ex2/ex3；后续实验编号不能和镜像编号混淆。

## 本轮新发现的问题和处理

1. 同步 RAM 模型的 wdata 误写成 output：改为 input；字节写入增加 en gating，
   避免片选关闭仍写内存。读仍是同步、使能保持、read-first。
2. 原 TB 用 `$finish`/`$stop` 报错，自动任务可能认为返回 0 就成功：所有失败改
   `$fatal(1)`，检查 trace 格式/耗尽、结束后未消费记录和完整写回总数。
3. 原工程 creator 依赖启动目录，并有 `-force` 覆盖现有工程风险：改为定位自身，
   调用统一脚本，逐文件加入五个 stage 和 header，明确综合与仿真顶层。
4. 中文绝对路径传给 Icarus `$fopen/$readmemb` 导致文件 API 报 non-printable
   并不能生成 trace：运行路径改成 ASCII 相对路径，源码可保留中文目录。
5. 旧记录把“当前机器未安装 Vivado”写成固定结论：本次已定位
   `F:\vivado\Vivado\2018.3\bin\vivado.bat`，由主代理统一执行 Vivado 验证。
   未实际完成的综合、时序、bitstream、上板、线上评测不能标为通过。

## 可复现测试

从分支根目录：

```powershell
python scripts/run_regression.py --image ex1_obj
```

该命令独立编译课程参考核生成新 trace，再编译五级 CPU，用 soc_bram 的同步
RAM/CONFREG 环境逐条对拍。2026-10-14 实测：20/20 功能点，46,534/46,534
启用写回记录，最终 `----PASS!!!`，进程返回 0。对应可提交摘要：
`test-results/regression-forward-ex1_obj.json`；原始日志和 trace 在
`test-results/raw/ex1_obj-forward/`（不提交大型输出）。

同步 RAM 定向测试源码在 `tests/tb_sync_ram.v`，覆盖全字写、字节写使能、关闭
片选禁止写、关闭片选读输出保持，以及同步 read-first 时序。详细环境、命令、
故障退出要求和 Vivado 操作见 `docs/verification.md`。
该测试实测返回 0、输出 `RAM_MODEL_PASS`，摘要在 `test-results/ram-model.json`。

在 WSL 中进入分支根目录，已经运行过回归后执行：

```sh
iverilog -g2012 -s tb_sync_ram -o test-results/raw/tb_sync_ram.vvp tests/tb_sync_ram.v cdp_ede_local-master/mycpu_env/soc_verify/soc_bram/testbench/sync_ram.v
vvp -n test-results/raw/tb_sync_ram.vvp
```

## FPGA 与线上准备

`scripts/create_vivado.tcl` / `scripts/build_vivado.tcl` 支持 `local` 和 `remote`。
本地/远程各自独立项目；远程输入时钟 50 MHz、两块 RAM 使用当前镜像 COE，
包括 remote2local 和远程顶层，仅加载远程 XDC。关闭后重新打开 `.xpr`，
不重复 create_project。Vivado 实测结果由主代理补充；实际 FPGA 板与校内线上
平台未在本分支的 Icarus 回归中测试。
