`timescale 1ns/1ps
module tb_sync_ram;
    reg clk = 0;
    always #5 clk = ~clk;
    reg en = 0;
    reg [3:0] we = 0;
    reg [1:0] address = 0;
    reg [31:0] wdata = 0;
    wire [31:0] rdata;
    sync_ram #(.ADDR_WIDTH(2)) ram(.clk(clk), .address(address),
        .rdata(rdata), .wdata(wdata), .we(we), .en(en));
    task tick;
        begin @(posedge clk); #1; end
    endtask
    initial begin
        en = 1; we = 4'b1111; wdata = 32'h11223344;
        tick(); we = 0; tick();
        if (rdata !== 32'h11223344) $fatal(1, "Full write/read failed");
        en = 0; we = 4'b1111; wdata = 32'hffffffff; tick();
        en = 1; we = 0; tick();
        if (rdata !== 32'h11223344) $fatal(1, "Disabled write changed RAM");
        we = 4'b0101; wdata = 32'haabbccdd; tick();
        if (rdata !== 32'h11223344) $fatal(1, "Expected read-first synchronous output");
        we = 0; tick();
        if (rdata !== 32'h11bb33dd) $fatal(1, "Byte enables failed");
        en = 0; address = 1; tick();
        if (rdata !== 32'h11bb33dd) $fatal(1, "Disabled read changed output");
        $display("RAM_MODEL_PASS: full write, byte enables, enable gating, synchronous read-first");
        $finish;
    end
endmodule
