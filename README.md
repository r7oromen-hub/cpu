# LoongArch 计组实验一至五

实验一至五采用逐步继承的五个 Git 分支。本目录是最终累计版本
`branches/experiment-5`，包含前五个实验的全部 CPU 功能。
2026-10-14 前递模式 `ex1_obj` 至 `ex7_obj` 全部完成独立参考核写回对拍；
实验五纯阻塞模式 `ex7_obj` 也通过。

先看 [交付总览](docs/overview.md)，再看对应实验文档。名称带 `1` 的对照目录未修改。

## 分支与验收范围

实验按《计组课设指导书LA版-2025》前五章编号，不能与 `exN_obj` 镜像编号混淆。

| Git 分支 / 工作目录 | 实验内容 | 课程功能测试 | 修改和问题记录 |
| --- | --- | --- | --- |
| experiment-1 | 不考虑冲突的五级流水 | ex1_obj | [实验一](docs/experiment-1.md) |
| experiment-2 | RAW 阻塞、控制冲突清空、EXE/MEM/WB 前递 | ex2_obj、ex3_obj | [实验二](docs/experiment-2.md) |
| experiment-3 | 算术逻辑和条件转移指令 | ex4_obj、ex5_obj | [实验三](docs/experiment-3.md) |
| experiment-4 | 字节/半字 load 和 store | ex6_obj | [实验四](docs/experiment-4.md) |
| experiment-5 | 乘法和迭代除法 | ex7_obj | [实验五](docs/experiment-5.md) |

五个分支已分别检出到 `计组课设la版/branches/experiment-1` 至
`experiment-5` 的独立 worktree。直接打开所需目录，不必在当前目录执行
`git switch`；Git 通常也不允许切换到已经被另一个 worktree 使用的分支。
原 Git 主工作目录 `计组课设la版/计组课设la版` 保留 baseline，不能把其中旧代码
当作最终累计实现。实验二及以后保留 `--mode stall` 与 `--mode forward` 两种测试方式。

## 打开和测试最终版本

Vivado 直接打开本目录的 `build/vivado-remote/loongson.xpr`。
CPU 源码在 `cdp_ede_local-master/mycpu_env/myCPU/`，展开 Sources 中的
`looongson_remote_top → soc_lite → cpu` 即可找到五级流水模块。
工程关闭后再打开 `.xpr`，不用重新运行创建 Tcl。

在本目录打开 PowerShell 后运行：

```powershell
python scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj ex4_obj ex5_obj ex6_obj ex7_obj --mode forward
python scripts/run_regression.py --image ex7_obj --mode stall
```

脚本自动调用 WSL Ubuntu 的 Icarus，选择四个 RAM 镜像、生成独立参考 trace、
逐条比较 PC/寄存器号/写回数据，并检查功能点和退出状态。命令最后选择的镜像
会保留在本分支的 `func/obj`，不要把旧 bitstream 当成新镜像结果。
环境和故障记录见 [验证说明](docs/verification.md)。

## 源码

- CPU：`cdp_ede_local-master/mycpu_env/myCPU/`
- SoC：`cdp_ede_local-master/mycpu_env/soc_verify/soc_bram/`
- 独立参考核：`cdp_ede_local-master/mycpu_env/gettrace/src/`
- 课程镜像：`for_test_obj/ex1_obj` 至 `for_test_obj/ex7_obj`
- 远程 FPGA 适配：`remote/`
- 实验记录：`docs/`

当前五个分支的 CPU-only Vivado 2018.3 综合均通过；远程板级工程正在统一完成
最终实现、时序及 bitstream 检查，最终结果见 [交付总览](docs/overview.md)。
实际 FPGA 上板和校内线上评测未执行。Vivado 生成目录和大型仿真输出不提交。
