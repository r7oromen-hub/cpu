`include "mycpu_head.v"
`timescale 1ns / 1ps

module wb_stage(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         ms_to_ws_valid,
    input  wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus,
    output wire                         ws_allowin,
    output wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    output wire [31:0]                  debug_wb_pc,
    output wire [ 3:0]                  debug_wb_rf_we,
    output wire [ 4:0]                  debug_wb_rf_wnum,
    output wire [31:0]                  debug_wb_rf_wdata
);

// 实验一：增加WB级保存最终结果、目的寄存器和PC，写回与取指/译码分属不同指令。
reg                          ws_valid;
reg  [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire                         ws_ready_go;

wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;
wire        rf_we;

assign {
    ws_gr_we,
    ws_dest,
    ws_final_result,
    ws_pc
} = ms_to_ws_bus_r;

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

// 实验一：只有有效且要求写寄存器的WB指令产生写使能；结果通过总线返回ID。
assign rf_we        = ws_valid && ws_gr_we;
assign ws_to_rf_bus = {rf_we, ws_dest, ws_final_result};

// 实验一：调试接口统一观察WB提交的PC、目的寄存器和数据，供逐条写回对拍。
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;

endmodule
