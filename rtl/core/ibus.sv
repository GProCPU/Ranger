`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module ibus #(
        parameter ROM_ADDR_WIDTH    = DEFAULT_ROM_ADDR_WIDTH,       // ROM address width (word-addressable, default 4kB)
        parameter ROM_BASE_ADDR     = DEFAULT_ROM_BASE_ADDR         // ROM base address (must be aligned to ROM size)
    ) (
        // clock not needed; module is asynchronous
        // reset not needed; module is read-only

        input  logic rd_en,                                         // read enable flag from Fetch Unit
        input  rv32::word addr,                                     // *byte-addressable* read address from Fetch Unit
        input  rv32::word rom_rd_data,                              // read data from ROM
        output logic rom_rd_en,                                     // read enable flag to ROM
        output [ROM_ADDR_WIDTH-1:0] rom_addr,                       // *word-addressable* read address to ROM
        output rv32::word rd_data,                                  // read data to Fetch unit
        output logic inst_access_fault                              // instruction access fault exception flag
    );

    localparam PREFIX_ADDR_WIDTH = rv32::XLEN - ROM_ADDR_WIDTH - 2;
    logic [PREFIX_ADDR_WIDTH-1:0] address_prefix;
    assign address_prefix = addr[rv32::XLEN-1:ROM_ADDR_WIDTH+2];

    assign rom_rd_en            = rd_en & (~inst_access_fault);
    assign rom_addr             = addr[(ROM_ADDR_WIDTH+2)-1:2];
    assign rd_data              = (rom_rd_en) ? rom_rd_data : 0;
    assign inst_access_fault    = (address_prefix != ROM_BASE_ADDR[rv32::XLEN-1:ROM_ADDR_WIDTH+2]);

endmodule