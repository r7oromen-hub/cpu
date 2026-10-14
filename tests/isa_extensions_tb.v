`timescale 1ns/1ps

// CPU-level directed ISA checks.  All operands come from executed instructions;
// back-to-back dependencies therefore exercise the inherited hazard controls.
module isa_extensions_tb;
    localparam BASE = 32'h1c000000;
    reg clk = 0;
    always #5 clk = ~clk;
    reg resetn = 0;
    wire inst_en, data_en;
    wire [3:0] inst_we, data_we;
    wire [31:0] inst_addr, inst_wdata, data_addr, data_wdata;
    reg [31:0] inst_rdata, data_rdata;
    wire [31:0] debug_pc, debug_data;
    wire [3:0] debug_we;
    wire [4:0] debug_dest;
    reg [31:0] imem [0:4095];
    reg [31:0] dmem [0:1023];
    reg [31:0] expected_pc [0:1023];
    reg [31:0] expected_data [0:1023];
    reg [4:0] expected_dest [0:1023];
    integer program_words = 0, expected_count = 0, actual_count = 0;
    integer i, lane, cycles = 0;
    reg [31:0] op_pc;

    mycpu_top dut(
        .clk(clk), .resetn(resetn),
        .inst_sram_en(inst_en), .inst_sram_we(inst_we),
        .inst_sram_addr(inst_addr), .inst_sram_wdata(inst_wdata),
        .inst_sram_rdata(inst_rdata),
        .data_sram_en(data_en), .data_sram_we(data_we),
        .data_sram_addr(data_addr), .data_sram_wdata(data_wdata),
        .data_sram_rdata(data_rdata),
        .debug_wb_pc(debug_pc), .debug_wb_rf_we(debug_we),
        .debug_wb_rf_wnum(debug_dest), .debug_wb_rf_wdata(debug_data)
    );

    // Same one-cycle synchronous, little-endian SRAM contract as the course SoC.
    always @(posedge clk) begin
        if (inst_en) inst_rdata <= imem[(inst_addr - BASE) >> 2];
        if (data_en) begin
            data_rdata <= dmem[data_addr[11:2]];
            for (lane = 0; lane < 4; lane = lane + 1)
                if (data_we[lane])
                    dmem[data_addr[11:2]][lane*8 +: 8] <= data_wdata[lane*8 +: 8];
        end
    end

    function [31:0] i12;
        input [31:0] opcode;
        input [4:0] rd, rj;
        input [11:0] imm;
        begin i12 = opcode | {10'b0, imm, rj, rd}; end
    endfunction
    function [31:0] r3;
        input [31:0] opcode;
        input [4:0] rd, rj, rk;
        begin r3 = opcode | {17'b0, rk, rj, rd}; end
    endfunction
    function [31:0] b16;
        input [31:0] opcode;
        input [4:0] rj, rd;
        input [15:0] offset_words;
        begin b16 = opcode | {6'b0, offset_words, rj, rd}; end
    endfunction
    task emit;
        input [31:0] inst;
        begin
            imem[program_words] = inst;
            program_words = program_words + 1;
        end
    endtask
    task expect_wb;
        input [31:0] pc;
        input [4:0] dest;
        input [31:0] result;
        begin
            expected_pc[expected_count] = pc;
            expected_dest[expected_count] = dest;
            expected_data[expected_count] = result;
            expected_count = expected_count + 1;
        end
    endtask
    task emit_wb;
        input [31:0] inst;
        input [4:0] dest;
        input [31:0] result;
        begin
            expect_wb(BASE + program_words*4, dest, result);
            emit(inst);
        end
    endtask
    task branch_case;
        input [31:0] opcode;
        input [4:0] rj, rd;
        input taken;
        begin
            emit(b16(opcode, rj, rd, 16'd3));
            if (taken) begin
                // Neither this write nor this store may survive redirect.
                emit(i12(32'h02800000, 5'd20, 5'd0, 12'd99));
                emit(i12(32'h29800000, 5'd3, 5'd0, 12'd0));
            end else begin
                emit_wb(i12(32'h02800000, 5'd20, 5'd0, 12'd99), 5'd20, 32'd99);
                emit(32'h03400000); // nop
            end
            emit_wb(i12(32'h02800000, 5'd21, 5'd0, 12'd77), 5'd21, 32'd77);
        end
    endtask

    initial begin
        for (i = 0; i < 4096; i = i + 1) imem[i] = 32'h03400000;
        for (i = 0; i < 1024; i = i + 1) dmem[i] = 0;
        emit_wb(32'h15000001, 5'd1, 32'h80000000); // lu12i.w r1, 0x80000
        emit_wb(32'h14ffffe2, 5'd2, 32'h7ffff000); // lu12i.w r2, 0x7ffff
        emit_wb(i12(32'h03800000, 5'd2, 5'd2, 12'hfff), 5'd2, 32'h7fffffff);
        emit_wb(i12(32'h02800000, 5'd3, 5'd0, 12'hfff), 5'd3, 32'hffffffff);
        emit_wb(i12(32'h02800000, 5'd5, 5'd0, 12'd32), 5'd5, 32'd32);
        emit_wb(i12(32'h02800000, 5'd6, 5'd0, 12'd63), 5'd6, 32'd63);

        // Signed immediate compare, and SLTUI's easily missed sign extension.
        emit_wb(i12(32'h02000000, 5'd10, 5'd1, 12'h800), 5'd10, 32'd1);
        emit_wb(i12(32'h02000000, 5'd10, 5'd2, 12'hfff), 5'd10, 32'd0);
        emit_wb(i12(32'h02000000, 5'd10, 5'd3, 12'h000), 5'd10, 32'd1);
        emit_wb(i12(32'h02400000, 5'd10, 5'd1, 12'hfff), 5'd10, 32'd1);
        emit_wb(i12(32'h02400000, 5'd10, 5'd1, 12'h7ff), 5'd10, 32'd0);
        emit_wb(i12(32'h02400000, 5'd10, 5'd3, 12'hfff), 5'd10, 32'd0);
        // Logical immediates must zero extend even when their bit 11 is 1.
        emit_wb(i12(32'h03400000, 5'd10, 5'd3, 12'hfff), 5'd10, 32'h00000fff);
        emit_wb(i12(32'h03800000, 5'd10, 5'd1, 12'h800), 5'd10, 32'h80000800);
        emit_wb(i12(32'h03c00000, 5'd10, 5'd3, 12'hfff), 5'd10, 32'hfffff000);
        // Register shift amounts 32 and 63 test the low-five-bit rule.
        emit_wb(r3(32'h00170000, 5'd10, 5'd1, 5'd5), 5'd10, 32'h80000000);
        emit_wb(r3(32'h00170000, 5'd10, 5'd3, 5'd6), 5'd10, 32'h80000000);
        emit_wb(r3(32'h00178000, 5'd10, 5'd1, 5'd6), 5'd10, 32'd1);
        emit_wb(r3(32'h00180000, 5'd10, 5'd1, 5'd6), 5'd10, 32'hffffffff);
        emit_wb(r3(32'h00180000, 5'd10, 5'd2, 5'd6), 5'd10, 32'd0);
        emit_wb(r3(32'h00178000, 5'd10, 5'd1, 5'd0), 5'd10, 32'h80000000);
        op_pc = BASE + program_words*4;
        emit_wb(32'h1c00000a, 5'd10, op_pc); // pcaddu12i r10, 0
        op_pc = BASE + program_words*4;
        emit_wb(32'h1c00002a, 5'd10, op_pc + 32'h1000);
        op_pc = BASE + program_words*4;
        emit_wb(32'h1dffffea, 5'd10, op_pc - 32'h1000);

        branch_case(32'h60000000, 5'd1, 5'd2, 1'b1); // negative < positive
        branch_case(32'h60000000, 5'd2, 5'd1, 1'b0);
        branch_case(32'h64000000, 5'd2, 5'd1, 1'b1);
        branch_case(32'h64000000, 5'd1, 5'd1, 1'b1); // equality
        branch_case(32'h64000000, 5'd1, 5'd2, 1'b0);
        branch_case(32'h68000000, 5'd1, 5'd2, 1'b0); // unsigned differs
        branch_case(32'h68000000, 5'd2, 5'd1, 1'b1);
        branch_case(32'h6c000000, 5'd1, 5'd2, 1'b1);
        branch_case(32'h6c000000, 5'd2, 5'd1, 1'b0);
        branch_case(32'h6c000000, 5'd3, 5'd3, 1'b1);

        // Backward, negative branch displacement with an immediate dependency.
        emit_wb(i12(32'h02800000, 5'd7, 5'd0, 12'd2), 5'd7, 32'd2);
        op_pc = BASE + program_words*4;
        emit_wb(i12(32'h02800000, 5'd7, 5'd7, 12'hfff), 5'd7, 32'd1);
        emit(b16(32'h64000000, 5'd7, 5'd0, 16'hffff));
        expect_wb(op_pc, 5'd7, 32'd0);
        expect_wb(op_pc, 5'd7, 32'hffffffff);
        emit_wb(i12(32'h02800000, 5'd22, 5'd0, 12'h123), 5'd22, 32'h123);
        emit(32'h50000000); // b 0, stop producing architectural writes
        repeat (5) @(negedge clk);
        resetn = 1;
    end

    always @(posedge clk) begin
        if (resetn) begin
            cycles = cycles + 1;
            if ((|debug_we) && debug_dest != 0) begin
                if (actual_count >= expected_count)
                    $fatal(1, "unexpected write pc=%h rd=%d data=%h", debug_pc, debug_dest, debug_data);
                if (debug_pc !== expected_pc[actual_count] ||
                    debug_dest !== expected_dest[actual_count] ||
                    debug_data !== expected_data[actual_count])
                    $fatal(1, "write %0d got pc=%h rd=%0d data=%h expected pc=%h rd=%0d data=%h",
                        actual_count, debug_pc, debug_dest, debug_data,
                        expected_pc[actual_count], expected_dest[actual_count], expected_data[actual_count]);
                actual_count = actual_count + 1;
            end
            if (actual_count == expected_count && cycles > 600) begin
                if (dmem[0] !== 0) $fatal(1, "wrong-path store changed memory");
                $display("DIRECTED ISA PASS: %0d writes, %0d cycles", actual_count, cycles);
                $finish;
            end
            if (cycles == 3000) $fatal(1, "timeout, matched %0d of %0d writes", actual_count, expected_count);
        end
    end
endmodule
