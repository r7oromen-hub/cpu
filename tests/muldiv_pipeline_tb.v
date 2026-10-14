`timescale 1ns/1ps
module muldiv_pipeline_tb;
reg clk=0;
always #5 clk=~clk;
reg resetn=0;
wire ien,den;
wire [3:0] iwe,dwe,wbwe;
wire [31:0] ia,iw,da,dw,wbpc,wbdata;
wire [4:0] wbreg;
reg [31:0] ir=0,dr=0;
reg [31:0] imem[0:255],dmem[0:255];
reg [31:0] epc[0:127],edata[0:127];
reg [4:0] ereg[0:127];
integer i,k,pos=0,n=0,checked=0,cycles=0,stores=0,starts=0;
integer division_instructions=0;
mycpu_top dut(.clk(clk),.resetn(resetn),
 .inst_sram_en(ien),.inst_sram_we(iwe),.inst_sram_addr(ia),
 .inst_sram_wdata(iw),.inst_sram_rdata(ir),
 .data_sram_en(den),.data_sram_we(dwe),.data_sram_addr(da),
 .data_sram_wdata(dw),.data_sram_rdata(dr),
 .debug_wb_pc(wbpc),.debug_wb_rf_we(wbwe),
 .debug_wb_rf_wnum(wbreg),.debug_wb_rf_wdata(wbdata));

function [31:0] rr(input [31:0] op,input [4:0] rd,input [4:0] rj,input [4:0] rk);
    rr=op | (rk<<10) | (rj<<5) | rd;
endfunction
function [31:0] addi(input [4:0] rd,input [4:0] rj,input [11:0] imm);
    addi=32'h02800000 | (imm<<10) | (rj<<5) | rd;
endfunction
function [31:0] mem(input bit store,input [4:0] rd,input [11:0] offset);
    mem=(store?32'h29800000:32'h28800000) | (offset<<10) | rd;
endfunction
task emit(input [31:0] instruction,input [4:0] r,input [31:0] value);
begin
    imem[pos]=instruction;
    epc[n]=32'h1c000000+pos*4; ereg[n]=r; edata[n]=value;
    n=n+1;pos=pos+1;
    if((instruction & 32'hfffe0000)==32'h00200000)
        division_instructions=division_instructions+1;
end
endtask
task raw_emit(input [31:0] instruction);
begin imem[pos]=instruction;pos=pos+1;end
endtask

initial begin
    for(i=0;i<256;i=i+1) begin imem[i]=32'h50000000;dmem[i]=0;end
    dmem[0]=-32'd37;dmem[1]=5;dmem[2]=-32'd5;
    dmem[3]=32'h80000000;dmem[4]=32'hffffffff;
    dmem[5]=32'hfffffffe;dmem[6]=32'h40000000;
    emit(mem(0,2,0),2,-32'd37);
    emit(mem(0,3,4),3,5);
    emit(rr(32'h001c0000,4,2,3),4,-32'd185);  // mul.w and load-use
    emit(rr(32'h001c8000,5,2,3),5,32'hffffffff); // signed high
    emit(rr(32'h001d0000,6,2,3),6,4);         // unsigned high
    emit(rr(32'h00200000,7,2,3),7,-32'd7);
    emit(addi(8,7,1),8,-32'd6);               // immediate division RAW
    emit(rr(32'h00208000,9,2,3),9,-32'd2);
    raw_emit(mem(1,9,64));                    // mod -> store RAW
    emit(rr(32'h00210000,10,2,3),10,32'h3333332b);
    emit(rr(32'h00218000,11,2,3),11,4);
    emit(mem(0,12,8),12,-32'd5);
    emit(rr(32'h00200000,13,2,12),13,7);      // negative / negative
    emit(rr(32'h00208000,14,2,12),14,-32'd2);
    emit(rr(32'h00200000,15,3,12),15,-32'd1); // positive / negative
    emit(rr(32'h00208000,16,3,12),16,0);
    emit(mem(0,17,12),17,32'h80000000);
    emit(mem(0,18,16),18,32'hffffffff);
    emit(rr(32'h00200000,19,17,18),19,32'h80000000);
    emit(rr(32'h00208000,20,17,18),20,0);      // signed overflow wrap
    emit(rr(32'h001c8000,21,17,18),21,0);
    emit(rr(32'h001d0000,22,17,18),22,32'h7fffffff);
    emit(rr(32'h001c0000,23,4,7),23,32'd1295); // multiply result dependency
    emit(rr(32'h00200000,24,2,0),24,32'hffffffff); // div0 defined
    emit(rr(32'h00208000,25,2,0),25,-32'd37);
    emit(rr(32'h00210000,26,3,0),26,32'hffffffff);
    emit(rr(32'h00218000,27,3,0),27,5);
    emit(rr(32'h00200000,28,2,3),28,-32'd7);
    // Branch waits for its immediately preceding division, then kills both
    // wrong-path register write and store. No stale division value may redirect.
    raw_emit(32'h58000000 | (3<<10) | (28<<5) | 7);
    raw_emit(mem(1,3,68));
    raw_emit(addi(29,0,999));
    emit(addi(29,28,8),29,1);
    emit(rr(32'h00200000,30,29,3),30,0);       // dividend < divisor
    emit(rr(32'h00208000,31,29,3),31,1);
    raw_emit(mem(1,31,72));
    emit(addi(4,0,42),4,42);                 // final completion write
    #40 resetn=1;
end

always @(posedge clk) begin
    if(ien) ir<=imem[ia[9:2]];
    if(den) begin
        dr<=dmem[da[9:2]];
        for(k=0;k<4;k=k+1) if(dwe[k]) dmem[da[9:2]][8*k+:8]<=dw[8*k+:8];
        if(|dwe) begin
            stores=stores+1;
            if(da!==64 && da!==72) $fatal(1,"wrong-path/repeated store da=%h",da);
        end
    end
    if(resetn && !dut.reset) begin
        cycles=cycles+1;
        if(dut.u_exe_stage.div_start) starts=starts+1;
    end
    #1;
    if(resetn && |wbwe && wbreg!=0) begin
        if(checked>=n) $fatal(1,"unexpected duplicate writeback");
        if(wbpc!==epc[checked] || wbreg!==ereg[checked] || wbdata!==edata[checked])
            $fatal(1,"trace mismatch #%0d expected pc=%h r=%0d data=%h got pc=%h r=%0d data=%h",
                checked,epc[checked],ereg[checked],edata[checked],wbpc,wbreg,wbdata);
        checked=checked+1;
        if(checked==n) begin
            if(stores!=2 || dmem[16]!==-32'd2 || dmem[18]!==1)
                $fatal(1,"store side effects mismatch stores=%0d",stores);
            if(starts!=division_instructions)
                $fatal(1,"division restarted/lost starts=%0d instructions=%0d",starts,division_instructions);
            $display("MULDIV_PIPELINE PASS writes=%0d cycles=%0d division-starts=%0d stores=%0d",
                checked,cycles,starts,stores);
            $finish;
        end
    end
    if(cycles>4000) $fatal(1,"timeout writes=%0d/%0d",checked,n);
end
endmodule
