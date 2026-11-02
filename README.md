# LoongArch 计组实验一至五

实验一至五采用逐步继承的五个 Git 分支。`experiment-5` 是最终累计版本，
包含前五个实验的全部 CPU 功能；仓库的 `main` 展示这一版本。
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

克隆后可用 `git switch experiment-3` 等命令查看对应实验；如需同时打开多个
实验，可使用 `git worktree`。实验二及以后保留 `--mode stall` 与
`--mode forward` 两种测试方式。

## 打开和测试最终版本

Vivado 生成目录不在仓库中。先运行一次回归选定镜像，再使用
`vivado -mode batch -source scripts/create_vivado.tcl -tclargs remote` 创建工程，
之后打开 `build/vivado-remote/loongson.xpr`。详细步骤见 [验证说明](docs/verification.md)。
CPU 源码在 `cdp_ede_local-master/mycpu_env/myCPU/`，展开 Sources 中的
`looongson_remote_top → soc_lite → cpu` 即可找到五级流水模块。
工程创建后可直接重新打开 `.xpr`。

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

五个分支 CPU-only 综合及远程板级综合、布线、时序、bitstream 均已验收通过。
实验一至三 CPU 为 50 MHz，实验四、五实际 CPU 为 25 MHz（原 50 MHz 时序
失败已记录）；输入保持 50 MHz，timer 保持 100 MHz。实验五保留 12 条 DSP
流水优化建议，无 Error/Critical Warning。详情见 [交付总览](docs/overview.md)。
2026-11-01 校内平台使用本地位流评测 exp1 至 exp7，均为 100 分；平台最终
提交版本未设置。详见 [线上评测记录](docs/online-evaluation.md)。Vivado 生成目录、
位流和大型仿真输出不提交；早期验收报告中的“线上评测未执行”反映当时状态。
