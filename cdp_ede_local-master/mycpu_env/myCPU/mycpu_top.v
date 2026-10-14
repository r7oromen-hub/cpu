`include "mycpu_head.v"
`timescale 1ns / 1ps

module mycpu_top #(
`ifdef STALL_ONLY
    parameter FORWARDING = 0
`else
    parameter FORWARDING = 1
`endif
)(
    input  wire        clk,
    input  wire        resetn,

    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

reg reset;
always @(posedge clk) begin
    reset <= ~resetn;
end

wire                         fs_to_ds_valid;
wire                         ds_to_es_valid;
wire                         es_to_ms_valid;
wire                         ms_to_ws_valid;
wire                         ds_allowin;
wire                         es_allowin;
wire                         ms_allowin;
wire                         ws_allowin;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`ES_TO_DS_BUS_WD -1:0] es_to_ds_bus;
wire [`MS_TO_DS_BUS_WD -1:0] ms_to_ds_bus;

if_stage u_if_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    .ds_allowin      (ds_allowin      ),
    .br_bus          (br_bus          ),
    .fs_to_ds_valid  (fs_to_ds_valid  ),
    .fs_to_ds_bus    (fs_to_ds_bus    ),
    .inst_sram_en    (inst_sram_en    ),
    .inst_sram_we    (inst_sram_we    ),
    .inst_sram_addr  (inst_sram_addr  ),
    .inst_sram_wdata (inst_sram_wdata ),
    .inst_sram_rdata (inst_sram_rdata )
);

id_stage #(.FORWARDING(FORWARDING)) u_id_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    .es_allowin      (es_allowin      ),
    .fs_to_ds_valid  (fs_to_ds_valid  ),
    .fs_to_ds_bus    (fs_to_ds_bus    ),
    .ws_to_rf_bus    (ws_to_rf_bus    ),
    .es_to_ds_bus    (es_to_ds_bus    ),
    .ms_to_ds_bus    (ms_to_ds_bus    ),
    .ds_allowin      (ds_allowin      ),
    .ds_to_es_valid  (ds_to_es_valid  ),
    .ds_to_es_bus    (ds_to_es_bus    ),
    .br_bus          (br_bus          )
);

exe_stage u_exe_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    .ms_allowin      (ms_allowin      ),
    .ds_to_es_valid  (ds_to_es_valid  ),
    .ds_to_es_bus    (ds_to_es_bus    ),
    .es_allowin      (es_allowin      ),
    .es_to_ms_valid  (es_to_ms_valid  ),
    .es_to_ms_bus    (es_to_ms_bus    ),
    .es_to_ds_bus    (es_to_ds_bus    ),
    .data_sram_en    (data_sram_en    ),
    .data_sram_we    (data_sram_we    ),
    .data_sram_addr  (data_sram_addr  ),
    .data_sram_wdata (data_sram_wdata )
);

mem_stage u_mem_stage(
    .clk             (clk             ),
    .reset           (reset           ),
    .ws_allowin      (ws_allowin      ),
    .es_to_ms_valid  (es_to_ms_valid  ),
    .es_to_ms_bus    (es_to_ms_bus    ),
    .data_sram_rdata (data_sram_rdata ),
    .ms_allowin      (ms_allowin      ),
    .ms_to_ws_valid  (ms_to_ws_valid  ),
    .ms_to_ws_bus    (ms_to_ws_bus    ),
    .ms_to_ds_bus    (ms_to_ds_bus    )
);

wb_stage u_wb_stage(
    .clk               (clk               ),
    .reset             (reset             ),
    .ms_to_ws_valid    (ms_to_ws_valid    ),
    .ms_to_ws_bus      (ms_to_ws_bus      ),
    .ws_allowin        (ws_allowin        ),
    .ws_to_rf_bus      (ws_to_rf_bus      ),
    .debug_wb_pc       (debug_wb_pc       ),
    .debug_wb_rf_we    (debug_wb_rf_we    ),
    .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
    .debug_wb_rf_wdata (debug_wb_rf_wdata )
);

endmodule
