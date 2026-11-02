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

## Vivado 2018.3 旧 COE 登记问题

实测在把课程 2019.2 XCI 加入 2018.3 工程、升级 IP 后，工具自动登记了原 XCI
相对 COE 路径。虽然 `CONFIG.Coe_File` 随后设置到了有效的新路径，旧缺失路径
仍留在工程文件集。RAM OOC 综合能完成，但顶层综合生成的 Tcl 仍尝试添加旧
文件，报 `ERROR: [Vivado 12-172] File or Directory .../tmp/func/obj/inst_ram.coe
does not exist`，因此不能把 OOC 成功当作整体工程成功。

修复使用 `get_files -all *.coe`、`get_property NAME`、`file exists` 和
`remove_files`，只移除不存在的 COE 文件登记，保留有效新镜像；不直接修改 XPR。
创建流程在生成 IP 输出前后检查，构建流程打开已有项目后也修复。两块 RAM
自检要求 `CONFIG.Load_Init_File=true` 且 `CONFIG.Coe_File` 确实存在；仅配置
错误或初始化内容发生变化的 RAM IP 重新生成输出，其他已成功的 OOC DCP 不重置。

已有顶层 synth_1/impl_1 若 STATUS 含 ERROR/failed，会单独 `reset_run` 后重启；
过时顶层 run 也重新构建，已完整且无需刷新的 run 可复用。完成检查同时确认
STATUS 不含错误和 PROGRESS=100%，避免失败进度记录误判。实际恢复构建及
时序结果由主代理执行并追加，修复脚本提交本身不声称恢复构建已成功。

## 时钟配置与镜像内容保护

共用脚本默认 CPU 输出 50 MHz，可读取本分支 `config/clock.tcl` 中的
`cpu_clock_mhz`。实验四、五实际布线后在 50 MHz 分别出现 WNS=-1.860 ns 和
-2.007 ns，主要路径涉及 MEM 字节选择/EXE 乘法经 ID 分支判断到取指使能。
两分支将 CPU 输出设为 25 MHz，板级输入仍为 remote 50 MHz/local 100 MHz，
timer_clk 仍 100 MHz；时序约束和负 slack 失败条件不放宽。最终 25 MHz
实现结果由总览填写。现有工程发现 PLL 频率真正改变时只重置和生成 PLL 输出及
它的 OOC run，再重建顶层，复用未变的 RAM DCP。

RAM 镜像路径相同不代表内容相同。每次生成 RAM 后，将实际选用 COE 的完整
二进制文件保存为项目 IP 目录中的 `init_snapshot.coe`。后续 build 比较内容；
如果同一路径的 COE 被新测试镜像替换，只 reset_target/generate 改变的 RAM、
重置对应 OOC run 和顶层，不重复综合另一块 RAM。写入快照前检查生成 `.mif`
每个 32 位二进制字与当前 COE vector 完全一致。

旧工程没有快照时，先比较生成 MIF 与当前 COE 的全部字及数量，一致后才能
种下快照并复用已有输出；缺文件、字数不完整或任何值不同都会重建，不能凭
路径和修改时间假设镜像正确。COE radix 支持 2/10/16，并拒绝超出 32 位的值。

`python tests/test_vivado_helpers.py` 的 mock Tcl 检查实测通过，覆盖：PLL
不变时复用、变频仅重置 PLL、旧工程完整 MIF 种快照、同路径内容替换只重建
受影响 RAM、不完整 MIF 拒绝存快照、WPWS/报告缺失失败、DRC 违规失败。
Windows Tcl 的 `scan %x` 可将 ffffffff 读成负数，因此字比较使用经格式检查的
宽整数表达式，真实 32 位全 1 值不会被误判。

`scripts/check_vivado_reuse.tcl` 只读打开已有工程并检查 RAM CONFIG、完整 MIF
和 PLL 频率，不修改 IP、输出或运行状态。2026-10-14 在实际 Vivado 2018.3
experiment-5 工程中返回 0，inst/data 均 `RAM_REUSE_GUARD_PASS`，最终
`VIVADO_REUSE_API_PASS`。它不是 FPGA 上板测试。

构建最终通过条件还包括无阻断 DRC 违规、global timing summary 的 WPWS>=0 且
脉宽失败端点数为 0；缺失或不完整报告失败。setup/hold 的原负 slack 检查保持，
不得仅凭 bitstream 文件存在宣称时序达标。

## DSP 建议警告与 DRC 严格例外

实验五真实 Fully Routed 设计出现 12 条 DSP 流水建议：DPIP-1、DPOP-1、
DPOP-2 各 4 条，全部原始 Severity=Warning。它们建议给 DSP 输入、PREG 和
MREG 增加内部流水级；当前乘法按实验要求采用 EXE 单周期结果，实际 25 MHz
setup/hold 已通过，因此不为消除建议警告改变指令流水时序。

Vivado 2018.3 只读 API 实测确认违规对象的 `CHECK` 分别是这三个编号，
`SEVERITY` 都为 Warning，`IS_WAIVED=0`。`lab_check_drc` 仅接受这三个已审查
check 且实际严重程度恰好为 Warning；未知 check、未知严重程度、Error、
Critical Warning 均失败。检查逐条打印保留的建议及总数，完整 report 不抑制，
不修改 SEVERITY、不加 waiver。实验五不是“零 DRC”，是 12 条明确保留的
建议警告、零阻断违规。独立只读检查入口为 `scripts/check_vivado_drc.tcl`。

新增 mock 检查同时断言三个建议性 Warning 可接受，而任意未审查 Warning
以及同 check 升为 Error/Critical Warning/空或未知严重程度均不能通过。

## Mock Tcl 测试依赖

测试需要有 `tkinter/_tkinter` 的 Python 和版本匹配、包含 `init.tcl` 的 Tcl
运行库，不需要图形窗口。WSL 精简 Python 可能没有 tkinter，某些重定位的
bundled Python 有 `_tkinter` 却没有可用 Tcl 初始化库；这些情况以返回码 2
明确报依赖错误，不跳过测试或标 PASS。脚本会先使用 Python 默认 Tcl，再搜索
sys.prefix、sys.base_prefix 和 PATH 中已安装 Python/Tcl 的标准运行库位置，
让 Tcl 本身检查兼容性，没有硬编码本机目录，也不会安装软件。

本机实测成功环境为 `F:\anaconda\python.exe`，Tcl 8.6.15，运行库
`F:\anaconda\Library\lib\tcl8.6`，无需设置 TCL_LIBRARY。从仓库目录执行：

```powershell
& 'F:/anaconda/python.exe' tests/test_vivado_helpers.py
```

当前共 8 项测试，实测全部通过。源 Tcl 由 Python 按测试文件自身的绝对位置
读取后交给 Tcl，避免中文文件名被旧 Tcl 误解，也支持从其他当前目录调用。
沙箱中 Python 写临时文件与原生 Tcl 读临时文件可能处于不同重定向视图；复跑
应在宿主终端执行，代理环境必要时使用经批准的宿主执行。不能将该环境造成的
文件不可见误认为工程保护测试通过，也不能为此跳过用例。
