`timescale 1ns / 1ps
// 实验二新增：异步、低有效外部BaseRAM适配模块，读数据寄存后呈现一周期返回接口。
module BaseRAM_control(
    input wire clk,
    input wire reset,
    input wire inst_sram_en,
    input wire [31:0] inst_sram_addr,
    input wire [31:0] inst_sram_wdata,
    output reg [31:0] inst_sram_rdata,
    input wire [3:0] inst_sram_we,
    inout wire [31:0] base_ram_data,
    output wire [19:0] base_ram_addr,
    output wire [3:0] base_ram_be_n,
    output wire base_ram_ce_n,
    output wire base_ram_oe_n,
    output wire base_ram_we_n
);
// 实验二新增：复位/未选中时关闭访问，分别产生互斥的读写控制。
wire selected = inst_sram_en && !reset;
wire writing = selected && |inst_sram_we;
wire reading = selected && !writing;
// 实验二新增：字节地址去掉低2位形成字地址；片选/读使能/写使能均转换为低有效。
assign base_ram_addr = inst_sram_addr[21:2];
assign base_ram_ce_n = !selected;
assign base_ram_we_n = !writing;
assign base_ram_oe_n = !reading;
assign base_ram_be_n = !selected ? 4'hf : writing ? ~inst_sram_we : 4'h0;
// 实验二新增：写时驱动双向总线，读时置高阻由RAM驱动；字节使能也转换为低有效。
assign base_ram_data = writing ? inst_sram_wdata : 32'bz;
// 实验二新增：读取时在时钟沿保存RAM数据；无读请求时保持输出，复位时输出清零。
always @(posedge clk) begin
    if (reset)
        inst_sram_rdata <= 32'b0;
    else if (reading)
        inst_sram_rdata <= base_ram_data;
end
endmodule
