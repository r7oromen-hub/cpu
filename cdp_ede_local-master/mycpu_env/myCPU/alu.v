`timescale 1ns / 1ps

module alu(
    input  wire [11:0] alu_op,
    input  wire [31:0] alu_src1,
    input  wire [31:0] alu_src2,
    output wire [31:0] alu_result
);

wire op_add;
wire op_sub;
wire op_slt;
wire op_sltu;
wire op_and;
wire op_nor;
wire op_or;
wire op_xor;
wire op_sll;
wire op_srl;
wire op_sra;
wire op_lui;

assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];

wire [31:0] add_sub_result;
wire [31:0] slt_result;
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result;
wire [31:0] srl_result;
wire [31:0] sra_result;

assign add_sub_result = op_sub ? (alu_src1 - alu_src2)
                               : (alu_src1 + alu_src2);
assign slt_result      = {31'b0, $signed(alu_src1) < $signed(alu_src2)};
assign sltu_result     = {31'b0, alu_src1 < alu_src2};
assign and_result      = alu_src1 & alu_src2;
assign nor_result      = ~(alu_src1 | alu_src2);
assign or_result       = alu_src1 | alu_src2;
assign xor_result      = alu_src1 ^ alu_src2;
assign lui_result      = alu_src2;
assign sll_result      = alu_src1 << alu_src2[4:0];
assign srl_result      = alu_src1 >> alu_src2[4:0];
assign sra_result      = $signed(alu_src1) >>> alu_src2[4:0];

assign alu_result = ({32{op_add | op_sub}} & add_sub_result)
                  | ({32{op_slt         }} & slt_result)
                  | ({32{op_sltu        }} & sltu_result)
                  | ({32{op_and         }} & and_result)
                  | ({32{op_nor         }} & nor_result)
                  | ({32{op_or          }} & or_result)
                  | ({32{op_xor         }} & xor_result)
                  | ({32{op_lui         }} & lui_result)
                  | ({32{op_sll         }} & sll_result)
                  | ({32{op_srl         }} & srl_result)
                  | ({32{op_sra         }} & sra_result);

endmodule
