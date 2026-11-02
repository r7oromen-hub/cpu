`timescale 1ns / 1ps
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
wire selected = inst_sram_en && !reset;
wire writing = selected && |inst_sram_we;
wire reading = selected && !writing;
assign base_ram_addr = inst_sram_addr[21:2];
assign base_ram_ce_n = !selected;
assign base_ram_we_n = !writing;
assign base_ram_oe_n = !reading;
assign base_ram_be_n = !selected ? 4'hf : writing ? ~inst_sram_we : 4'h0;
assign base_ram_data = writing ? inst_sram_wdata : 32'bz;
always @(posedge clk) begin
    if (reset)
        inst_sram_rdata <= 32'b0;
    else if (reading)
        inst_sram_rdata <= base_ram_data;
end
endmodule
