`timescale 1ns / 1ps

// 32-bit restoring divider. There is one shift/compare/subtract iteration per
// cycle; synthesizable datapath deliberately contains neither / nor %.
// start is accepted only while idle. done and outputs remain stable until the
// next accepted start (or reset), so a stalled pipeline can retain the result.
module iterative_divider(
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire        signed_mode,
    input  wire [31:0] dividend,
    input  wire [31:0] divisor,
    output reg         busy,
    output reg         done,
    output reg  [31:0] quotient,
    output reg  [31:0] remainder
);

reg [31:0] quotient_work;
reg [32:0] remainder_work;
reg [31:0] divisor_abs;
reg [5:0]  iteration;
reg        quotient_negative;
reg        remainder_negative;

// 有符号除法先求操作数的无符号幅值；记录符号，在迭代完成后恢复。
wire dividend_negative = signed_mode && dividend[31];
wire divisor_negative  = signed_mode && divisor[31];
wire [31:0] dividend_abs = dividend_negative ? (~dividend + 32'd1) : dividend;
wire [31:0] incoming_divisor_abs = divisor_negative ? (~divisor + 32'd1) : divisor;
// 每周期移入被除数的一位，比较余数与除数；够减则减去除数并写入一位商1。
wire [32:0] shifted_remainder = {remainder_work[31:0], quotient_work[31]};
wire subtract_divisor = shifted_remainder >= {1'b0, divisor_abs};
wire [32:0] next_remainder = subtract_divisor
                            ? shifted_remainder - {1'b0, divisor_abs}
                            : shifted_remainder;
wire [31:0] next_quotient = {quotient_work[30:0], subtract_divisor};
wire [31:0] signed_quotient = quotient_negative
                             ? (~next_quotient + 32'd1) : next_quotient;
wire [31:0] signed_remainder = remainder_negative
                              ? (~next_remainder[31:0] + 32'd1)
                              : next_remainder[31:0];

// 空闲时接受start；普通非零除数迭代32次，done和结果保持至下一次请求或复位。
// 本实现除数为零时直接给商全1、余数为被除数，不触发异常。
always @(posedge clk) begin
    if (reset) begin
        busy               <= 1'b0;
        done               <= 1'b0;
        quotient           <= 32'b0;
        remainder          <= 32'b0;
        quotient_work      <= 32'b0;
        remainder_work     <= 33'b0;
        divisor_abs        <= 32'b0;
        iteration          <= 6'b0;
        quotient_negative  <= 1'b0;
        remainder_negative <= 1'b0;
    end
    else if (start && !busy) begin
        // LoongArch leaves division-by-zero results unspecified; this module
        // defines quotient=-1 and remainder=dividend without an exception.
        if (divisor == 32'b0) begin
            quotient  <= 32'hffffffff;
            remainder <= dividend;
            busy      <= 1'b0;
            done      <= 1'b1;
        end
        else begin
            quotient_work      <= dividend_abs;
            remainder_work     <= 33'b0;
            divisor_abs        <= incoming_divisor_abs;
            quotient_negative  <= dividend_negative ^ divisor_negative;
            remainder_negative <= dividend_negative;
            iteration          <= 6'd0;
            busy               <= 1'b1;
            done               <= 1'b0;
        end
    end
    else if (busy) begin
        quotient_work  <= next_quotient;
        remainder_work <= next_remainder;
        if (iteration == 6'd31) begin
            quotient  <= signed_quotient;
            remainder <= signed_remainder;
            busy      <= 1'b0;
            done      <= 1'b1;
        end
        else begin
            iteration <= iteration + 6'd1;
        end
    end
end

endmodule
