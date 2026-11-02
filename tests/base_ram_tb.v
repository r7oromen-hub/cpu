`timescale 1ns/1ps
module base_ram_tb;
reg clk=0;
always #5 clk=~clk;
reg reset=1, en=0;
reg [3:0] we=0;
reg [31:0] addr=0, wdata=0;
wire [31:0] rdata, bus;
wire [19:0] ram_addr;
wire [3:0] be_n;
wire ce_n, oe_n, we_n;
reg [31:0] memory=32'h11223344;
integer k;
BaseRAM_control dut(.clk(clk),.reset(reset),.inst_sram_en(en),
 .inst_sram_addr(addr),.inst_sram_wdata(wdata),.inst_sram_rdata(rdata),
 .inst_sram_we(we),.base_ram_data(bus),.base_ram_addr(ram_addr),
 .base_ram_be_n(be_n),.base_ram_ce_n(ce_n),.base_ram_oe_n(oe_n),.base_ram_we_n(we_n));
assign bus=(!ce_n && !oe_n && we_n)?memory:32'bz;
always @(posedge clk)
 if(!ce_n && !we_n)
   for(k=0;k<4;k=k+1) if(!be_n[k]) memory[8*k+:8]<=bus[8*k+:8];
initial begin
 #1;
 if({ce_n,oe_n,we_n,be_n}!==7'b1111111 || bus!==32'bz)
   $fatal(1,"reset must disable RAM and release data bus");
 @(negedge clk); reset=0; en=1; addr=32'habcdefbc;
 #1;
 if(ram_addr!==addr[21:2] || {ce_n,oe_n,we_n,be_n}!==7'b0010000 || bus!==memory)
   $fatal(1,"read polarity/address/tri-state incorrect");
 @(posedge clk); #1;
 if(rdata!==32'h11223344) $fatal(1,"registered read failed");
 @(negedge clk); we=4'b0101; wdata=32'haabbccdd;
 #1;
 if({ce_n,oe_n,we_n,be_n}!==7'b0101010 || bus!==wdata)
   $fatal(1,"write polarity/byte mask/data drive incorrect");
 @(posedge clk); #1;
 if(memory!==32'h11bb33dd || rdata!==32'h11223344)
   $fatal(1,"masked write/read hold failed");
 @(negedge clk); en=0;
 #1;
 if({ce_n,oe_n,we_n,be_n}!==7'b1111111 || bus!==32'bz)
   $fatal(1,"disabled SRAM must be released");
 @(posedge clk); #1;
 if(rdata!==32'h11223344) $fatal(1,"disabled read changed response");
 @(negedge clk); en=1; we=0;
 @(posedge clk); #1;
 if(rdata!==32'h11bb33dd) $fatal(1,"readback failed");
 $display("BASE_RAM PASS address/polarity/byte-mask/tri-state/held-response");
 $finish;
end
endmodule
