`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module rom #(
        parameter ADDR_WIDTH    = DEFAULT_ROM_ADDR_WIDTH    // word-addressable address bits
    ) (
        // clock not needed; module is asynchronous
        // reset not needed; module is read-only

        input  logic rd_en1,                                // read enable 1
        input  logic [ADDR_WIDTH-1:0] addr1,                // read address 1 (word-addressable)
        output rv32::word rd_data1,                         // read data 1

        input  logic rd_en2,                                // read enable 2
        input  logic [ADDR_WIDTH-1:0] addr2,                // read address 2 (word-addressable)
        output rv32::word rd_data2                          // read data 2
    );

    localparam DEPTH = 2 ** ADDR_WIDTH;
    rv32::word data [DEPTH-1:0];

    initial begin
        $readmemh("rom.hex", data, 0, DEPTH-1);
    end


    assign rd_data1 = (rd_en1) ? data[addr1] : 0;
    assign rd_data2 = (rd_en2) ? data[addr2] : 0;

endmodule
