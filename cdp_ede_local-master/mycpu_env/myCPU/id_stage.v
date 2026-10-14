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
wire inst_nor;
wire inst_and;
wire inst_or;
wire inst_xor;
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

assign inst_add_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
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

wire [11:0] alu_op;
assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

wire        need_ui5;
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
assign need_si20 = inst_lu12i_w;
assign need_si26 = inst_b | inst_bl;
assign src2_is_4 = inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'd4 :
             need_si20 ? {i20, 12'b0} :
             need_ui5  ? {27'b0, rk} :
                         {{20{i12[11]}}, i12};

assign br_offs = need_si26 ? {{4{i26[25]}}, i26, 2'b0}
                            : {{14{i16[15]}}, i16, 2'b0};
assign jirl_offs = {{14{i16[15]}}, i16, 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;
assign src1_is_pc    = inst_jirl | inst_bl;
assign src2_is_imm   = inst_slli_w | inst_srli_w | inst_srai_w |
                       inst_addi_w | inst_ld_w   | inst_st_w   |
                       inst_lu12i_w| inst_jirl   | inst_bl;
assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                       inst_nor | inst_and | inst_or | inst_xor |
                       inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                       inst_ld_w | inst_jirl | inst_bl | inst_lu12i_w;
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

// Immediate fields overlap rk/rj encodings; compare only genuinely read
// operands. jirl uses rj for its target even though the ALU uses PC.
assign src1_used = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                   inst_nor | inst_and | inst_or | inst_xor |
                   inst_slli_w | inst_srli_w | inst_srai_w | inst_addi_w |
                   inst_ld_w | inst_st_w | inst_jirl | inst_beq | inst_bne;
assign src2_used = inst_add_w | inst_sub_w | inst_slt | inst_sltu |
                   inst_nor | inst_and | inst_or | inst_xor |
                   inst_st_w | inst_beq | inst_bne;
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

// Closest (youngest) producer wins. An EXE load hit stalls rather than using
// an older MEM/WB value of the same register.
assign rj_value  = !FORWARDING ? rf_rdata1 :
                   es_hit1 ? es_result : ms_hit1 ? ms_result :
                   ws_hit1 ? rf_wdata : rf_rdata1;
assign rkd_value = !FORWARDING ? rf_rdata2 :
                   es_hit2 ? es_result : ms_hit2 ? ms_result :
                   ws_hit2 ? rf_wdata : rf_rdata2;
assign alu_src1  = src1_is_pc ? ds_pc : rj_value;
assign alu_src2  = src2_is_imm ? imm : rkd_value;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = ((inst_beq &&  rj_eq_rd) ||
                   (inst_bne && !rj_eq_rd) ||
                    inst_jirl || inst_bl || inst_b) &&
                   ds_to_es_valid && es_allowin && !reset;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b)
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
