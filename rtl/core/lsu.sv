`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module lsu #(
        
    ) (
        // clock not needed; module is purely combinatorial
        // reset not needed; module is combinatorial and stateless

        input lsu_op_t lsu_op,                                  // LSU operation select
        input rv32::word alu_result,                            // output from alu (data or mem addr)
        input rv32::word alt_data,                              // data source for store and CSR read instructions
        input logic endianness,                                 // data memory endiannes select (0=little,1=big)

        // Register File write port
        output logic dest_en,                                   // register file write enable
        input  rv32::gpr_addr_t dest_addr,                      // destination register
        output rv32::word dest_data,                            // register file write data

        // DBus interface
        input  rv32::word dbus_rd_data,                         // data from memory
        output logic dbus_rd_en,                                // DBus read enable
        output logic dbus_wr_en,                                // DBus write enable
        output rv32::word dbus_addr,                            // memory read address (byte-addressable)
        output rv32::word dbus_wr_data,                         // memory write data
        output logic [(rv32::XLEN/8)-1:0] dbus_wr_strobe,       // write strobes, indicate which byte lanes hold valid data
        input  logic dbus_wait,                                 // asserted if DBus requires additional cycle(s) to complete transaction
        input  logic dbus_err,                                  // if asserted, operation is aborted

        // CSR write port
        output logic csr_wr_en,                                 // CSR write enable
        output rv32::word csr_wr_data                           // CSR write data

    );

    assign dbus_addr    = alu_result;
    assign dbus_wr_data = (endianness) ? convert_endian(alt_data) : alt_data;
    assign csr_wr_data  = alu_result;

    rv32::word dbus_rd_data_endian;
    logic [15:0] dbus_rd_data_endian16;
    assign dbus_rd_data_endian = (endianness) ? convert_endian(dbus_rd_data) : dbus_rd_data;
    assign dbus_rd_data_endian16 = (endianness) ? convert_endian16(dbus_rd_data) : dbus_rd_data;


    always_comb begin
        case (lsu_op)
            LSU_LB: begin
                dest_en    = 1;
                dest_data  = { {24{dbus_rd_data[7]}}, dbus_rd_data[7:0] };
                dbus_rd_en = 1;
                dbus_wr_en = 0;
                dbus_wr_strobe = 4'h0;
                csr_wr_en  = 0;
            end
            LSU_LH: begin
                dest_en    = 1;
                dest_data  = { {16{dbus_rd_data_endian16[15]}}, dbus_rd_data_endian16 };
                dbus_rd_en = 1;
                dbus_wr_en = 0;
                dbus_wr_strobe = 4'h0;
                csr_wr_en  = 0;
            end
            LSU_LW: begin
                dest_en    = 1;
                dest_data  = dbus_rd_data_endian;
                dbus_rd_en = 1;
                dbus_wr_en = 0;
                dbus_wr_strobe = 4'h0;
                csr_wr_en  = 0;
            end
            LSU_LBU: begin
                dest_en    = 1;
                dest_data  = { {24{1'b0}}, dbus_rd_data[7:0] };
                dbus_rd_en = 1;
                dbus_wr_en = 0;
                dbus_wr_strobe = 4'h0;
                csr_wr_en  = 0;
            end
            LSU_LHU: begin
                dest_en    = 1;
                dest_data  = { {16{1'b0}}, dbus_rd_data_endian16 };
                dbus_rd_en = 1;
                dbus_wr_en = 0;
                dbus_wr_strobe = 4'h0;
                csr_wr_en  = 0;
            end
            LSU_SB: begin
                dest_en    = 0;
                dest_data  = 0;
                dbus_rd_en = 0;
                dbus_wr_en = 1;
                dbus_wr_strobe = 4'h1;
                csr_wr_en  = 0;
            end
            LSU_SH: begin
                dest_en    = 0;
                dest_data  = 0;
                dbus_rd_en = 0;
                dbus_wr_en = 1;
                dbus_wr_strobe = 4'h3;
                csr_wr_en  = 0;
            end
            LSU_SW: begin
                dest_en    = 0;
                dest_data  = 0;
                dbus_rd_en = 0;
                dbus_wr_en = 1;
                dbus_wr_strobe = 4'hF;
                csr_wr_en  = 0;
            end
            LSU_CSRR: begin
                dest_en    = 1;
                dest_data  = alt_data;
                dbus_rd_en = 0;
                dbus_wr_en = 0;
                dbus_wr_strobe = 0;
                csr_wr_en  = 0;
            end
            LSU_CSRRW: begin
                dest_en    = 1;
                dest_data  = alt_data;
                dbus_rd_en = 0;
                dbus_wr_en = 0;
                dbus_wr_strobe = 0;
                csr_wr_en  = 1;
            end
            LSU_REG: begin
                dest_en    = 1;
                dest_data  = alu_result;
                dbus_rd_en = 0;
                dbus_wr_en = 0;
                dbus_wr_strobe = 0;
                csr_wr_en  = 0;
            end
            LSU_NOP: begin
                dest_en    = 0;
                dest_data  = 0;
                dbus_rd_en = 0;
                dbus_wr_en = 0;
                dbus_wr_strobe = 0;
                csr_wr_en  = 0;
            end
            default: begin
                dest_en    = 0;
                dest_data  = 0;
                dbus_rd_en = 0;
                dbus_wr_en = 0;
                dbus_wr_strobe = 0;
                csr_wr_en  = 0;
            end
        endcase
        if (dbus_wait | dbus_err) begin
            // override register file write enable
            dest_en     = 0;
        end
    end


    // `ifdef FORMAL
    // always_comb begin
    //     // Check exceptions
    //     if (data_misaligned || data_access_fault) begin
    //         // Do nothing if exception occurs
    //         assert(!dest_en);
    //         assert(!dbus_rd_en);
    //         assert(!dbus_wr_en);
    //         assert(!csr_wr_en);
    //         case (lsu_op)
    //             LSU_LB: assert(load_store_n);
    //             LSU_LH: assert(load_store_n);
    //             LSU_LW: assert(load_store_n);
    //             LSU_LBU: assert(load_store_n);
    //             LSU_LWU: assert(load_store_n);
    //             LSU_SB: assert(~load_store_n);
    //             LSU_SH: assert(~load_store_n);
    //             LSU_SW: assert(~load_store_n);
    //         endcase
    //     end
    //     else begin
    //         // Check enable signals
    //         assert(dest_en == (
    //                (lsu_op == LSU_LB)
    //             || (lsu_op == LSU_LH)
    //             || (lsu_op = LSU_LW)
    //             || (lsu_op = LSU_LBU)
    //             || (lsu_op = LSU_LHU)
    //             || (lsu_op = LSU_CSRR)
    //             || (lsu_op = LSU_CSRRW)
    //             || (lsu_op = LSU_REG)
    //         ));
    //         assert(dbus_rd_en == (
    //                (lsu_op == LSU_LB)
    //             || (lsu_op == LSU_SH)
    //             || (lsu_op == LSU_LW)
    //             || (lsu_op == LSU_LBU)
    //             || (lsu_op == LSU_LHU)
    //         ));
    //         assert(dbus_wr_en == (
    //                (lsu_op == LSU_SB)
    //             || (lsu_op == LSU_SH)
    //             || (lsu_op == LSU_SW)
    //         ));
    //         assert(csr_wr_en == (
    //                (lsu_op == LSU_CSRR)
    //             || (lsu_op == LSU_CSRRW)
    //         ));
    //         // Check dest_data
    //         case (lsu_op)
    //             LSU_LB: assert(dest_data == { {24{dbus_rd_data[7]}}, dbus_rd_data[7:0] });
    //             LSU_LH: (endianness) ?
    //                     assert(dest_data == { {16{dbus_rd_data[7]}}, dbus_rd_data[7:0], dbus_rd_data[15:8] }) :
    //                     assert(dest_data == { {16{dbus_rd_data[15]}}, dbus_rd_data[15:0] });
    //             LSU_LW: (endianness) ?
    //                     assert(dest_data == { dbus_rd_data[7:0], dbus_rd_data[15:8], dbus_rd_data[23:16], dbus_rd_data[31:24] }) :
    //                     assert(dest_data == dbus_rd_data);
    //             LSU_LBU: assert(dest_data == { {24{1'b0}}, dbus_rd_data[7:0] });
    //             LSU_LHU: (endianness) ?
    //                     assert(dest_data == { {16{1'b0}}, dbus_rd_data[7:0], dbus_rd_data[15:8] }) :
    //                     assert(dest_data == { {16{1'b0}}, dbus_rd_data[15:0] });
    //             LSU_CSRR, LSU_CSRRW: assert(dest_data == alt_data);
    //             LSU_REG: assert(dest_data == alu_result);
    //         endcase
    //         // Check dbus_addr
    //         case (lsu_op)
    //             LSU_LB, LSU_LH, LSU_LW, LSU_LBU, LSU_LHU, LSU_SB, LSU_SH, LSU_SW: assert(dbus_addr == alu_result);
    //         endcase
    //         // Check dbus_wr_data
    //         case (lsu_op)
    //             LSU_SB: assert(dbus_wr_data == { {24{alt_data[7]}}, alt_data[7:0] });
    //             LSU_SH: (endianness) ?
    //                     assert(dbus_wr_data == { {16{alt_data[7]}}, alt_data[7:0], alt_data[15:8] }) :
    //                     assert(dbus_wr_data == { {16{alt_data[15]}}, alt_data[15:0] });
    //             LSU_SW: (endianness) ?
    //                     assert(dbus_wr_data == { alt_data[7:0], alt_data[15:8], alt_data[23:16], alt_data[31:24] });
    //                     assert(dbus_wr_data == alt_data);
    //         endcase
    //         // Check dbus_wr_strobe
    //         case (lsu_op)
    //             LSU_SB: assert(dbus_wr_strobe == 4'b0001);
    //             LSU_SH: assert(dbus_wr_strobe == 4'b0011);
    //             LSU_SW: assert(dbus_wr_strobe == 4'b1111);
    //         endcase
    //         // Check csr_wr_data
    //         case (lsu_op)
    //             LSU_CSRRW: assert(csr_wr_data == alu_result);
    //         endcase
    //     end // if/else (data_misaligned || data_access_fault)
    // end // always_comb
    // `endif // FORMAL

endmodule