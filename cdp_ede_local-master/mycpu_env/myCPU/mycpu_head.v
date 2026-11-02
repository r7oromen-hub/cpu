`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V

`define BR_BUS_WD        33
`define FS_TO_DS_BUS_WD  64
// 实验四修改：增加mem_size(2位)和load_unsigned(1位)，ID->EXE由148增至151位。
`define DS_TO_ES_BUS_WD 151
// 实验四修改：同样的3位控制继续传至MEM，EXE->MEM由71增至74位。
`define ES_TO_MS_BUS_WD  74
`define MS_TO_WS_BUS_WD  70
`define WS_TO_RF_BUS_WD  38
`define ES_TO_DS_BUS_WD  39
`define MS_TO_DS_BUS_WD  38

// 实验四新增：内部访存宽度编码（并非指令操作码），供ID、EXE、MEM统一使用。
// WORD为32位字，BYTE为8位字节，HALF为16位半字；大小在ID译码时选定。
`define MEM_SIZE_WORD 2'b00
`define MEM_SIZE_BYTE 2'b01
`define MEM_SIZE_HALF 2'b10

`endif
