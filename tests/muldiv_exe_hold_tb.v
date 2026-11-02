`timescale 1ns/1ps
`include "mycpu_head.v"
module muldiv_exe_hold_tb;
reg clk=0;
always #5 clk=~clk;
reg reset=1,ms_allowin=0,fs_to_ds_valid=0;
reg [`FS_TO_DS_BUS_WD-1:0] fs_to_ds_bus=0;
reg [`WS_TO_RF_BUS_WD-1:0] ws_to_rf_bus=0;
wire ds_allowin,ds_to_es_valid,es_allowin,es_to_ms_valid;
wire [`DS_TO_ES_BUS_WD-1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD-1:0] es_to_ms_bus;
wire [`ES_TO_DS_BUS_WD-1:0] es_to_ds_bus;
wire [`BR_BUS_WD-1:0] br_bus;
wire data_sram_en;
wire [3:0] data_sram_we;
wire [31:0] data_sram_addr,data_sram_wdata;
reg [`ES_TO_MS_BUS_WD-1:0] held_bus;
integer starts=0,stores=0,cycles=0,i;
id_stage id(.clk(clk),.reset(reset),.es_allowin(es_allowin),
    .fs_to_ds_valid(fs_to_ds_valid),.fs_to_ds_bus(fs_to_ds_bus),
    .ws_to_rf_bus(ws_to_rf_bus),.es_to_ds_bus(es_to_ds_bus),
    .ms_to_ds_bus({`MS_TO_DS_BUS_WD{1'b0}}),.ds_allowin(ds_allowin),
    .ds_to_es_valid(ds_to_es_valid),.ds_to_es_bus(ds_to_es_bus),.br_bus(br_bus));
exe_stage exe(.*);

task write_rf(input [4:0] regno,input [31:0] value);
begin
    @(negedge clk);ws_to_rf_bus={1'b1,regno,value};
    @(negedge clk);ws_to_rf_bus=0;
end
endtask
task issue(input [31:0] instruction,input [31:0] pc);
begin
    @(negedge clk);
    while(!ds_allowin) @(negedge clk);
    fs_to_ds_bus={instruction,pc};fs_to_ds_valid=1;
    @(negedge clk);fs_to_ds_valid=0;
end
endtask
always @(posedge clk) if(!reset) begin
    if(exe.div_start) starts=starts+1;
    if(data_sram_en && |data_sram_we) stores=stores+1;
end
initial begin
    repeat(3) @(negedge clk);reset=0;
    write_rf(2,-32'd37);write_rf(3,5);write_rf(4,99);
    issue(32'h00200000 | (3<<10) | (2<<5) | 7,32'h1c000000);
    issue(32'h02800000 | (1<<10) | (7<<5) | 8,32'h1c000004);
    while(!es_to_ms_valid) begin
        @(negedge clk);cycles=cycles+1;
        if(id.ds_valid && ds_to_es_valid && !exe.es_ready_go)
            $fatal(1,"dependent ID instruction bypassed unfinished division");
        if(cycles>40) $fatal(1,"division did not finish while downstream blocked");
    end
    held_bus=es_to_ms_bus;
    for(i=0;i<8;i=i+1) begin
        @(negedge clk);
        if(!es_to_ms_valid || es_allowin || es_to_ms_bus!==held_bus ||
           exe.div_start || data_sram_en || es_to_ds_bus[31:0]!==-32'd7)
            $fatal(1,"division output changed/restarted under backpressure");
    end
    if(starts!=1) $fatal(1,"request count expected1 got%0d",starts);
    ms_allowin=1;
    @(posedge clk);#1;
    if(!exe.es_valid || es_to_ds_bus[31:0]!==-32'd6)
        $fatal(1,"dependent add did not capture completed divide result");
    @(negedge clk); // let add leave EXE before introducing next instruction
    @(negedge clk);ms_allowin=0;
    issue(32'h29800000 | (64<<10) | 4,32'h1c000008);
    while(!exe.es_valid) @(negedge clk);
    repeat(6) begin
        @(negedge clk);
        if(data_sram_en || |data_sram_we) $fatal(1,"held store issued early/repeated");
    end
    ms_allowin=1;
    @(posedge clk);#1;
    @(negedge clk);
    repeat(3) @(negedge clk);
    if(stores!=1) $fatal(1,"store should issue once got%0d",stores);
    issue(32'h00208000 | (3<<10) | (2<<5) | 9,32'h1c00000c);
    while(!exe.u_divider.busy) @(negedge clk);
    repeat(8) @(negedge clk);
    reset=1;
    @(posedge clk);#1;
    if(exe.es_valid || exe.u_divider.busy || exe.u_divider.done ||
       es_to_ms_valid || data_sram_en)
        $fatal(1,"reset did not abort EXE division/side effects");
    $display("MULDIV_EXE_HOLD PASS completed-output-hold/dependent-forward/single-store/reset-abort");
    $finish;
end
initial begin #10000;$fatal(1,"global timeout");end
endmodule
