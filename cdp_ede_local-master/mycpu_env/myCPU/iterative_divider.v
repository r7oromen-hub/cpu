`timescale 1ns / 1ps

// 实验五新增模块：32位迭代除法器，每周期移位、比较并按需减去除数，不用/或%综合。
// 空闲时接受start；普通非零除数执行32轮，done及结果保持到下一次请求或复位。
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

// 实验五新增：商寄存器起初装被除数，逐位移出它并移入新商位；余数多留1位做比较。
reg [31:0] quotient_work;
reg [32:0] remainder_work;
reg [31:0] divisor_abs;
reg [5:0]  iteration;
reg        quotient_negative;
reg        remainder_negative;

// 实验五新增：有符号输入先转为无符号幅值再做除法，完成后恢复符号。
// INT_MIN的幅值0x80000000按无符号数保存；unsigned模式直接使用原输入。
wire dividend_negative = signed_mode && dividend[31];
wire divisor_negative  = signed_mode && divisor[31];
wire [31:0] dividend_abs = dividend_negative ? (~dividend + 32'd1) : dividend;
wire [31:0] incoming_divisor_abs = divisor_negative ? (~divisor + 32'd1) : divisor;
// 实验五新增：把被除数下一位移入余数；余数够减则减去除数，并令本轮商位为1。
wire [32:0] shifted_remainder = {remainder_work[31:0], quotient_work[31]};
wire subtract_divisor = shifted_remainder >= {1'b0, divisor_abs};
wire [32:0] next_remainder = subtract_divisor
                            ? shifted_remainder - {1'b0, divisor_abs}
                            : shifted_remainder;
wire [31:0] next_quotient = {quotient_work[30:0], subtract_divisor};
// 实验五新增：商符号为两输入符号异或，余数符号与被除数相同，商向零截断。
wire [31:0] signed_quotient = quotient_negative
                             ? (~next_quotient + 32'd1) : next_quotient;
wire [31:0] signed_remainder = remainder_negative
                              ? (~next_remainder[31:0] + 32'd1)
                              : next_remainder[31:0];

// 实验五新增：复位清除在途请求；busy期间只迭代，不接受新的start。
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
        // 实验五新增：本实现约定除零时商为全1、余数为被除数，并立即完成。
        if (divisor == 32'b0) begin
            quotient  <= 32'hffffffff;
            remainder <= dividend;
            busy      <= 1'b0;
            done      <= 1'b1;
        end
        else begin
            // 实验五新增：锁存幅值和符号，随后输入变化不影响正在执行的除法。
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
        // 实验五新增：每周期产生一位商；计数0到31共32轮，最后一轮输出并保持结果。
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
