`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module alu_TB;

    localparam MAX_CYCLES = 512;
    integer clk_count = 0;
    integer fail = 0;
    integer fid;

    reg clk;

    // ALU inputs
    rv32::signed_word src1;
    rv32::signed_word src2;
    alu_op_t alu_op;
    // ALU outputs
    rv32::signed_word result;
    logic zero;

    alu DUT (
        .src1,
        .src2,
        .alu_op,
        .result,
        .zero
    );


    // 10 MHz clock
    initial clk = 0;
    initial forever #50 clk = ~clk;

    initial begin
        src1 = 0;
        src2 = 0;
        alu_op = ALU_NOP;

        fid = $fopen("alu.log");
        $dumpfile("alu.vcd");
        $dumpvars(2, alu_TB);
    end


    // Stimulus and verification
    always @(posedge clk) begin
        rv32::signed_word expected;
        string op_name;
        src1 <= $random();                  // use non-blocking assignments; applies after the clock edge
        src2 <= $random();
        alu_op <= alu_op_t'($random());
        case (alu_op)
            ALU_ADD: begin
                op_name = "ADD     ";       // use blocking assignments; applies immediatly
                expected = src1 + src2;
            end
            ALU_SLL: begin
                op_name = "SLL     ";
                expected = src1 << (src2[4:0]);
            end
            ALU_SLTU: begin
                op_name = "SLTU    ";
                expected = (rv32::word'(src1) < rv32::word'(src2)) ? 1 : 0; // cast to unsigned
            end
            ALU_SGEU: begin
                op_name = "SGEU    ";
                expected = (rv32::word'(src1) >= rv32::word'(src2)) ? 1 : 0; // cast to unsigned
            end
            ALU_XOR: begin
                op_name = "XOR     ";
                expected = src1 ^ src2;
            end
            ALU_SRL: begin
                op_name = "SRL     ";
                expected = src1 >> (src2[4:0]);
            end
            ALU_OR: begin
                op_name = "OR      ";
                expected = src1 | src2;
            end
            ALU_AND: begin
                op_name = "AND     ";
                expected = src1 & src2;
            end
            ALU_SUB: begin
                op_name = "SUB     ";
                expected = src1 - src2;
            end
            ALU_SLT: begin
                op_name = "SLT     ";
                expected = (src1 < src2) ? 1 : 0;
            end
            ALU_SGE: begin
                op_name = "SGE     ";
                expected = (src1 >= src2) ? 1 : 0;
            end
            ALU_SRA: begin
                op_name = "SRA     ";
                expected = src1 >>> (src2[4:0]);
            end
            ALU_NOP: begin
                op_name = "NOP     ";
                expected = src1;
            end
            default: begin
                op_name = "INVALID ";
                expected = src1;
            end
        endcase
        $write("clk = %d    src1 = 0x%h  src2 = 0x%h", clk_count, src1, src2);
        $write("    alu_op = 0b%b %s", alu_op, op_name);
        $write("    result = 0h%h  zero = %b", result, zero);
        $fwrite(fid,"clk = %d    src1 = 0x%h  src2 = 0x%h", clk_count, src1, src2);
        $fwrite(fid,"    alu_op = 0b%b %s", alu_op, op_name);
        $fwrite(fid,"    result = 0h%h  zero = %b", result, zero);
        if (result !== expected) begin
            fail++;
            $write("    failed!");
            $fwrite(fid,"    failed!");
        end
        $write("\n");
        $fwrite(fid,"\n");
    end


    always @(posedge clk) begin
        clk_count <= clk_count + 1;
        if (clk_count >= MAX_CYCLES) begin
            if (fail) begin
                $write("\n\nFAILED %d tests\n", fail);
                $fwrite(fid,"\n\nFailed %d tests\n", fail);
            end
            else begin
                $write("\n\nPASSED all tests\n");
                $fwrite(fid,"\n\nPASSED all tests\n");
            end
            $fclose(fid);
            $finish();
        end
    end

endmodule