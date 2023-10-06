`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module regfile #(
        
    ) (
        input  logic clk,                       // write port clock
        // reset not needed, registers can start in undefined state

        input  logic rs1_en,                    // enable for read port 1
        input  rv32::gpr_addr_t rs1_addr,       // address for read port 1
        output rv32::word rs1_data,             // data for read port 1

        input  logic rs2_en,                    // enable for read port 2
        input  rv32::gpr_addr_t rs2_addr,       // address for read port 2
        output rv32::word rs2_data,             // data for read port 2

        input  logic dest_en,                   // enable for write port
        input  rv32::gpr_addr_t dest_addr,      // address for write port
        input  rv32::word dest_data             // data for write port

    );

    rv32::word data [rv32::REG_COUNT-1:1];

    assign rs1_data = (rs1_en && rs1_addr) ? data[rs1_addr] : 0;
    assign rs2_data = (rs2_en && rs2_addr) ? data[rs2_addr] : 0;

    always_ff @(posedge clk) begin
        if (dest_en && dest_addr) begin
            data[dest_addr] <= dest_data;
        end
    end


    // Unpack registers for simulation
    genvar i;
    generate
    for (i=1; i<rv32::REG_COUNT; i++) begin
        rv32::word register;
        assign register = data[i];
    end
    endgenerate

endmodule
