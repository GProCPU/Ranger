`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module pc #(
        
    ) (
        input logic clk,                    // system clock
        input logic rst_n,                  // global synchronous reset (active-low)
        input rv32::word next_pc,           // next program counter value
        output rv32::word pc                // current program counter value
    );


    always_ff @(posedge clk) begin
        if (!rst_n) begin
            pc <= 0;
        end
        else begin
            pc <= next_pc;
        end
    end

endmodule
