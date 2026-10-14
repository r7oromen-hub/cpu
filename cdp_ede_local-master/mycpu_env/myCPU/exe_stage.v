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
reg                          div_started;
wire [2:0]                   es_mul_op;
wire [2:0]                   es_div_op;

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
wire [31:0] es_final_result;
wire div_start;
wire div_busy;
wire div_done;
wire [31:0] div_quotient;
wire [31:0] div_remainder;

assign {
    es_mul_op,
    es_div_op,
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

// div_started distinguishes this instruction from the previous divider's
// sticky done. A newly arrived division cannot consume the previous result.
assign es_ready_go    = !es_div_op[2] || (div_started && div_done);
assign es_allowin     = !es_valid || (es_ready_go && ms_allowin);
assign es_to_ms_valid = es_valid && es_ready_go;
assign div_start = !reset && es_valid && es_div_op[2] && !div_started;

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

always @(posedge clk) begin
    if (reset)
        div_started <= 1'b0;
    else if (es_allowin)
        div_started <= 1'b0;
    else if (div_start)
        div_started <= 1'b1;
end

alu u_alu(
    .alu_op     (es_alu_op     ),
    .alu_src1   (es_alu_src1   ),
    .alu_src2   (es_alu_src2   ),
    .alu_result (es_alu_result )
);

// Sign-extend for mulh.w and zero-extend for mulh.wu. Both unsigned 32-bit
// values fit in signed 33 bits, so one multiply implements all three opcodes.
wire signed [32:0] mul_src1 = {(!es_mul_op[2] && es_alu_src1[31]), es_alu_src1};
wire signed [32:0] mul_src2 = {(!es_mul_op[2] && es_alu_src2[31]), es_alu_src2};
wire signed [65:0] mul_product = mul_src1 * mul_src2;
wire [31:0] mul_result = es_mul_op[0] ? mul_product[31:0] : mul_product[63:32];
iterative_divider u_divider(
    .clk(clk), .reset(reset), .start(div_start), .signed_mode(es_div_op[1]),
    .dividend(es_alu_src1), .divisor(es_alu_src2), .busy(div_busy),
    .done(div_done), .quotient(div_quotient), .remainder(div_remainder)
);
assign es_final_result = |es_mul_op ? mul_result :
                         es_div_op[2] ? (es_div_op[0] ? div_remainder : div_quotient) :
                                        es_alu_result;

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
                       es_res_from_mem || (es_div_op[2] && !es_ready_go),
                       es_dest, es_final_result};

assign es_to_ms_bus = {
    es_mem_size,
    es_load_unsigned,
    es_res_from_mem,
    es_gr_we,
    es_dest,
    es_final_result,
    es_pc
};

endmodule
