`include "mycpu_head.v"
`timescale 1ns / 1ps

module mem_stage(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         ws_allowin,
    input  wire                         es_to_ms_valid,
    input  wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus,
    input  wire [31:0]                  data_sram_rdata,
    output wire                         ms_allowin,
    output wire                         ms_to_ws_valid,
    output wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus,
    output wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus
);

reg                          ms_valid;
reg  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire                         ms_ready_go;

wire        ms_res_from_mem;
// 实验四新增：记录本条load读取字节/半字/字，以及是否进行零扩展。
wire [ 1:0] ms_mem_size;
wire        ms_load_unsigned;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire [31:0] ms_final_result;

// 实验四修改：解包EXE传来的新增3位，和本条指令的地址、目的寄存器一起保存。
assign {
    ms_mem_size,
    ms_load_unsigned,
    ms_res_from_mem,
    ms_gr_we,
    ms_dest,
    ms_alu_result,
    ms_pc
} = es_to_ms_bus_r;

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || (ms_ready_go && ws_allowin);
assign ms_to_ws_valid = ms_valid && ms_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r <= es_to_ms_bus;
    end
end

// Little endian: address bits 1:0 select byte position in the returned word.
// 实验四新增：RAM返回32位字，先把目标字节或半字右移到最低位，再截取。
// {地址低2位,3'b000}表示字节偏移乘8，所以00/01/10/11分别右移0/8/16/24位。
// 半字访问使用自然对齐地址，其字内偏移为0或2，即右移0或16位。
wire [31:0] shifted_load = data_sram_rdata >> {ms_alu_result[1:0], 3'b000};
// 实验四新增：ld.b/ld.h复制所选数据的符号位(bit7/bit15)，ld.bu/ld.hu高位补0。
// 例如读到字节80：ld.b得到FFFFFF80，ld.bu得到00000080；ld.w保留原32位数据。
wire [31:0] load_result = ms_mem_size == `MEM_SIZE_BYTE ?
                         {{24{!ms_load_unsigned && shifted_load[7]}}, shifted_load[7:0]} :
                         ms_mem_size == `MEM_SIZE_HALF ?
                         {{16{!ms_load_unsigned && shifted_load[15]}}, shifted_load[15:0]} :
                         data_sram_rdata;
// 实验四修改：load原来直接选RAM的32位数据，现在选经过截取和扩展的load_result。
// 其余写回指令仍选EXE计算结果；下方原有前递和写回总线共用这个最终结果。
assign ms_final_result = ms_res_from_mem ? load_result
                                         : ms_alu_result;
assign ms_to_ds_bus = {ms_valid && ms_gr_we && ms_dest != 5'd0,
                       ms_dest, ms_final_result};
assign ms_to_ws_bus = {
    ms_gr_we,
    ms_dest,
    ms_final_result,
    ms_pc
};

endmodule
