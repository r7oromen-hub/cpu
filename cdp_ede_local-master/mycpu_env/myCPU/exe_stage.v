`include "mycpu_head.v"
`timescale 1ns / 1ps

module exe_stage(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         ms_allowin,
    input  wire                         ds_to_es_valid,
    input  wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus,
    output wire                         es_allowin,
    output wire                         es_to_ms_valid,
    output wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus,
    output wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus,
    output wire                         data_sram_en,
    output wire [ 3:0]                  data_sram_we,
    output wire [31:0]                  data_sram_addr,
    output wire [31:0]                  data_sram_wdata
);

reg                          es_valid;
reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire                         es_ready_go;

wire        es_res_from_mem;
wire [ 1:0] es_mem_size;
wire        es_load_unsigned;
wire        es_mem_we;
wire        es_gr_we;
wire [ 4:0] es_dest;
wire [11:0] es_alu_op;
wire [31:0] es_alu_src1;
wire [31:0] es_alu_src2;
wire [31:0] es_rkd_value;
wire [31:0] es_pc;
wire [31:0] es_alu_result;

assign {
    es_mem_size,
    es_load_unsigned,
    es_res_from_mem,
    es_mem_we,
    es_gr_we,
    es_dest,
    es_alu_op,
    es_alu_src1,
    es_alu_src2,
    es_rkd_value,
    es_pc
} = ds_to_es_bus_r;

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || (es_ready_go && ms_allowin);
assign es_to_ms_valid = es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

alu u_alu(
    .alu_op     (es_alu_op     ),
    .alu_src1   (es_alu_src1   ),
    .alu_src2   (es_alu_src2   ),
    .alu_result (es_alu_result )
);

// Only the transfer edge may issue a memory operation. This prevents repeated
// stores if a later extension adds downstream backpressure.
assign data_sram_en    = !reset && es_to_ms_valid && ms_allowin &&
                        (es_res_from_mem || es_mem_we);
wire [3:0] store_lanes = es_mem_size == `MEM_SIZE_BYTE ? (4'b0001 << es_alu_result[1:0]) :
                         es_mem_size == `MEM_SIZE_HALF ? (es_alu_result[1] ? 4'b1100 : 4'b0011) :
                                                        4'b1111;
assign data_sram_we    = {4{data_sram_en && es_mem_we}} & store_lanes;
assign data_sram_addr  = es_alu_result;
// Replication places the low byte/halfword in every possible selected lane.
assign data_sram_wdata = es_mem_size == `MEM_SIZE_BYTE ? {4{es_rkd_value[7:0]}} :
                         es_mem_size == `MEM_SIZE_HALF ? {2{es_rkd_value[15:0]}} :
                                                        es_rkd_value;
assign es_to_ds_bus = {es_valid && es_gr_we && es_dest != 5'd0,
                       es_res_from_mem, es_dest, es_alu_result};

assign es_to_ms_bus = {
    es_mem_size,
    es_load_unsigned,
    es_res_from_mem,
    es_gr_we,
    es_dest,
    es_alu_result,
    es_pc
};

endmodule
