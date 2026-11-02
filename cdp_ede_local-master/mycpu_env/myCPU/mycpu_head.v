`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V

`define BR_BUS_WD        33
`define FS_TO_DS_BUS_WD  64
`define DS_TO_ES_BUS_WD 148
`define ES_TO_MS_BUS_WD  71
`define MS_TO_WS_BUS_WD  70
`define WS_TO_RF_BUS_WD  38
// 实验二新增：EXE->ID包含有效写标志1位、load未就绪标志1位、目的寄存器5位和结果32位。
`define ES_TO_DS_BUS_WD  39
// 实验二新增：MEM->ID包含有效写标志1位、目的寄存器5位和最终结果32位。
`define MS_TO_DS_BUS_WD  38

`endif
