`timescale 1ns/1ps
module lab2_hazards_tb;
reg clk=0;
always #5 clk=~clk;
reg resetn=0;
wire ien, den;
wire [3:0] iwe, dwe, wbwe;
wire [31:0] ia, iw, da, dw, wbpc, wbdata;
wire [4:0] wbreg;
reg [31:0] ir=0, dr=0;
reg [31:0] imem[0:255], dmem[0:255];
integer i, k, cycles=0, stalls=0, stores=0, redirects=0;
integer n=0, checked=0;
reg [31:0] epc[0:63], edata[0:63];
reg [4:0] ereg[0:63];
mycpu_top dut(.clk(clk),.resetn(resetn),
 .inst_sram_en(ien),.inst_sram_we(iwe),.inst_sram_addr(ia),
 .inst_sram_wdata(iw),.inst_sram_rdata(ir),
 .data_sram_en(den),.data_sram_we(dwe),.data_sram_addr(da),
 .data_sram_wdata(dw),.data_sram_rdata(dr),
 .debug_wb_pc(wbpc),.debug_wb_rf_we(wbwe),
 .debug_wb_rf_wnum(wbreg),.debug_wb_rf_wdata(wbdata));
function [31:0] addi(input [4:0] rd,input [4:0] rj,input [11:0] imm);
 addi=32'h02800000 | (imm<<10) | (rj<<5) | rd;
endfunction
function [31:0] add(input [4:0] rd,input [4:0] rj,input [4:0] rk);
 add=32'h00100000 | (rk<<10) | (rj<<5) | rd;
endfunction
function [31:0] mem(input bit store,input [4:0] rd,input [4:0] rj,input [11:0] imm);
 mem=(store?32'h29800000:32'h28800000) | (imm<<10) | (rj<<5) | rd;
endfunction
function [31:0] branch(input bit link,input [25:0] off);
 branch=(link?32'h54000000:32'h50000000) | (off[15:0]<<10) | off[25:16];
endfunction
task expected(input integer idx,input [4:0] r,input [31:0] value);
 begin epc[n]=32'h1c000000+idx*4; ereg[n]=r; edata[n]=value; n=n+1; end
endtask
initial begin
 for(i=0;i<256;i=i+1) begin imem[i]=branch(0,0); dmem[i]=0; end
 imem[0]=addi(2,0,5); expected(0,2,5);
 imem[1]=addi(2,2,1); expected(1,2,6);
 imem[2]=addi(3,2,2); expected(2,3,8);
 imem[3]=mem(1,3,0,0);
 imem[4]=mem(0,4,0,0); expected(4,4,8);
 imem[5]=add(5,4,3); expected(5,5,16);
 // Taken branch immediately after its producer: kill wrong-path store and RF.
 imem[6]=32'h58000000 | (3<<10) | (5<<5) | 5;
 imem[7]=mem(1,2,0,4);
 imem[8]=addi(6,0,123);
 imem[9]=addi(7,0,7); expected(9,7,7);
 imem[10]=addi(7,0,9); expected(10,7,9);
 imem[11]=add(8,7,7); expected(11,8,18);
 imem[12]=addi(0,0,42);
 imem[13]=addi(9,0,0); expected(13,9,0);
 imem[14]=addi(10,0,7); expected(14,10,7);
 // Immediate's low bits look like rk=10, but addi has only one register source.
 imem[15]=addi(11,0,10); expected(15,11,10);
 // lu12i immediate bits look like rj=10; neither operand is a register source.
 imem[16]=32'h14000000 | (10<<5) | 12; expected(16,12,32'ha000);
 imem[17]=branch(1,3); expected(17,1,32'h1c000048);
 imem[18]=mem(1,2,0,8);
 imem[19]=addi(6,0,124);
 imem[20]=addi(13,0,13); expected(20,13,13);
 imem[21]=mem(1,1,0,12);
 // A load to a destination with an older value in MEM/WB must stall and use load.
 imem[22]=addi(14,0,99); expected(22,14,99);
 imem[23]=mem(0,14,0,0); expected(23,14,8);
 imem[24]=add(15,14,14); expected(24,15,16);
 // Non-taken branch with RAW operand.
 imem[25]=32'h5c000000 | (3<<10) | (15<<5) | 15;
 imem[26]=addi(16,0,16); expected(26,16,16);
 imem[27]=branch(0,2);
 imem[28]=mem(1,2,0,16);
 imem[29]=addi(17,0,17); expected(29,17,17);
 // jirl target from the immediately preceding addi: source is rj, not ALU src1.
 imem[30]=32'h14000000 | (20'h1c000<<5) | 18; expected(30,18,32'h1c000000);
 imem[31]=addi(18,18,144); expected(31,18,32'h1c000090);
 imem[32]=32'h4c000000 | (18<<5) | 19; expected(32,19,32'h1c000084);
 imem[33]=mem(1,2,0,20);
 imem[34]=addi(6,0,125);
 imem[36]=addi(20,0,20); expected(36,20,20);
 #40 resetn=1;
end
always @(posedge clk) begin
 if(ien) ir<=imem[ia[9:2]];
 if(den) begin
   dr<=dmem[da[9:2]];
   for(k=0;k<4;k=k+1) if(dwe[k]) dmem[da[9:2]][8*k+:8]<=dw[8*k+:8];
   if(|dwe) begin
     stores=stores+1;
     if(da!==0 && da!==12) $fatal(1,"wrong-path store addr=%h",da);
   end
 end
 if(resetn && !dut.reset) begin
   cycles=cycles+1;
   if(dut.u_id_stage.ds_valid && !dut.u_id_stage.ds_ready_go) stalls=stalls+1;
   if(dut.br_bus[32]) redirects=redirects+1;
   if((dut.u_id_stage.ds_pc==32'h1c00003c || dut.u_id_stage.ds_pc==32'h1c000040)
      && dut.u_id_stage.ds_valid && !dut.u_id_stage.ds_ready_go)
      $fatal(1,"unused instruction fields caused false RAW stall");
 end
 #1;
 if(resetn && |wbwe && wbreg!=0 && checked<n) begin
   if(wbpc!==epc[checked] || wbreg!==ereg[checked] || wbdata!==edata[checked])
     $fatal(1,"trace mismatch #%0d expected pc=%h r=%0d data=%h got pc=%h r=%0d data=%h",
       checked,epc[checked],ereg[checked],edata[checked],wbpc,wbreg,wbdata);
   checked=checked+1;
   if(checked==n) begin
     if(dmem[0]!==8 || dmem[3]!==32'h1c000048 || stores!=2)
       $fatal(1,"memory side effects wrong, stores=%0d",stores);
`ifdef STALL_ONLY
     if(stalls<20) $fatal(1,"pure blocking mode failed to stall");
`else
     if(stalls!=2) $fatal(1,"forwarding needs exactly two load-use bubbles, got %0d",stalls);
`endif
     $display("LAB2_HAZARDS PASS writes=%0d cycles=%0d stalls=%0d stores=%0d redirects=%0d",
       checked,cycles,stalls,stores,redirects);
     $finish;
   end
 end
 if(cycles>500) $fatal(1,"timeout checked=%0d/%0d",checked,n);
end
endmodule
