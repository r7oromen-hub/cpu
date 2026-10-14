# 实验四：字节和半字访存指令

工作分支：`experiment-4`，基于实验三完整实现与验证分支 `7e7a559`。修改只在本实验工作树，名字带 `1` 的对照目录不参与实现。

## 要求与数据通路

依据《计组课设指导书 LA 版 2025》PDF 第 25-26 页以及《龙芯架构 32 位精简版参考手册》2.2.4.1 节，增加 `ld.b/ld.h/ld.bu/ld.hu/st.b/st.h`。沿用原有地址计算：rj 加符号扩展 si12。在 EXE 发起同步 SRAM 访问，在 MEM 选择对应字节或半字并扩展，WB 写回，MEM 前递送出相同的扩展结果。

LoongArch32 精简版使用小端序：地址低 2 位为 `00/01/10/11` 时，分别对应返回字的 `[7:0]/[15:8]/[23:16]/[31:24]`。

| 指令 | MEM 读取/扩展 | EXE store mask |
| --- | --- | --- |
| `ld.b` | 对应字节符号扩展 | 0000 |
| `ld.bu` | 对应字节零扩展 | 0000 |
| `ld.h` | 地址偏移 0 或 2 的半字符号扩展 | 0000 |
| `ld.hu` | 地址偏移 0 或 2 的半字零扩展 | 0000 |
| `st.b` | 不写通用寄存器 | 0001/0010/0100/1000 |
| `st.h` | 不写通用寄存器 | 0011/1100 |

store 数据用低 8/16 位分别复制到 4 个字节或 2 个半字，由字节写使能选出目标通道。未选中的 SRAM 字节保留原值，`st.w` 保持 1111 写使能及完整原数据。

## 修改清单

- `myCPU/id_stage.v`：增加六条访存译码；统一 load/store 指令分组；地址计算、源使用掩码、写寄存器/访存许可覆盖新增指令。load 只读取 rj，store 读取 rj 和 rd。增加 2 位访存大小和 1 位无符号 load 标记。
- `myCPU/mycpu_head.v`：增加 `MEM_SIZE_WORD/BYTE/HALF` 常量；ID→EXE 总线宽度由 148 改为 151，EXE→MEM 由 71 改为 74；其他总线宽度不变。
- `myCPU/exe_stage.v`：解包并传递访存格式；用地址低位产生字节写掩码和复制数据，保持仅在有效 EXE→MEM 发射时发生访存。
- `myCPU/mem_stage.v`：按照有效地址低 2 位将返回字移位，再选低 8/16 位并符号/零扩展；原有 ALU 与 word load 结果保持原行为。
- `tests/load_store_tb.v`：直接 CPU+同步 SRAM 定向测试，检查每条写回的 PC、寄存器与数据，同时检查实际 store 地址、字节掩码、每个选中通道的数据及最终相邻内存未被覆盖。
- `scripts/run_lab4_directed.sh`：forward 与 stall 双模式定向仿真。

## 问题与边界记录

1. load 的最终数据必须在 MEM 格式化后才可前递，不能前递 EXE 的地址。`res_from_mem` 现在覆盖所有 load，保持实验二的 load-use 气泡。
2. 同一条指令的访存大小和 unsigned 标志需要与地址一同通过流水寄存器；直接使用 ID 当前指令控制 MEM 会串指令。
3. 仅更改字节写使能而不排列写数据，会让地址偏移 1/2/3 的 store 写入错误字节。
4. ld.b/ld.h 的符号位分别是所选字节 bit 7 和所选半字 bit 15，不能使用整个返回字 bit 31。
5. 测试与课程镜像使用自然对齐的 half/word 访问。未对齐访问的 ALE 异常属于后续异常处理系统；此阶段未实现异常寄存器或 trap 路径，不将其声明为完整特权 ISA。

## 定向验证

2026-10-14 实际运行结果，forward 与 stall 模式均通过：

```text
LOAD_STORE PASS writes=68 stores=8 cycles=401
```

401 周期包含完成后保留的等待周期，用于发现重复写和额外副作用，不是性能结论。覆盖四个字节通道的正/负符号扩展和零扩展、两个自然对齐半字、byte/half/word 部分覆盖、负地址偏移、连续 store 数据/地址前递、load-to-store 和 load-to-address 相关。

实验二 hazard/BaseRAM 与实验三 ISA 定向测试也在本分支重新通过：23 条 hazard 写回，43 条新增 ISA 写回；forward/stall 均通过。

复现：

```bash
bash scripts/run_lab4_directed.sh
python3 scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj ex4_obj ex5_obj ex6_obj --mode forward
python3 scripts/run_regression.py --image ex6_obj --mode stall
```

## 完整镜像与硬件验证

2026-10-14 完整 forward 回归全部通过，参考是课程独立 `gettrace` 核，完整核对写回 PC/寄存器/值与功能点序列：

| 镜像 | 功能点 | 有效写回逐条一致 |
| --- | ---: | ---: |
| `ex1_obj` | 20/20 | 46,534 |
| `ex2_obj` | 20/20 | 46,534 |
| `ex3_obj` | 20/20 | 46,534 |
| `ex4_obj` | 29/29 | 62,377 |
| `ex5_obj` | 33/33 | 71,332 |
| `ex6_obj` | 39/39 | 79,750 |

JSON 汇总：`test-results/regression-forward-ex1_obj-ex2_obj-ex3_obj-ex4_obj-ex5_obj-ex6_obj.json`。`ex6_obj` 纯阻塞模式正在进行，完成后补入结果。详细原始日志和参考轨迹在忽略的 `test-results/raw/` 内。

尚未宣称 Vivado 综合、时序、实物上板或线上测评通过。这些由主任务集中处理并另行记录。
