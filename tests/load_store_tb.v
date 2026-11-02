`timescale 1ns/1ps
module load_store_tb;
localparam BASE = 32'h1c000000;
reg clk=0, resetn=0;
always #5 clk=~clk;
wire ien, den;
wire [3:0] iwe, dwe, wbwe;
wire [31:0] ia, iw, da, dw, wbpc, wbdata;
wire [4:0] wbreg;
reg [31:0] ir=0, dr=0;
reg [31:0] imem[0:1023], dmem[0:255];
reg [31:0] epc[0:255], edata[0:255];
reg [4:0] ereg[0:255];
reg [31:0] store_addr[0:31], store_data[0:31];
reg [3:0] store_mask[0:31];
integer p=0, n=0, checked=0, sn=0, stores=0, cycles=0;
integer i,k,off;
reg [31:0] byte_signed, byte_unsigned;
mycpu_top dut(.clk(clk),.resetn(resetn),
 .inst_sram_en(ien),.inst_sram_we(iwe),.inst_sram_addr(ia),
 .inst_sram_wdata(iw),.inst_sram_rdata(ir),
 .data_sram_en(den),.data_sram_we(dwe),.data_sram_addr(da),
 .data_sram_wdata(dw),.data_sram_rdata(dr),
 .debug_wb_pc(wbpc),.debug_wb_rf_we(wbwe),
 .debug_wb_rf_wnum(wbreg),.debug_wb_rf_wdata(wbdata));
function [31:0] imm_inst(input [31:0] opcode,input [4:0] rd,input [4:0] rj,input [11:0] imm);
 imm_inst=opcode | {10'b0,imm,rj,rd};
endfunction
task emit(input [31:0] inst);
 begin imem[p]=inst; p=p+1; end
endtask
task emit_wb(input [31:0] inst,input [4:0] dest,input [31:0] value);
 begin epc[n]=BASE+p*4; ereg[n]=dest; edata[n]=value; n=n+1; emit(inst); end
endtask
task emit_load(input [31:0] opcode,input [4:0] base,input [11:0] offset,input [31:0] value);
 begin
   emit_wb(imm_inst(opcode,10,base,offset),10,value);
   // Immediate consumer must wait for MEM formatted result, not EXE address.
   emit_wb(imm_inst(32'h02800000,11,10,1),11,value+1);
 end
endtask
task emit_store(input [31:0] opcode,input [4:0] src,input [4:0] base,input [11:0] offset,
                input [31:0] addr,input [3:0] mask,input [31:0] data);
 begin
   emit(imm_inst(opcode,src,base,offset));
   store_addr[sn]=addr; store_mask[sn]=mask; store_data[sn]=data; sn=sn+1;
 end
endtask
initial begin
 for(i=0;i<1024;i=i+1) imem[i]=32'h50000000;
 for(i=0;i<256;i=i+1) dmem[i]=32'h55aa55aa;
 dmem[0]=32'h80ff7f01;
 for(off=0;off<4;off=off+1) begin
   case(off)
    0: begin byte_signed=32'h00000001; byte_unsigned=32'h00000001; end
    1: begin byte_signed=32'h0000007f; byte_unsigned=32'h0000007f; end
    2: begin byte_signed=32'hffffffff; byte_unsigned=32'h000000ff; end
    3: begin byte_signed=32'hffffff80; byte_unsigned=32'h00000080; end
   endcase
   emit_load(32'h28000000,0,off,byte_signed);
   emit_load(32'h2a000000,0,off,byte_unsigned);
 end
 emit_load(32'h28400000,0,0,32'h00007f01);
 emit_load(32'h28400000,0,2,32'hffff80ff);
 emit_load(32'h2a400000,0,0,32'h00007f01);
 emit_load(32'h2a400000,0,2,32'h000080ff);
 emit_wb(imm_inst(32'h02800000,1,0,4),1,4);
 // Back-to-back producers and stores check forwarding of both address and data.
 emit_wb(imm_inst(32'h02800000,2,0,12'ha5),2,32'ha5);
 emit_store(32'h29000000,2,1,12'hffc,0,4'b0001,32'ha5a5a5a5);
 emit_load(32'h28800000,0,0,32'h80ff7fa5);
 emit_wb(imm_inst(32'h02800000,2,0,12'h34),2,32'h34);
 emit_store(32'h29000000,2,0,1,1,4'b0010,32'h34343434);
 emit_load(32'h28800000,0,0,32'h80ff34a5);
 emit_wb(imm_inst(32'h02800000,2,0,12'hf0),2,32'hf0);
 emit_store(32'h29000000,2,0,2,2,4'b0100,32'hf0f0f0f0);
 emit_load(32'h28800000,0,0,32'h80f034a5);
 emit_wb(imm_inst(32'h02800000,2,0,12'h7e),2,32'h7e);
 emit_store(32'h29000000,2,0,3,3,4'b1000,32'h7e7e7e7e);
 emit_load(32'h28800000,0,0,32'h7ef034a5);
 emit_wb(32'h14000102,2,32'h00008000); // lu12i.w r2, 8
 emit_wb(imm_inst(32'h03800000,2,2,1),2,32'h00008001);
 emit_store(32'h29400000,2,0,0,0,4'b0011,32'h80018001);
 emit_load(32'h28800000,0,0,32'h7ef08001);
 emit_wb(imm_inst(32'h02800000,2,0,12'hedc),2,32'hfffffedc);
 emit_store(32'h29400000,2,0,2,2,4'b1100,32'hfedcfedc);
 emit_load(32'h28800000,0,0,32'hfedc8001);
 emit_load(32'h28400000,0,0,32'hffff8001);
 emit_load(32'h28400000,0,2,32'hfffffedc);
 emit_load(32'h2a400000,0,0,32'h00008001);
 emit_load(32'h2a400000,0,2,32'h0000fedc);
 emit_load(32'h28000000,0,3,32'hfffffffe);
 // Word accesses must remain whole-word and retain their existing semantics.
 emit_wb(32'h142468a3,3,32'h12345000);
 emit_wb(imm_inst(32'h03800000,3,3,12'h678),3,32'h12345678);
 emit_store(32'h29800000,3,0,4,4,4'b1111,32'h12345678);
 emit_load(32'h28800000,0,4,32'h12345678);
 emit_load(32'h28000000,1,3,32'h12);
 emit_load(32'h2a000000,1,2,32'h34);
 // A subword load feeds store data immediately.
 emit_wb(imm_inst(32'h2a000000,12,0,1),12,32'h80);
 emit_store(32'h29000000,12,0,12,12,4'b0001,32'h80808080);
 emit_load(32'h28800000,0,12,32'h55aa5580);
 // A subword load also feeds the base address of the next load.
 emit_wb(imm_inst(32'h2a000000,13,0,0),13,1);
 emit_load(32'h2a000000,13,1,32'hdc);
 emit(32'h50000000);
 repeat(5) @(negedge clk);
 resetn=1;
end
always @(posedge clk) begin
 if(ien) ir<=imem[(ia-BASE)>>2];
 if(den) begin
   dr<=dmem[da[9:2]];
   if(|dwe) begin
     if(stores>=sn || da!==store_addr[stores] || dwe!==store_mask[stores])
       $fatal(1,"store %0d address/mask mismatch addr=%h mask=%b",stores,da,dwe);
     for(k=0;k<4;k=k+1) if(dwe[k]) begin
       if(dw[8*k+:8]!==store_data[stores][8*k+:8])
         $fatal(1,"store %0d lane %0d data mismatch",stores,k);
       dmem[da[9:2]][8*k+:8]<=dw[8*k+:8];
     end
     stores=stores+1;
   end
 end
 if(resetn) begin
   cycles=cycles+1;
   if(|wbwe && wbreg!=0) begin
     if(checked>=n || wbpc!==epc[checked] || wbreg!==ereg[checked] || wbdata!==edata[checked])
       $fatal(1,"write %0d got pc=%h rd=%0d data=%h expected pc=%h rd=%0d data=%h",
         checked,wbpc,wbreg,wbdata,epc[checked],ereg[checked],edata[checked]);
     checked=checked+1;
   end
   if(checked==n && cycles>400) begin
     if(stores!=sn || dmem[0]!==32'hfedc8001 || dmem[1]!==32'h12345678 ||
        dmem[2]!==32'h55aa55aa || dmem[3]!==32'h55aa5580 || dmem[4]!==32'h55aa55aa)
       $fatal(1,"final memory/untouched neighbor mismatch, stores=%0d",stores);
     $display("LOAD_STORE PASS writes=%0d stores=%0d cycles=%0d",checked,stores,cycles);
     $finish;
   end
   if(cycles>3000) $fatal(1,"timeout matched %0d/%0d",checked,n);
 end
end
endmodule
