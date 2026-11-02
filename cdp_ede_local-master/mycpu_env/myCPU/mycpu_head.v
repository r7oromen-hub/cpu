`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V

`define BR_BUS_WD        33
`define FS_TO_DS_BUS_WD  64
// 实验五修改：新增mul_op(3位)+div_op(3位)，ID->EXE由151位扩展为157位。
`define DS_TO_ES_BUS_WD 157
`define ES_TO_MS_BUS_WD  74
`define MS_TO_WS_BUS_WD  70
`define WS_TO_RF_BUS_WD  38
`define ES_TO_DS_BUS_WD  39
`define MS_TO_DS_BUS_WD  38

`define MEM_SIZE_WORD 2'b00
`define MEM_SIZE_BYTE 2'b01
`define MEM_SIZE_HALF 2'b10

`endif
