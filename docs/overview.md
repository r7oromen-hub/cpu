# 实验一至五交付总览

更新日期：2026-10-14。此总览位于最终累计版本 `experiment-5`，逐实验的详细修改、
实现问题、控制时序和定向测试在 [实验一](experiment-1.md)、[实验二](experiment-2.md)、
[实验三](experiment-3.md)、[实验四](experiment-4.md)、[实验五](experiment-5.md)。

## 目录和分支

指定实验根目录：`C:\Users\nwulk\Desktop\课程与项目\计组\计组课设la版`。
每个实验单独使用一个 branch，并已检出到同名工作目录：

```text
计组课设la版/
├─ 实验导航.md                    用户入口（Git 库外）
├─ 计组课设la版/                  Git 主工作目录，保留 baseline
└─ branches/
   ├─ experiment-1/              分支 experiment-1
   ├─ experiment-2/              分支 experiment-2，继承实验一
   ├─ experiment-3/              分支 experiment-3，继承实验二
   ├─ experiment-4/              分支 experiment-4，继承实验三
   └─ experiment-5/              分支 experiment-5，最终累计版本
```

另一个名字带 `1` 的原始对照目录未修改。直接打开要学习或提交的实验目录即可，
不需要执行 `git switch experiment-N`。这些分支已经被对应 worktree 使用，切换
其他 worktree 正在使用的分支通常会被 Git 拒绝。

## 实验编号与测试镜像

实验编号按指导书前五章；`exN_obj` 是测试镜像编号，两者不是一一对应。

| 实验 / 分支 | 新增内容 | 本实验对应镜像 |
| --- | --- | --- |
| 实验一 / experiment-1 | 20 条基础指令的五级流水、同步 SRAM、valid/allowin | ex1_obj |
| 实验二 / experiment-2 | RAW 阻塞、分支错误路径清空、EXE/MEM/WB 前递、load-use 等待 | ex2_obj、ex3_obj |
| 实验三 / experiment-3 | 算术逻辑、立即数、寄存器移位、PC 相对运算和条件分支扩展 | ex4_obj、ex5_obj |
| 实验四 / experiment-4 | 字节/半字 load、符号与零扩展、字节/半字 store 和写掩码 | ex6_obj |
| 实验五 / experiment-5 | 低位/高位乘法、有/无符号迭代除法和余数、多周期 EXE | ex7_obj |

只查看某实验自己的实现时，使用对应 worktree；查看全部功能时使用 experiment-5。

## 如何打开工程和源码

以实验五为例，Vivado 中 `File → Project → Open` 选择：

```text
C:\Users\nwulk\Desktop\课程与项目\计组\计组课设la版\branches\experiment-5\build\vivado-remote\loongson.xpr
```

其他实验只需把路径中的 `experiment-5` 改为对应编号。关闭后仍打开 `.xpr`，
不要重新运行 create_project。创建脚本会拒绝覆盖已有项目，构建脚本可恢复失败
的顶层运行，并复用正确的 IP 输出。

CPU 源码相对工作目录在 `cdp_ede_local-master/mycpu_env/myCPU/`；
Sources 层次为 `looongson_remote_top → soc_lite → cpu`，五级实例是
`u_if_stage/u_id_stage/u_exe_stage/u_mem_stage/u_wb_stage`。第三、四、五实验
新增功能主要在 ID、EXE、MEM；实验五另有 `iterative_divider.v`。

远程 bitstream 完成后的预期文件位置：

```text
build/vivado-remote/loongson.runs/impl_1/looongson_remote_top.bit
```

这里列的是输出位置，是否已通过最终实现和时序检查以以下验收记录为准。

## 如何重新运行测试

在对应 worktree 的 PowerShell 中执行。Python 脚本在 Windows 自动调用 WSL
Ubuntu；WSL 中需有 Python 3、iverilog、vvp，不需要 Vivado 才能运行软件仿真。

```powershell
# 实验一工作目录
python scripts/run_regression.py --image ex1_obj

# 实验二工作目录：分别检查阻塞和前递
python scripts/run_regression.py --image ex2_obj --mode stall
python scripts/run_regression.py --image ex3_obj --mode forward

# 实验三工作目录
python scripts/run_regression.py --image ex4_obj ex5_obj --mode forward

# 实验四工作目录
python scripts/run_regression.py --image ex6_obj --mode forward

# 实验五工作目录：完整累计回归
python scripts/run_regression.py --image ex1_obj ex2_obj ex3_obj ex4_obj ex5_obj ex6_obj ex7_obj --mode forward
python scripts/run_regression.py --image ex7_obj --mode stall
```

在 WSL 中进入相应目录，还可执行 `bash scripts/run_lab2_directed.sh` 至
`run_lab5_directed.sh`；各脚本及期望输出见对应实验文档。汇总在
`test-results/regression-*.json`，有界原始日志与 trace 在 `test-results/raw/`。
脚本会重新编译独立课程参考核，比较所有启用写回；超时、非零返回、功能点不足、
trace 缺失/多余或任意 PC/寄存器号/数据不一致都会失败，不只匹配最后的 PASS 文本。

每次选择镜像会更新本 worktree 的 `cdp_ede_local-master/mycpu_env/func/obj/`。
不要在同一个 worktree 同时运行不同镜像测试；重新选择镜像后，Vivado RAM 输出
和顶层 runs 必须重新生成，才能得到匹配的新 bitstream。

## 已完成的验证

以下是 experiment-5 的累计前递模式实测，不仅是对应新增功能的局部测试。

| 镜像 | 功能点 | 全部启用写回 | 结果 |
| --- | --- | --- | --- |
| ex1_obj | 20/20 | 46,534/46,534 | PASS |
| ex2_obj | 20/20 | 46,534/46,534 | PASS |
| ex3_obj | 20/20 | 46,534/46,534 | PASS |
| ex4_obj | 29/29 | 62,377/62,377 | PASS |
| ex5_obj | 33/33 | 71,332/71,332 | PASS |
| ex6_obj | 39/39 | 79,750/79,750 | PASS |
| ex7_obj | 46/46 | 86,846/86,846 | PASS |

证据：[完整累计回归](../test-results/regression-forward-ex1_obj-ex2_obj-ex3_obj-ex4_obj-ex5_obj-ex6_obj-ex7_obj.json)。
纯阻塞 ex7 也达到 46/46 功能点、86,846 条写回全部一致，见
[纯阻塞回归](../test-results/regression-stall-ex7_obj.json)。
独立除法器 2,243 组测试通过，乘除法流水两种模式各比较 671 条写回，包含
384 次固定种子随机乘法对比；下游阻塞、完成结果保持、单次 store 和复位中断
测试通过，见 [定向测试摘要](../test-results/lab5-directed.json)。前序实验的
定向测试在最终版本中也重跑通过。

所有五个分支已完成 CPU-only Vivado 2018.3 综合。它验证 CPU RTL 可综合，
不等同于完整板级实现、最终时序或实际上板。

| 分支 | CPU-only 综合 | 远程板级实现 / 时序 / bitstream 最终验收 |
| --- | --- | --- |
| experiment-1 | PASS | 已生成过 bitstream；修正未用时钟 XDC 后重验中 |
| experiment-2 | PASS | 已生成过 bitstream；修正未用时钟 XDC 后重验中 |
| experiment-3 | PASS | 构建中，等待最终结果 |
| experiment-4 | PASS | 构建中，等待最终结果 |
| experiment-5 | PASS | 构建中，等待最终结果 |

此表是整理交付时的状态，主代理在构建完成后填写实际结果、时序指标和报告位置。
实际 FPGA 上板和校内平台线上评测未执行，不标 PASS。线上提交需要教师提供的
平台入口和账号，再上传所选镜像对应的最终 `.bit`。

## 工程问题记录

共用验证和工程配置细节在 [验证说明](verification.md)。本轮实际处理了：

- RAM 模型 wdata 方向和 en gating、TB 错误返回码与完整 trace 检查。
- 工程遗漏 stage/header、创建目录依赖和 `-force` 覆盖风险。
- Vivado 2018.3 对中文目录的 `file normalize` 及 alias 路径异常；通过
  `CPU_LAB_ROOT` 保留 ASCII worktree alias，避免工具解析真实中文路径时损坏。
- XCI 加入/升级后仍登记旧缺失 COE，导致顶层综合 `Vivado 12-172`；只清理
  不存在的 COE 记录，保留有效新镜像和已成功的 IP OOC checkpoint。
- `CONFIG.Coe_File` 若为相对路径，必须相对 XCI 所在目录解析，不能用当前
  工作目录检查；`lab_resolve_ip_coe` 统一解析并确认 Load_Init_File 已启用。
- 远程未使用的 11 MHz 和手动时钟网络被综合优化，原 XDC 对不存在网络设置
  routing exception 会报警；为这些网络加存在性判断后再设置约束。

功能范围及继承限制见各实验文档；尤其任意 warm reset 的首个时钟沿可能仍有
旧 WB 写回，当前验收不声称通用寄存器堆复位清零。

## 如何查看每个实验改了什么

直接在所需 worktree 执行 `git log` 或 `git diff`，无需切换分支。实验五目录例子：

```powershell
git log --oneline -8
git diff experiment-4..experiment-5 -- cdp_ede_local-master/mycpu_env/myCPU docs/experiment-5.md
git show --stat HEAD
```

比较实验二时用 `experiment-1..experiment-2`，实验三用
`experiment-2..experiment-3`，实验四用 `experiment-3..experiment-4`。
实验一 CPU 在保留基线时已经存在，其历史修改清单在 `docs/experiment-1.md`，
不能用本轮提交统计误认为它没有做五级流水。
