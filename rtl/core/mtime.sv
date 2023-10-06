`timescale 1ns/1ps


`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module mtime #(
        parameter CLK_PERIOD   = DEFAULT_CLK_PERIOD    // system clock period in ns
    ) (
        input  logic clk,                                   // system clock
        input  logic rst_n,                                 // reset (active-low)

        input  logic rd_en,                                 // read enable from DBus
        input  logic wr_en,                                 // write enable from DBus
        input  logic [1:0] addr,                            // read/write address from DBus
        input  rv32::word wr_data,                          // write data from DBus
        input  logic [(rv32::XLEN/8)-1:0] wr_strobe,        // byte enable for writes from DBus
        output rv32::word rd_data,                          // read data to DBus
        output logic [63:0] time_rd_data,                   // read-only time(h) CSR
        output logic interrupt                              // machine timer interrupt flag
    );

    logic [63:0] mtime;
    logic [63:0] mtimecmp;

    // internal counter
    integer counter;
    logic tick;

    assign time_rd_data = mtime;
    assign interrupt = (mtime >= mtimecmp);


    // Read logic
    always_comb begin
        if (rd_en) begin
            case (addr)
                'b00: rd_data = mtime[31:0];
                'b01: rd_data = mtime[63:32];
                'b10: rd_data = mtimecmp[31:0];
                'b11: rd_data = mtimecmp[63:32];
            endcase
        end
        else begin
            rd_data = 0;
        end
    end


    // Write and Increment logic
    rv32::word _wr_data;
    generate
        for (genvar i=0; i<rv32::XLEN; i+=8) begin
            assign _wr_data[i+7:i] = (wr_strobe[i/8]) ? wr_data[i+7:i] : 0;
        end
    endgenerate
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            mtime    <= 0;
            mtimecmp <= 0;
        end
        else begin

            // Increment
            // overwritten by writes
            if (tick) mtime <= mtime + 1;

            // Write
            if (wr_en) begin
                case (addr)
                    'b00: mtime[31:0]       <= _wr_data;
                    'b01: mtime[63:32]      <= _wr_data;
                    'b10: mtimecmp[31:0]    <= _wr_data;
                    'b11: mtimecmp[63:32]   <= _wr_data;
                endcase
            end

        end
    end


    // Cycle count logic
    localparam CYCLES_PER_TICK = 1000 / CLK_PERIOD;     // 1 us / CLK_PERIOD (ns)
    assign tick = (counter == CYCLES_PER_TICK-1);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0;
        end
        else begin
            counter <= (tick) ? 0 : counter+1;
        end
    end


endmodule
