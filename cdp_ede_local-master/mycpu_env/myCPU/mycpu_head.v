`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V

// 实验一：统一五级流水总线宽度，发送端打包和接收端解包必须保持字段顺序一致。
// BR为跳转标志+地址；IF->ID为指令+PC；其余总线承载各级所需控制与数据。
`define BR_BUS_WD        33
`define FS_TO_DS_BUS_WD  64
`define DS_TO_ES_BUS_WD 148
`define ES_TO_MS_BUS_WD  71
`define MS_TO_WS_BUS_WD  70
`define WS_TO_RF_BUS_WD  38

`endif
