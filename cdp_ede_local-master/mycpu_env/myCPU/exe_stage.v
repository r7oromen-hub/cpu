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
// 实验五新增：标记本条除法是否已启动，并接收本条指令的乘法/除法控制字段。
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
// 实验五新增：统一选择ALU、乘积、商或余数作为EXE最终结果。
wire [31:0] es_final_result;
wire div_start;
wire div_busy;
wire div_done;
wire [31:0] div_quotient;
wire [31:0] div_remainder;

// 实验五修改：从ID->EXE总线最高6位取出mul_op/div_op，原有字段顺序不变。
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

// 实验五修改：原ready_go恒为1；现在除法必须“本条已启动且完成”才允许离开EXE。
// div_started避免新除法误用上一条除法保留的done和结果；乘法仍在EXE单周期完成。
assign es_ready_go    = !es_div_op[2] || (div_started && div_done);
assign es_allowin     = !es_valid || (es_ready_go && ms_allowin);
assign es_to_ms_valid = es_valid && es_ready_go;
// 实验五新增：只有有效且尚未启动的除法发出start，避免等待期间反复启动。
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

// 实验五新增：换入下一条指令或复位时清除启动标记，接受start后置1。
// 下游阻塞时保持该标记，即使除法已完成，也不能重复发起请求。
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

// 实验五新增：使用一个33x33位有符号乘法器兼容三种乘法。
// mulh.w符号扩展，mulh.wu高位补0；32位无符号数补0后可在33位有符号数中表示。
wire signed [32:0] mul_src1 = {(!es_mul_op[2] && es_alu_src1[31]), es_alu_src1};
wire signed [32:0] mul_src2 = {(!es_mul_op[2] && es_alu_src2[31]), es_alu_src2};
wire signed [65:0] mul_product = mul_src1 * mul_src2;
// 实验五新增：mul.w取低32位，另两条取高32位；低32位不受有/无符号解释影响。
wire [31:0] mul_result = es_mul_op[0] ? mul_product[31:0] : mul_product[63:32];
// 实验五新增：独立迭代除法器跨周期计算；商和余数同时输出，由指令选择。
iterative_divider u_divider(
    .clk(clk), .reset(reset), .start(div_start), .signed_mode(es_div_op[1]),
    .dividend(es_alu_src1), .divisor(es_alu_src2), .busy(div_busy),
    .done(div_done), .quotient(div_quotient), .remainder(div_remainder)
);
// 实验五新增：|es_mul_op为归约或，任一乘法位为1就选择乘积；否则选择商/余数或ALU。
assign es_final_result = |es_mul_op ? mul_result :
                         es_div_op[2] ? (es_div_op[0] ? div_remainder : div_quotient) :
                                        es_alu_result;

assign data_sram_en    = !reset && es_to_ms_valid && ms_allowin &&
                        (es_res_from_mem || es_mem_we);
wire [3:0] store_lanes = es_mem_size == `MEM_SIZE_BYTE ? (4'b0001 << es_alu_result[1:0]) :
                         es_mem_size == `MEM_SIZE_HALF ? (es_alu_result[1] ? 4'b1100 : 4'b0011) :
                                                        4'b1111;
assign data_sram_we    = {4{data_sram_en && es_mem_we}} & store_lanes;
assign data_sram_addr  = es_alu_result;
assign data_sram_wdata = es_mem_size == `MEM_SIZE_BYTE ? {4{es_rkd_value[7:0]}} :
                         es_mem_size == `MEM_SIZE_HALF ? {2{es_rkd_value[15:0]}} :
                                                        es_rkd_value;
// 实验五修改：前递数据由单独ALU结果改为最终结果，新增未完成除法的不可用标记。
// 除法完成后该标记解除，ID才能前递使用本条指令的商或余数。
assign es_to_ds_bus = {es_valid && es_gr_we && es_dest != 5'd0,
                       es_res_from_mem || (es_div_op[2] && !es_ready_go),
                       es_dest, es_final_result};

// 实验五修改：原es_alu_result字段改传es_final_result，MEM/WB可沿用原有写回通路。
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
