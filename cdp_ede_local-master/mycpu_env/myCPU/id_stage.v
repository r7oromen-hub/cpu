`include "mycpu_head.v"
`timescale 1ns / 1ps

module id_stage #(parameter FORWARDING = 1)(
    input  wire                         clk,
    input  wire                         reset,
    input  wire                         es_allowin,
    input  wire                         fs_to_ds_valid,
    input  wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus,
    input  wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    input  wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus,
    input  wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus,
    output wire                         ds_allowin,
    output wire                         ds_to_es_valid,
    output wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus,
    output wire [`BR_BUS_WD       -1:0] br_bus
);

reg                          ds_valid;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
wire                         ds_ready_go;
wire [31:0]                  ds_inst;
wire [31:0]                  ds_pc;

assign {ds_inst, ds_pc} = fs_to_ds_bus_r;

assign ds_ready_go    = !raw_stall;
assign ds_allowin     = !ds_valid || (ds_ready_go && es_allowin);
assign ds_to_es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

assign op_31_26 = ds_inst[31:26];
assign op_25_22 = ds_inst[25:22];
assign op_21_20 = ds_inst[21:20];
assign op_19_15 = ds_inst[19:15];
assign rd       = ds_inst[ 4: 0];
assign rj       = ds_inst[ 9: 5];
assign rk       = ds_inst[14:10];
assign i12      = ds_inst[21:10];
assign i20      = ds_inst[24: 5];
assign i16      = ds_inst[25:10];
assign i26      = {ds_inst[9:0], ds_inst[25:10]};

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));
decoder_4_16 u_dec1(.in(op_25_22), .out(op_25_22_d));
decoder_2_4  u_dec2(.in(op_21_20), .out(op_21_20_d));
decoder_5_32 u_dec3(.in(op_19_15), .out(op_19_15_d));

wire inst_add_w;
wire inst_sub_w;
wire inst_slt;
wire inst_sltu;
// 实验三新增：立即数比较SLTI/SLTUI的识别信号。
wire inst_slti;
wire inst_sltui;
wire inst_nor;
wire inst_and;
wire inst_or;
wire inst_xor;
// 实验三新增：ANDI/ORI/XORI逻辑立即数运算，以及SLL.W/SRL.W/SRA.W寄存器移位。
wire inst_andi;
wire inst_ori;
wire inst_xori;
wire inst_sll_w;
wire inst_srl_w;
wire inst_sra_w;
wire inst_slli_w;
wire inst_srli_w;
wire inst_srai_w;
wire inst_addi_w;
wire inst_ld_w;
wire inst_st_w;
wire inst_jirl;
wire inst_b;
wire inst_bl;
wire inst_beq;
wire inst_bne;
wire inst_lu12i_w;
// 实验三新增：PC相对加法PCADDU12I，以及BLT/BGE/BLTU/BGEU四条条件分支。
wire inst_pcaddu12i;
wire inst_blt;
wire inst_bge;
wire inst_bltu;
wire inst_bgeu;

assign inst_add_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
// 实验三新增：按指令编码识别SLTI/SLTUI；两个字段的匹配结果都为1才成立。
assign inst_slti    = op_31_26_d[6'h00] & op_25_22_d[4'h8];
assign inst_sltui   = op_31_26_d[6'h00] & op_25_22_d[4'h9];
assign inst_nor     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
// 实验三新增：逻辑立即数指令只需匹配[31:26]和[25:22]，低位保留给立即数与寄存器。
assign inst_andi    = op_31_26_d[6'h00] & op_25_22_d[4'hd];
assign inst_ori     = op_31_26_d[6'h00] & op_25_22_d[4'he];
assign inst_xori    = op_31_26_d[6'h00] & op_25_22_d[4'hf];
// 实验三新增：寄存器移位指令匹配四个操作码字段；移位量来自rk寄存器值的低5位。
assign inst_sll_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
assign inst_srl_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
assign inst_sra_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
assign inst_slli_w  = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w  = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w  = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w  = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl    = op_31_26_d[6'h13];
assign inst_b       = op_31_26_d[6'h14];
assign inst_bl      = op_31_26_d[6'h15];
assign inst_beq     = op_31_26_d[6'h16];
assign inst_bne     = op_31_26_d[6'h17];
assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];
// 实验三新增：识别PCADDU12I，计算当前指令PC加上左移12位的立即数。
assign inst_pcaddu12i = op_31_26_d[6'h07] & ~ds_inst[25];
// 实验三新增：四条大小比较分支以[31:26]区分；BLT/BGE有符号，BLTU/BGEU无符号。
assign inst_blt     = op_31_26_d[6'h18];
assign inst_bge     = op_31_26_d[6'h19];
assign inst_bltu    = op_31_26_d[6'h1a];
assign inst_bgeu    = op_31_26_d[6'h1b];

// 实验三新增：统一六条条件分支的分组信号，后续替换原来仅检查BEQ/BNE的条件。
wire inst_cond_branch = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;

// 实验三修改：将新指令加入原有ALU操作选择；比较、逻辑和移位沿用已有运算，
// PCADDU12I使用加法。ALU控制仍为12位，不新增运算单元或级间总线字段。
wire [11:0] alu_op;
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl | inst_pcaddu12i;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltui;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_slli_w | inst_sll_w;
assign alu_op[ 9] = inst_srli_w | inst_srl_w;
assign alu_op[10] = inst_srai_w | inst_sra_w;
assign alu_op[11] = inst_lu12i_w;

wire        need_ui5;
// 实验三新增：标识12位逻辑立即数，区别于原来的符号扩展立即数。
wire        need_ui12;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;
wire        src_reg_is_rd;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

assign need_ui5  = inst_slli_w | inst_srli_w | inst_srai_w;
// 实验三新增：ANDI/ORI/XORI选零扩展ui12；PCADDU12I复用高20位立即数格式。
assign need_ui12 = inst_andi | inst_ori | inst_xori;
assign need_si20 = inst_lu12i_w | inst_pcaddu12i;
assign need_si26 = inst_b | inst_bl;
assign src2_is_4 = inst_jirl | inst_bl;

// 实验三修改：增加need_ui12分支，高20位补0；PCADDU12I使用{i20,12'b0}。
// SLTI/SLTUI仍走最后的si12符号扩展路径；SLTUI的U表示比较无符号，不表示零扩展。
assign imm = src2_is_4 ? 32'd4 :
             need_si20 ? {i20, 12'b0} :
             need_ui5  ? {27'b0, rk} :
             need_ui12 ? {20'b0, i12} :
                         {{20{i12[11]}}, i12};

assign br_offs = need_si26 ? {{4{i26[25]}}, i26, 2'b0}
                            : {{14{i16[15]}}, i16, 2'b0};
assign jirl_offs = {{14{i16[15]}}, i16, 2'b0};

// 实验三修改：四条新增条件分支和BEQ/BNE一样从rd读取第二个比较操作数。
assign src_reg_is_rd = inst_cond_branch | inst_st_w;
// 实验三修改：PCADDU12I的第一个ALU操作数选当前指令PC，而不是rj。
assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;
// 实验三修改：SLTI/SLTUI、逻辑立即数和PCADDU12I选择imm；寄存器移位选择rk寄存器的值。
assign src2_is_imm   = inst_slli_w | inst_srli_w | inst_srai_w |
                       inst_addi_w | inst_ld_w   | inst_st_w   |
                       inst_lu12i_w| inst_jirl   | inst_bl |
                       inst_slti | inst_sltui | need_ui12 | inst_pcaddu12i;
assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
// 实验三修改：九条新增运算指令允许写回rd；四条新增条件分支不写通用寄存器。
assign gr_we         = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                       inst_nor | inst_and | inst_or | inst_xor |
                       inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                       inst_ld_w | inst_jirl | inst_bl | inst_lu12i_w |
                       inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori |
                       inst_sll_w | inst_srl_w | inst_sra_w | inst_pcaddu12i;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

wire        rf_we;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

assign {rf_we, rf_waddr, rf_wdata} = ws_to_rf_bus;
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;

regfile u_regfile(
    .clk    (clk       ),
    .raddr1 (rf_raddr1 ),
    .rdata1 (rf_rdata1 ),
    .raddr2 (rf_raddr2 ),
    .rdata2 (rf_rdata2 ),
    .we     (rf_we     ),
    .waddr  (rf_waddr  ),
    .wdata  (rf_wdata  )
);

wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] alu_src1;
wire [31:0] alu_src2;
wire        rj_eq_rd;
// 实验三新增：有符号/无符号小于比较结果，供四条新增分支使用。
wire        rj_lt_rd;
wire        rj_ltu_rd;
wire        br_taken;
wire [31:0] br_target;
wire        src1_used;
wire        src2_used;
wire        es_writes;
wire        es_load;
wire [ 4:0] es_dest;
wire [31:0] es_result;
wire        ms_writes;
wire [ 4:0] ms_dest;
wire [31:0] ms_result;
wire        es_hit1, es_hit2, ms_hit1, ms_hit2, ws_hit1, ws_hit2;
wire        raw_stall;

// 实验三修改：新增立即数运算、寄存器移位和条件分支都读取rj，加入源1检测。
// PCADDU12I不读通用寄存器，因此不加入，避免把立即数字段误判为寄存器相关。
assign src1_used = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                   inst_nor | inst_and | inst_or | inst_xor |
                   inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                   inst_ld_w | inst_st_w | inst_jirl | inst_cond_branch |
                   inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori |
                   inst_sll_w | inst_srl_w | inst_sra_w;
// 实验三修改：寄存器移位还读取rk，条件分支还读取rd；新增立即数运算不读取源2。
// 扩展这两个使用掩码后，新指令才能正确接入既有阻塞和前递。
assign src2_used = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                   inst_nor | inst_and | inst_or | inst_xor |
                   inst_st_w | inst_cond_branch | inst_sll_w | inst_srl_w | inst_sra_w;
assign {es_writes, es_load, es_dest, es_result} = es_to_ds_bus;
assign {ms_writes, ms_dest, ms_result} = ms_to_ds_bus;
assign es_hit1 = src1_used && rf_raddr1 != 0 && es_writes && rf_raddr1 == es_dest;
assign es_hit2 = src2_used && rf_raddr2 != 0 && es_writes && rf_raddr2 == es_dest;
assign ms_hit1 = src1_used && rf_raddr1 != 0 && ms_writes && rf_raddr1 == ms_dest;
assign ms_hit2 = src2_used && rf_raddr2 != 0 && ms_writes && rf_raddr2 == ms_dest;
assign ws_hit1 = src1_used && rf_raddr1 != 0 && rf_we && rf_waddr != 0 && rf_raddr1 == rf_waddr;
assign ws_hit2 = src2_used && rf_raddr2 != 0 && rf_we && rf_waddr != 0 && rf_raddr2 == rf_waddr;
assign raw_stall = ds_valid && (FORWARDING ?
                   (es_load && (es_hit1 || es_hit2)) :
                   (es_hit1 || es_hit2 || ms_hit1 || ms_hit2 || ws_hit1 || ws_hit2));

assign rj_value  = !FORWARDING ? rf_rdata1 :
                   es_hit1 ? es_result : ms_hit1 ? ms_result :
                   ws_hit1 ? rf_wdata : rf_rdata1;
assign rkd_value = !FORWARDING ? rf_rdata2 :
                   es_hit2 ? es_result : ms_hit2 ? ms_result :
                   ws_hit2 ? rf_wdata : rf_rdata2;
assign alu_src1  = src1_is_pc ? ds_pc : rj_value;
assign alu_src2  = src2_is_imm ? imm : rkd_value;

assign rj_eq_rd = (rj_value == rkd_value);
// 实验三新增：用经过既有前递选择的操作数比较；BLT/BGE按有符号数，BLTU/BGEU按无符号数。
assign rj_lt_rd = ($signed(rj_value) < $signed(rkd_value));
assign rj_ltu_rd = (rj_value < rkd_value);
// 实验三修改：加入BLT/BGE/BLTU/BGEU跳转条件，大于等于通过“小于”取反得到。
// 新分支也必须等ID真正发射后才跳转，沿用原有握手和复位限制。
assign br_taken = ((inst_beq &&  rj_eq_rd) ||
                   (inst_bne && !rj_eq_rd) ||
                   (inst_blt && rj_lt_rd) || (inst_bge && !rj_lt_rd) ||
                   (inst_bltu && rj_ltu_rd) || (inst_bgeu && !rj_ltu_rd) ||
                    inst_jirl || inst_bl || inst_b) &&
                   ds_to_es_valid && es_allowin && !reset;
// 实验三修改：把原来BEQ/BNE的目标选择扩展到整组条件分支；
// 新分支目标同样为当前PC加符号扩展后左移2位的si16偏移。
assign br_target = (inst_cond_branch || inst_bl || inst_b)
                 ? ds_pc + br_offs
                 : rj_value + jirl_offs;

assign br_bus = {br_taken, br_target};
assign ds_to_es_bus = {
    res_from_mem,
    mem_we,
    gr_we,
    dest,
    alu_op,
    alu_src1,
    alu_src2,
    rkd_value,
    ds_pc
};

endmodule
