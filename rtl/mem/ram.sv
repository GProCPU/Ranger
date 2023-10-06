`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


(* keep_hierarchy = "yes" *)
module ram #(
        parameter ADDR_WIDTH    = DEFAULT_RAM_ADDR_WIDTH,   // word-addressable address bits
        parameter DUMP_MEM      = 0                         // set to one to enable dump of memory content
    ) (
        input wire clk,
        // reset not needed; memory can start in undefined state

        input  logic rd_en,                                 // read enable
        input  logic wr_en,                                 // write enable
        input  logic [ADDR_WIDTH-1:0] addr,                 // read/write address (word-addressable)
        input  rv32::word wr_data,                          // write data
        input  logic [(rv32::XLEN/8)-1:0] wr_strobe,        // write strobe
        output rv32::word rd_data                           // read data
    );

    localparam DEPTH = 2 ** ADDR_WIDTH;
    rv32::word data [DEPTH-1:0];


    assign rd_data = (rd_en) ? data[addr] : 0;

    generate
        for (genvar i=0; i<rv32::XLEN; i+=8) begin
            always_ff @(posedge clk) begin
                if (wr_en & wr_strobe[i/8]) begin
                    data[addr][i+7:i] <= wr_data[i+7:i];    // write byte lane
                end
            end
        end
    endgenerate

    // Dump memory for simulation
    generate
    if (DUMP_MEM) begin
        for (genvar i=0; i<DEPTH; i++) begin
            rv32::word _data;
            assign _data = data[i];
        end
    end
    endgenerate

endmodule
