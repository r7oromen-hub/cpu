# 共用验证和 Vivado 工程脚本

所有命令均从本分支的仓库根目录执行。每个分支使用自己的 `func/obj` 和
`test-results/raw`，不要在同一个 worktree 中同时运行两个镜像回归。

## Icarus 回归

Windows（WSL Ubuntu 中须已安装 Python 3、iverilog、vvp）：

```powershell
python scripts/run_regression.py --image ex1_obj
python scripts/run_regression.py --image ex2_obj --mode stall
python scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj --mode forward
```

Linux/WSL 使用 `python3` 执行同一脚本。`--mode stall` 定义 `STALL_ONLY`；
默认 `forward` 不额外定义宏。`--define NAME` 可以附加其他编译宏。

脚本每次复制指定 `for_test_obj/exN_obj` 的四份 RAM 镜像至 `mycpu_env/func/obj`，
记录 SHA-256，然后分别重新编译课程独立参考核和被测五级流水 CPU。参考核
`gettrace/src/myCPU/SimpleLACoreWrapRAM.v` 没有改动；只完善了参考环境的
镜像路径、结束与错误报告。参考核采用组合读取内存，被测 SoC 采用真实同步
RAM；二者数据通路相互独立，不以被测 CPU 生成自己的预期结果。

通过条件同时包括：子进程返回 0、参考核完成、课程规定的所有功能点按序完成、
被测核最终 PASS、全部启用的参考写回被逐条比较。课程功能点总数：
`ex1=20, ex2=20, ex3=20, ex4=29, ex5=33, ex6=39, ex7=46`。
对拍包括 PC、目的寄存器号和按字节写使能屏蔽后的写回数据。

每个子进程默认超时 240 秒，可用 `--timeout` 调整。错误、trace 提前耗尽、
提前结束、残留有效参考记录均 `$fatal(1)`；禁用交互式 `$stop`，失败不能伪装
为返回码 0。原周期性进度输出仅在 `+VERBOSE` 下启用，每份原始日志上限
2 MB，默认不开启 VCD。结果摘要写入 `test-results/regression-*.json`；原始
编译/运行日志、仿真可执行文件和 trace 在被 gitignore 的 `test-results/raw/`。

中文路径下 Icarus 的 packed-string `$fopen/$readmemb` 会拒绝非 ASCII 字节。
运行文件使用输出目录的相对 ASCII 路径，Python/编译器源文件路径仍可为中文。

## RAM 模型修复

`soc_bram/testbench/sync_ram.v` 原来将 `wdata` 错误声明成输出，修改为输入。
每个字节写入增加 `en && we[i]` 限定；读数据只在使能时于时钟沿更新，未改成
组合 RAM。新增 `INST_MIF`、`DATA_MIF` plusarg，未传入时保持课程默认路径。

## Vivado

```powershell
& 'F:\vivado\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts/create_vivado.tcl -tclargs local
& 'F:\vivado\Vivado\2018.3\bin\vivado.bat' -mode batch -source scripts/build_vivado.tcl -tclargs remote 4
```

本地工程位于 `build/vivado-local/loongson.xpr`，远程工程位于
`build/vivado-remote/loongson.xpr`。创建脚本拒绝覆盖已经存在的工程，关闭后直接
打开 `.xpr`。旧 `soc_bram/run_vivado/create_project.tcl` 改为定位自身所在目录并
调用统一创建脚本，避免当前目录不同、流水文件漏加和 `-force` 覆盖的问题。

工程显式添加全部 CPU `.v`，将 `mycpu_head.v` 标记为 Verilog Header，加入 include
目录，并设置综合/仿真顶层。各 IP 复制到生成目录再修改，保持源 XCI 独立；
本地 PLL 输入 100 MHz、远程 50 MHz；两块 RAM 均使用当前所选镜像的 COE。
远程仅加入 `remote/loongson_remote.xdc` 和两个适配模块，综合顶层按课程拼写为
`looongson_remote_top`。本地顶层是 `soc_lite_top`，仿真顶层都是 `tb_top`。

构建脚本等待综合及生成 bitstream 完成，保存 timing/utilization/DRC 报告，检查
setup/hold slack。更换镜像后已有工程的 RAM IP 必须重新生成输出并 Reset Runs，
或另建项目目录；不能把旧 bitstream 当作新镜像结果。线上评测还需要教师提供的
平台入口和账号，以及实际上传和平台结果；本地仿真或 Vivado 完成不能替代它。

当前 Vivado 流程由主代理统一运行并记录实测结果；脚本本身不代表综合或上板通过。

Vivado 2018.3 在中文目录上执行 `file normalize` 可能破坏路径，包括 ASCII
junction 指向中文目录的情况。可在调用前将 `CPU_LAB_ROOT` 设置为本 worktree
的绝对 ASCII junction 路径；脚本会按原样使用该路径，不再 normalize。
例如主代理统一验证创建的临时 alias，设置 `$env:CPU_LAB_ROOT` 后再运行 batch。
这个变量应指向单个实验 worktree，不是整个多分支的任务目录。
