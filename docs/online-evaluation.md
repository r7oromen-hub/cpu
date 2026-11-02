# 线上自动评测记录

日期：2026-11-01。平台：http://202.204.62.155:8000/judge

| 平台题目 | 任务 ID | 状态 | 分数 | 本次提交文件 |
| --- | ---: | --- | ---: | --- |
| exp1 | 6835 | Finished | 100 | exp1.bit |
| exp2 | 6841 | Finished | 100 | exp2-stall.bit |
| exp3 | 6836 | Finished | 100 | exp3-forward.bit |
| exp_4 | 6843 | Finished | 100 | exp4.bit |
| exp_5 | 6837 | Finished | 100 | exp5.bit |
| exp_6 | 6838 | Finished | 100 | exp6.bit |
| exp_7 | 6839 | Finished | 100 | exp7.bit |

以上文件为本次实际提交的本地位流副本。exp2 使用纯阻塞，exp3 使用前递；exp4 使用 ex4 镜像。exp4 结果详情显示 FPGA 板 19088、Passed testpoint 0x1d（29），原始截图与位流保存在本地，不纳入仓库。

平台提示最终提交版本只能选择在线编译结果；本次是本地位流评测，未标记最终版本。页面显示截止时间在 2025 年，正式提交是否开放需以平台及教师要求为准。exp_8、exp_9 要求异常和中断支持，超出此项目当前实现范围，未评测。

## 文件 SHA-256

```text
CA90526E00F2F633CF43D4043C978A29B40821EBFF14B90FBFFCCC38CC7F9ECC  exp1.bit
48C975B5BFDDF6E3424B13F01EC300FF59042E3918BD67DD867549648D0CB996  exp2-stall.bit
E888286AF3AFE43518BF58098271BB1FF50CB4518D90FDB1B27E6F92044EEF43  exp3-forward.bit
92695F91254EFF32EBB02CD78CC71B5EFCF50C57F1C52DF07433ED620748AE8E  exp4.bit
F30216EB4E51B846AC7A3739FF693F142B60501193A37D2B35A0EE95191A256C  exp5.bit
1F814E2966B4C2D8F6E789C0DEED44E3D0D1CFD0ABFBAA446512E355A9E38B85  exp6.bit
B2F8E7049FBE67FF19923000C5C6BD537A65827E952AEC8720A8354B59BE898E  exp7.bit
```
