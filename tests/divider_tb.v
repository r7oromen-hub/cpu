`timescale 1ns/1ps
module divider_tb;
reg clk = 0;
always #5 clk = ~clk;
reg reset = 1, start = 0, signed_mode = 0;
reg [31:0] dividend = 0, divisor = 0;
wire busy, done;
wire [31:0] quotient, remainder;
integer tests = 0, seed = 32'h1452026, i, j;
reg [31:0] corners[0:10];
iterative_divider dut(.*);

task check_case(input bit sign_mode, input [31:0] a, input [31:0] b,
                input bit disturb_busy, input integer hold_cycles);
reg signed [63:0] sa, sb, sq, sr;
reg [31:0] eq, er;
integer cycles, h;
begin
    // The testbench oracle is deliberately independent of the restoring
    // datapath. / and % are allowed only here, never in synthesized RTL.
    if (b == 0) begin eq = 32'hffffffff; er = a; end
    else if (sign_mode) begin
        sa = {{32{a[31]}},a}; sb = {{32{b[31]}},b};
        sq = sa / sb; sr = sa % sb; eq = sq[31:0]; er = sr[31:0];
    end
    else begin eq = a / b; er = a % b; end
    @(negedge clk); signed_mode = sign_mode; dividend = a; divisor = b; start = 1;
    @(posedge clk); #1;
    if (b != 0 && (!busy || done)) $fatal(1,"start did not clear done/set busy");
    @(negedge clk); start = 0;
    cycles = 0;
    while (!done) begin
        // An unaccepted start and changing input buses must not corrupt a run.
        if (disturb_busy && cycles == 2) begin
            start = 1; dividend = ~a; divisor = 32'd3; signed_mode = ~sign_mode;
        end
        if (cycles == 3) start = 0;
        @(posedge clk); #1; cycles = cycles + 1;
        if (cycles > 33) $fatal(1,"division timed out");
        @(negedge clk);
    end
    start = 0;
    if (busy || quotient !== eq || remainder !== er)
        $fatal(1,"division mismatch signed=%0d a=%h b=%h expected q=%h r=%h got q=%h r=%h",
               sign_mode,a,b,eq,er,quotient,remainder);
    if (b != 0 && cycles != 32) $fatal(1,"latency got %0d expected 32 iterations",cycles);
    for (h=0;h<hold_cycles;h=h+1) begin
        dividend = $random(seed); divisor = $random(seed);
        @(posedge clk); #1;
        if (!done || busy || quotient !== eq || remainder !== er)
            $fatal(1,"completed result was not held");
        @(negedge clk);
    end
    tests = tests + 1;
end
endtask

initial begin
    repeat(3) @(posedge clk);
    @(negedge clk); reset=0;
    corners[0]=0; corners[1]=1; corners[2]=2; corners[3]=3;
    corners[4]=32'h7fffffff; corners[5]=32'h80000000;
    corners[6]=32'hffffffff; corners[7]=32'hfffffffe;
    corners[8]=32'h40000000; corners[9]=32'h80000001; corners[10]=32'h55555555;
    for(i=0;i<11;i=i+1) for(j=0;j<11;j=j+1) begin
        check_case(0,corners[i],corners[j],1,2);
        check_case(1,corners[i],corners[j],1,2);
    end
    // Fixed seed gives reproducible random inputs and back-to-back requests.
    for(i=0;i<1000;i=i+1) begin
        check_case(0,$random(seed),$random(seed),i%5==0,i%4);
        check_case(1,$random(seed),$random(seed),i%7==0,i%3);
    end
    @(negedge clk); start=1; dividend=32'hfedcba98; divisor=7; signed_mode=0;
    @(negedge clk); start=0;
    repeat(7) @(negedge clk);
    reset=1;
    @(posedge clk); #1;
    if(busy || done || quotient!==0 || remainder!==0) $fatal(1,"reset failed to abort division");
    @(negedge clk); reset=0;
    check_case(1,-32'd37,32'd5,0,8);
    $display("DIVIDER PASS cases=%0d corner/sign/random/busy-start/result-hold/reset-abort",tests);
    $finish;
end
initial begin #2000000; $fatal(1,"global timeout"); end
endmodule
