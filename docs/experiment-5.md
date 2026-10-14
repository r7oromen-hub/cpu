# 实验五：乘法与多周期除法

Git 分支为 `experiment-5`，工作目录是 `计组课设la版/branches/experiment-5`。只修改实验目录，名称带 `1` 的对照目录未修改。实验五对应课程镜像 `ex7_obj`，继承前四个实验的流水、相关处理、扩展算术与访存指令。

## 独立除法器

新增 `cdp_ede_local-master/mycpu_env/myCPU/iterative_divider.v`，使用恢复余数迭代算法。每个周期执行一次移位、无符号比较和减法，共 32 次迭代；可综合 RTL 没有 `/` 或 `%` 运算符。签名输入先取二补码绝对值，计算后恢复商和余数符号。有符号商向零截断，余数符号与被除数相同。`INT_MIN/-1` 商按 32 位二补码回绕。

接口：空闲时 `start=1` 接收 `signed_mode/dividend/divisor`；运行期间 `busy=1`，再次 `start` 被忽略；完成后 `busy=0,done=1`，商和余数保持，直到下次接受 `start` 或复位。除数为零定义商 `0xffffffff`、余数等于被除数，不产生异常。普通非零除数在接受请求之后 32 个时钟沿完成；流水线还需要一次开始握手。

新增 `tests/divider_tb.v`，用独立的 64 位有符号 `/`、`%` 计算测试期望值（这些算符仅位于仿真测试平台）。覆盖 11 个边界值的符号/无符号笛卡尔积、2,000 组固定种子随机输入、运行中无效 start、连续请求、输入变化、完成结果保持和复位中断。

新增 `scripts/run_lab5_directed.sh` 作为 Icarus 定向测试入口。独立除法器已于 2026-10-14 实测通过：`DIVIDER PASS cases=2243 corner/sign/random/busy-start/result-hold/reset-abort`。

新增 `tests/muldiv_pipeline_tb.v` 的流水定向测试，预期逐条比较 PC/寄存器号/写回值，包含七条新指令、signed/unsigned 高位乘法、两负数与不同符号的除法、余数符号、INT_MIN/-1、除零、load→mul、mul/div/mod RAW、结果送 store、除法后条件跳转及错误路径副作用、连续除法请求计数。该测试等待流水集成后执行，不能把草稿写为已通过。

## 集成计划与当前状态

正在等待实验四依赖集成后添加 `mul.w/mulh.w/mulh.wu/div.w/mod.w/div.wu/mod.wu`。EXE 保存除法请求状态，仅启动一次；除法结果准备好后才令 `es_ready_go=1`。EXE→ID 的结果未就绪信息必须覆盖除法，避免前递尚未完成的结果。完成结果在下游阻塞期间保持，直到 EXE→MEM 真正握手。

尚未运行课程完整回归、Vivado 综合/实现或线上评测，不能将这些项目标为通过。
