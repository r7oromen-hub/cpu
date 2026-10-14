# 实验二：RAW 阻塞、前递、控制冲突和 BaseRAM 接口

## 范围和分支

- Git 分支：`experiment-2`，继承实验一的五级流水 CPU。
- 按指导书第二章实现，课程镜像对应 `ex2_obj`（阻塞）和 `ex3_obj`（前递）。实验号不能与镜像号混用。
- 工作目录位于 `计组课设la版/branches/experiment-2`，名字带 `1` 的对照目录未修改。
- 默认 `FORWARDING=1`。编译宏 `STALL_ONLY` 将 `mycpu_top` 默认参数改为 `0`，也可显式覆盖参数。

## 修改文件和设计

| 文件 | 修改内容 | 原因 |
| --- | --- | --- |
| `myCPU/mycpu_top.v` | 增加 FORWARDING 参数、连接 EXE/MEM→ID 前递总线 | 一套流水结构同时支持阻塞与前递验收 |
| `myCPU/mycpu_head.v` | EXE→ID 39 位、MEM→ID 38 位总线宏 | 传递有效写使能、目的寄存器、结果及 EXE load 标志 |
| `myCPU/id_stage.v` | 真实源寄存器掩码、RAW 检测、前递选择、分支发射条件 | 解决寄存器 RAW、load-use 和控制冲突 |
| `myCPU/if_stage.v` | 跳转当周期屏蔽旧 IF→ID valid | 清空已经取出的错误顺序路径指令 |
| `myCPU/exe_stage.v` | 输出前递信息，访存只在本级向 MEM 传递时发起，复位禁用写 | 避免无效级和将来下游阻塞造成重复 store |
| `myCPU/mem_stage.v` | 输出 load/ALU 最终结果给 ID | load 数据在同步 RAM 返回后才可使用 |
| `myCPU/BaseRAM_control.v` | 新增低有效外部 SRAM 适配器 | 处理地址截取、控制极性、双向总线和字节掩码 |
| `tests/lab2_hazards_tb.v` | 新增指令序列及逐条参考写回断言 | 覆盖流水相关和错误路径副作用 |
| `tests/base_ram_tb.v` | 新增外部 SRAM 模型与断言 | 验证接口电平、地址、三态及读保持 |
| `scripts/run_lab2_directed.sh` | 编译并运行两个流水模式及 BaseRAM 测试 | 提供可复现的定向验收入口 |

表中 `myCPU` 的完整仓库内路径为 `cdp_ede_local-master/mycpu_env/myCPU`。

### 阻塞模式

ID 仅对指令实际读取的寄存器比较 EXE、MEM、WB 有效目的寄存器。零号寄存器及不写寄存器的指令不产生相关。遇到任何 RAW 时，`ds_ready_go=0`；ID 指令保持，EXE/MEM/WB 继续流动。WB 命中也阻塞，等写回时钟沿完成后再从寄存器堆读取。

### 前递模式

按照 EXE > MEM > WB 的优先级选择最新结果。EXE 的普通 ALU 结果可直接旁路，EXE 的 load 结果尚未返回，因此命中时阻塞一周期。load 到 MEM 后，通过同步 SRAM 返回的数据前递。较新的 EXE load 命中时，不能误用较老 MEM/WB 的同名寄存器值。

### 真实源寄存器和写使能

- `rj`：双寄存器算术逻辑、立即移位、addi、load、store、jirl 和条件分支读取。
- 第二读端口：双寄存器算术逻辑使用 `rk`，store 和条件分支使用 `rd`。
- `lu12i.w`、`b`、`bl` 没有普通源寄存器。addi、立即移位和 load 的立即数字段不可当成 `rk` 比较。
- `jirl` 虽然 ALU src1 选 PC，跳转目标仍然读取 rj，因此必须检测/前递 rj。
- `gr_we` 从已识别的写寄存器指令正向生成，避免未知编码误写寄存器。

### 控制冲突和同步 SRAM 时序

`br_taken` 只有在 `ds_to_es_valid && es_allowin && !reset` 时有效。被 RAW 阻塞的分支保持在 ID，不发出重复跳转。跳转当天，IF 将错误顺序路径的 `fs_to_ds_valid` 置零，并向同步指令 RAM 发出目标地址；下一周期目标指令与更新的 fs_pc 对齐。ID 阻塞时 IF 的 RAM en 关闭，RAM 输出保持，PC 同时保持。

数据 RAM 在 EXE→MEM 的时钟沿捕获请求。load 数据在 MEM 使用，并可前递到 ID；该分支没有可变等待时长的 RAM 总线协议。

### BaseRAM 控制器

接口名保持指导书 2.4.3 的形式，可放在 FPGA 顶层 CPU SRAM-like 接口与外部 BaseRAM 引脚之间。地址使用 CPU 地址 `[21:2]`，低两位为字节偏移。读时 CPU 释放双向总线，外部 RAM 驱动；写时 CPU 驱动，RAM 输出使能关闭。写字节使能为 `~inst_sram_we`。

对指导书示例做了两处完善：未选中时关闭 oe/ce/we 和所有 byte enable，并且不锁存浮空数据；复位读寄存器清零，同时关闭外部 RAM。测试中的高阻用于外部 inout，总线读响应寄存器使用确定的 0 复位值，方便可综合实现及调试。

当前 `soc_bram` 面向板内 Xilinx BRAM，仍直接连接 SRAM-like 接口。BaseRAM 控制器是另外的外部异步 SRAM 适配层，不应插进现有 BRAM 路径或与远程板约束混用。

## 问题记录

1. 基线 ID 的 ready_go 恒为 1，连续 RAW 会读取旧寄存器值。增加阻塞/前递解决。
2. 基线分支只用 ds_valid 限定；加入 RAW 阻塞后会在等待时不断重定向。现在只有 ID 真正向 EXE 发射时跳转。
3. 基线取指错误路径仍能进入 ID，产生 store 或 RF 写副作用。IF→ID 的 valid 在跳转时被清除。
4. 指令编码的立即数字段与 rj/rk 位置重叠，若无真实源掩码会产生假依赖。定向测试使用刻意重叠的 addi/lu12i 编码断言不会阻塞。
5. 多条旧指令写同一个寄存器时，较老结果不可覆盖最新前递；EXE 优先，并对 EXE load 加阻塞。
6. 外部 SRAM 示例在未选中时仍可能采样高阻读总线；增加 selected/read 条件和确定复位。

## 定向测试

在仓库根目录运行（Linux/WSL 内有 Icarus Verilog 12）：

```bash
bash scripts/run_lab2_directed.sh
```

Windows PowerShell 可调用：

```powershell
wsl -d Ubuntu -- bash '/mnt/c/Users/nwulk/Desktop/课程与项目/计组/计组课设la版/branches/experiment-2/scripts/run_lab2_directed.sh'
```

2026-10-14 实际输出：

```text
LAB2_HAZARDS PASS writes=23 cycles=39 stalls=2 stores=2 redirects=5
LAB2_HAZARDS PASS writes=23 cycles=68 stalls=31 stores=2 redirects=5
BASE_RAM PASS address/polarity/byte-mask/tri-state/held-response
```

23 条有效寄存器写回逐条比较 PC、目的寄存器及数据。覆盖连续 RAW、store 数据依赖、两次 load-use、EXE/MEM/WB 优先选择、覆盖同名寄存器的 load、r0、不使用字段假依赖、条件分支 taken/not-taken、b/bl/jirl 和错误路径 store/RF 清空。存储器断言只允许两次正确 store。前递模式恰好两个气泡；阻塞模式实际产生 31 个等待周期。

BaseRAM 测试覆盖复位、未选中、读、部分写、地址截取、低有效控制、字节掩码、读写总线驱动互斥及输出保持。

## 完整功能回归与实物验收

使用独立课程参考核 `gettrace/src/myCPU/SimpleLACoreWrapRAM.v` 重新生成 golden trace，再编译本分支 CPU 进行完整写回比对：

```bash
python3 scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj --mode forward
python3 scripts/run_regression.py --image ex2_obj --mode stall
```

Windows 可使用提供的 Python 环境运行同一脚本（脚本自动转交 WSL）：

```powershell
& 'C:\Users\nwulk\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj --mode forward
& 'C:\Users\nwulk\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' scripts/run_regression.py --image ex2_obj --mode stall
```

2026-10-14 完整测试结果：

| 镜像 | 模式 | 功能点 | 逐条写回比对 | 结果 |
| --- | --- | --- | --- | --- |
| ex1_obj | 前递 | 20/20 | 46,534/46,534 | PASS |
| ex2_obj | 前递 | 20/20 | 46,534/46,534 | PASS |
| ex3_obj | 前递 | 20/20 | 46,534/46,534 | PASS |
| ex2_obj | 纯阻塞 | 20/20 | 46,534/46,534 | PASS |

`test-results/regression-forward-ex1_obj-ex2_obj-ex3_obj.json` 和 `test-results/regression-stall-ex2_obj.json` 保存镜像 SHA256、验证模式和比对数量。原始仿真输出位于被 Git 忽略的 `test-results/raw/`；定向输出位于 `test-results/lab2-directed/`。

提供的 ex2_obj 与 ex3_obj 的 inst/data mif/coe 文件 SHA256 均相同，因此两种要求通过不同编译模式验收。定向测试中前递只有两个 load-use 等待周期、纯阻塞产生 31 个等待周期，直接证明两种实现的控制差异。

共享参考测试平台在完成标记以后有一次已关闭描述符 `$fdisplay` 警告；golden 文件生成、全部启用写回数量和 DUT 的完整对拍均已通过，该警告不是 CPU 失败。没有修改独立参考核心。

本机尚未运行 Vivado 综合/实现、时序报告、FPGA 上板或线上测评。本记录不将这些未执行项目标为通过。外部异步 BaseRAM 的具体时钟频率及板级时序约束还需要真实目标板验收。
