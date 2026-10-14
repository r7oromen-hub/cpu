# LoongArch 计组实验一至五

本仓库以此前实现的 `ex1_obj` 五级流水 CPU 为起点。工作目录为
`计组课设la版/计组课设la版`，不修改名字带 `1` 的对照目录。

## 分支与验收范围

实验按《计组课设指导书LA版-2025》前五章编号，不能与 `exN_obj` 镜像编号混淆。

| Git 分支 | 实验内容 | 课程功能测试 |
| --- | --- | --- |
| experiment-1 | 不考虑冲突的五级流水 | ex1_obj |
| experiment-2 | RAW 阻塞、控制冲突清空、EXE/MEM/WB 前递 | ex2_obj、ex3_obj |
| experiment-3 | 算术逻辑和条件转移指令 | ex4_obj、ex5_obj |
| experiment-4 | 字节/半字 load 和 store | ex6_obj |
| experiment-5 | 乘法和迭代除法 | ex7_obj |

各分支逐步继承前一实验，最终分支保留全部功能。实验二保留可选择的纯阻塞实现与前递实现，分别验证。

## 源码

- CPU：`cdp_ede_local-master/mycpu_env/myCPU/`
- SoC：`cdp_ede_local-master/mycpu_env/soc_verify/soc_bram/`
- 独立参考核：`cdp_ede_local-master/mycpu_env/gettrace/src/`
- 课程镜像：`for_test_obj/ex1_obj` 至 `for_test_obj/ex7_obj`
- 远程 FPGA 适配：`remote/`
- 实验记录：`docs/`

Vivado 生成目录和仿真输出不提交。没有实际运行过的 Vivado 综合、时序、上板或线上评测不得写为通过。
