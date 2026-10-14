`include "mycpu_head.v"
`timescale 1ns / 1ps

module if_stage(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         ds_allowin,
    input  wire [`BR_BUS_WD       -1:0] br_bus,
    output wire                         fs_to_ds_valid,
    output wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus,
    output wire                         inst_sram_en,
    output wire [ 3:0]                  inst_sram_we,
    output wire [31:0]                  inst_sram_addr,
    output wire [31:0]                  inst_sram_wdata,
    input  wire [31:0]                  inst_sram_rdata
);

reg         fs_valid;
reg  [31:0] fs_pc;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;
wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;

assign {br_taken, br_target} = br_bus;

assign to_fs_valid    = ~reset;
assign fs_ready_go    = 1'b1;
assign fs_allowin     = !fs_valid || (fs_ready_go && ds_allowin);
// A redirect is emitted only when ID advances. The old IF instruction belongs
// to the fall-through path and must never enter ID on this same edge.
assign fs_to_ds_valid = fs_valid && fs_ready_go && !br_taken;

assign seq_pc = fs_pc + 32'd4;
assign nextpc = br_taken ? br_target : seq_pc;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h1bff_fffc;
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign fs_to_ds_bus    = {inst_sram_rdata, fs_pc};
assign inst_sram_en    = to_fs_valid && fs_allowin;
assign inst_sram_we    = 4'b0000;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

endmodule
