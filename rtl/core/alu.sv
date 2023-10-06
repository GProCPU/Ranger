`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module alu #(
        
    ) (
        // clock not needed; module is purely combinatorial
        // reset not needed; module is combinatorial and stateless

        input alu_op_t alu_op,                  // operation select
        input rv32::signed_word src1,           // left-side operand
        input rv32::signed_word src2,           // right-side operand

        output rv32::signed_word result,        // arithmetic or logic result
        output logic zero                       // result zero flag
    );

    rv32::word unsigned_src1;
    rv32::word unsigned_src2;
    logic [4:0] shamt; // shift amount
    assign unsigned_src1 = src1;
    assign unsigned_src2 = src2;
    assign shamt = src2[4:0];

    assign zero = (result==0) ? 1 : 0;


    always_comb begin
        case (alu_op)
            ALU_ADD:    result = src1 + src2;
            ALU_SLL:    result = src1 << shamt;
            ALU_SLTU:   result = (unsigned_src1 < unsigned_src2) ? 1 : 0;
            ALU_SGEU:   result = (unsigned_src1 >= unsigned_src2) ? 1 : 0;
            ALU_XOR:    result = src1 ^ src2;
            ALU_SRL:    result = src1 >> shamt;
            ALU_OR:     result = src1 | src2;
            ALU_AND:    result = src1 & src2;
            ALU_SUB:    result = src1 - src2;
            ALU_SLT:    result = (src1 < src2) ? 1 : 0;
            ALU_SGE:    result = (src1 >= src2) ? 1 : 0;
            ALU_SRA:    result = src1 >>> shamt;
            ALU_NOP:    result = src1;
            default:    result = src1;
        endcase
    end


endmodule