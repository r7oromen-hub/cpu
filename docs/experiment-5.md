# 实验五：乘法与多周期除法

Git 分支为 `experiment-5`，工作目录是 `计组课设la版/branches/experiment-5`。只修改实验目录，名称带 `1` 的对照目录未修改。实验五对应课程镜像 `ex7_obj`，继承前四个实验的流水、相关处理、扩展算术与访存指令。

## 独立除法器

新增 `cdp_ede_local-master/mycpu_env/myCPU/iterative_divider.v`，使用恢复余数迭代算法。每个周期执行一次移位、无符号比较和减法，共 32 次迭代；可综合 RTL 没有 `/` 或 `%` 运算符。签名输入先取二补码绝对值，计算后恢复商和余数符号。有符号商向零截断，余数符号与被除数相同。`INT_MIN/-1` 商按 32 位二补码回绕。

接口：空闲时 `start=1` 接收 `signed_mode/dividend/divisor`；运行期间 `busy=1`，再次 `start` 被忽略；完成后 `busy=0,done=1`，商和余数保持，直到下次接受 `start` 或复位。除数为零定义商 `0xffffffff`、余数等于被除数，不产生异常。普通非零除数在接受请求之后 32 个时钟沿完成；流水线还需要一次开始握手。

新增 `tests/divider_tb.v`，用独立的 64 位有符号 `/`、`%` 计算测试期望值（这些算符仅位于仿真测试平台）。覆盖 11 个边界值的符号/无符号笛卡尔积、2,000 组固定种子随机输入、运行中无效 start、连续请求、输入变化、完成结果保持和复位中断。

新增 `scripts/run_lab5_directed.sh` 作为 Icarus 定向测试入口。独立除法器已于 2026-10-14 实测通过：`DIVIDER PASS cases=2243 corner/sign/random/busy-start/result-hold/reset-abort`。

新增 `tests/muldiv_pipeline_tb.v` 的流水定向测试，逐条比较 PC/寄存器号/写回值，包含七条新指令、signed/unsigned 高位乘法、两负数与不同符号的除法、余数符号、INT_MIN/-1、除零、load→mul、mul/div/mod RAW、结果送 store、除法后条件跳转及错误路径副作用、连续除法请求计数。另外使用 128 对随机操作数、独立 64 位算术期望值比较 384 个 low/signed-high/unsigned-high 乘法结果，总共 671 条有效寄存器写回。

新增 `tests/muldiv_exe_hold_tb.v`，直接连接 ID 与 EXE，以可控 `ms_allowin` 实测下游阻塞。断言：除法尚未完成时依赖 ID 指令不能发射；完成后持续 8 个周期保持结果，不能重新 start；释放阻塞后依赖 add 捕获正确商；store 仅在真正握手时发出一次；复位中断在途除法并关闭副作用。

2026-10-14 实际定向结果：

```text
DIVIDER PASS cases=2243 corner/sign/random/busy-start/result-hold/reset-abort
MULDIV_PIPELINE PASS writes=671 cycles=1243 division-starts=17 stores=2
MULDIV_PIPELINE PASS writes=671 cycles=1520 division-starts=17 stores=2
MULDIV_EXE_HOLD PASS completed-output-hold/dependent-forward/single-store/reset-abort
```

两个流水结果依次是前递和纯阻塞模式，两种模式均逐条对拍，没有重复除法请求或错误路径 store。

集成后还重跑了前面实验的定向脚本：实验二 RAW/控制流分别 23 写回、39/68 周期，BaseRAM 接口 PASS；实验三扩展 ISA 两种模式均 43 写回 PASS；实验四字节/半字访存两种模式均 68 写回、8 次 store PASS。原功能没有因 DS→ES 总线扩展而退化。

## 流水集成与修改清单

| 文件 | 修改内容 | 原因 |
| --- | --- | --- |
| `myCPU/mycpu_head.v` | DS→ES 总线 151→157 位 | 增加 3 位乘法控制和 3 位除法控制 |
| `myCPU/id_stage.v` | 七条新指令译码，读源掩码、gr_we、控制字段；将旧 es_load 元数据推广为 es_result_unavailable | 正确检测乘除法 RAW，未完成的除法不能前递 |
| `myCPU/exe_stage.v` | 共用乘法器，例化迭代除法器，div_started 标志、ready_go、最终结果选择与前递 | 在多周期 EXE 保存当前指令，并与下游握手同步 |
| `myCPU/iterative_divider.v` | 新增 32 次恢复余数迭代 | 满足除法 RTL 不直接使用 `/` 或 `%` 的要求 |
| `tests/divider_tb.v` | 2,243 组独立算术对比与协议断言 | 验证边界、随机和除法器握手 |
| `tests/muldiv_pipeline_tb.v` | 671 条预期写回与副作用断言 | 验证实际七指令、前递/阻塞、RAW 和控制流 |
| `tests/muldiv_exe_hold_tb.v` | 下游阻塞与复位定向测试 | 验证完成结果保持和 store 不重复 |
| `scripts/run_lab5_directed.sh` | 两种模式及独立模块的自动运行入口 | 提供可复现定向验收 |

表中 `myCPU` 完整路径为 `cdp_ede_local-master/mycpu_env/myCPU`。乘法控制为 `{unsigned_high,signed_high,low}`；除法控制为 `{is_div,signed_mode,is_remainder}`。两组字段作为 DS→ES 总线最高 6 位，其余访存字段顺序沿用实验四。MEM/WB 接口不变，EXE 把选择后的 ALU/乘法/商/余数统一送到原结果字段。

乘法使用一个 33×33 位有符号 `*`。signed-high 的操作数符号扩展、unsigned-high 的操作数零扩展（32 位无符号数可以完整容纳在 33 位有符号数中）；low 结果取 `[31:0]`，高位结果取 `[63:32]`。不使用两套并行 signed/unsigned 乘法器。乘法为单周期组合逻辑，具体频率和 DSP 映射需要 Vivado 实测。

EXE 的 `div_start = es_valid && is_div && !div_started && !reset`；请求开始后置 `div_started`，仅在 EXE 允许更新或复位时清零。`es_ready_go = !is_div || (div_started && div_done)`。除法完成后可前递，但下游堵塞时 EXE 不换指令，商和余数继续保持，直到 `es_to_ms_valid && ms_allowin` 真正握手。同步 RAM 访问仍受该真正握手限定，乘除法不会发起 SRAM 请求。

EXE→ID 的 39 位总线保持位宽，将原 load 位推广为“结果未就绪”：load 或尚未完成的除法为 1。ID 命中该最新生产者时阻塞，不得错误使用较老的 MEM/WB 同名结果；除法完成后该位清零并选择最终商/余数前递。

## 实现问题记录

1. 除法器完成信号保持以支持下游等待，连续除法会遇到前一条的旧 `done=1`。增加每条 EXE 指令独立的 `div_started`，只有当前指令已开始且完成才放行，避免提前消费旧结果。
2. 原 EXE→ID 第二位只表示 load；多周期除法尚未完成时也不能旁路。推广为 `es_result_unavailable`，保持原 39 位总线以便复用所有前递连线。
3. signed/unsigned 乘法高 32 位不相同，而低 32 位相同。使用 33 位扩展明确类型，再用 128 对随机数逐类比较，避免 Verilog 隐式有符号转换或表达式截断错误。
4. 除法请求只开始一次，完成结果不能随输入端总线变化。独立测试在运行中改变输入、发送无效 start，流水测试在下游堵塞后等待 8 周期，均断言结果稳定且不重启。
5. `INT_MIN` 绝对值不能用 32 位有符号正数表示，但可用 unsigned magnitude `0x80000000`。内部按无符号 32 位幅值迭代，最终恢复二补码符号。

已知继承边界：复位测试证明 EXE valid 清空、除法中断和 EXE 访存请求关闭，不代表通用寄存器堆全部清零。基线 WB 的 `rf_we` 只门控 `ws_valid/gr_we`，未直接门控 reset；任意时刻的 warm reset 首个清 valid 时钟沿可能仍提交旧 WB 写回。因此本分支不声称任意 warm reset 下完全没有 RF 写入，课程启动复位及 r0 恒零契约不受影响。

## 可复现测试与完整回归

在 WSL 仓库根目录：

```bash
bash scripts/run_lab5_directed.sh
python3 scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj ex4_obj ex5_obj ex6_obj ex7_obj --mode forward
python3 scripts/run_regression.py --image ex7_obj --mode stall
```

完整回归独立编译未修改的课程参考核 `gettrace/src/myCPU/SimpleLACoreWrapRAM.v` 生成 trace，再与本分支 CPU 的有效写回比较。定向测试中的算术 oracle 位于 tests，不参与综合；参考核没有为迁就 DUT 修改乘除法核心。

2026-10-14 本分支前递模式完整回归全部 PASS，每个镜像所有功能点和启用写回记录均精确一致：

| 镜像 | 功能点 | 启用写回对拍 | 结果 |
| --- | --- | --- | --- |
| ex1_obj | 20/20 | 46,534/46,534 | PASS |
| ex2_obj | 20/20 | 46,534/46,534 | PASS |
| ex3_obj | 20/20 | 46,534/46,534 | PASS |
| ex4_obj | 29/29 | 62,377/62,377 | PASS |
| ex5_obj | 33/33 | 71,332/71,332 | PASS |
| ex6_obj | 39/39 | 79,750/79,750 | PASS |
| ex7_obj | 46/46 | 86,846/86,846 | PASS |

摘要文件：`test-results/regression-forward-ex1_obj-ex2_obj-ex3_obj-ex4_obj-ex5_obj-ex6_obj-ex7_obj.json`，包含各镜像 SHA-256、耗时和独立参考核说明。纯阻塞模式 ex7 全镜像也已 PASS：46/46 功能点，86,846/86,846 启用写回记录；对应 `test-results/regression-stall-ex7_obj.json`。

Vivado 综合/实现由主代理统一执行并补充结果；FPGA 上板和校内线上评测未执行，不标为通过。
