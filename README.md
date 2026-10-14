# 实验二：相关阻塞、前递和控制冲突

Git 分支为 `experiment-2`，真实工作目录为 `计组课设la版/branches/experiment-2`。本 worktree 已检出同名分支，不需要 `git switch`。其他实验从[实验导航](../../实验导航.md)进入；名字带 `1` 的对照目录未修改。

继承实验一，增加 RAW 检测、纯阻塞、EXE/MEM/WB 前递、load-use 等待和分支错误路径清空。`ex2_obj` 验收纯阻塞，`ex3_obj` 验收前递；实验号与镜像号不同。

修改位置、实现问题与测试结果见[本实验记录](docs/experiment-2.md)。CPU 源码位于 [cdp_ede_local-master/mycpu_env/myCPU](cdp_ede_local-master/mycpu_env/myCPU/)。

打开 [Vivado 远程工程 loongson.xpr](build/vivado-remote/loongson.xpr)，在 Sources 中展开 `looongson_remote_top → soc_lite → cpu` 查看五级流水。关闭后重新打开该 `.xpr`，不用重跑创建 Tcl。

在本目录的 PowerShell 中复现课程镜像测试：

```powershell
python scripts/run_regression.py --image ex2_obj --mode stall
python scripts/run_regression.py --image ex3_obj --mode forward
```

镜像仿真及 CPU-only Vivado 综合已通过。完整板级实现、时序和 bitstream 结果以[远程工程验收摘要](test-results/vivado-remote/summary.json)为准；实际 FPGA 上板和校内线上测评尚未执行。
