`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module trap #(
        parameter RESET_ADDR        = DEFAULT_RESET_ADDR        // program counter reset/boot address
    ) (
        input  logic clk,
        input  logic rst_n,

        // PC related signals
        input  rv32::word pc,
        input  rv32::word decoder_next_pc,
        output rv32::word next_pc,

        // CSR signals
        input  logic csr_rd_en,
        input  logic csr_wr_en,
        input  rv32::csr_addr_t csr_addr,
        output rv32::word csr_rd_data,
        input  rv32::word csr_wr_data,

        // Exception metadata
        input  logic global_mie,
        input  logic load_store_n,
        input  rv32::word data_addr,
        input  rv32::word inst,

        // Exceptions
        input  logic inst_access_fault,
        input  logic inst_misaligned,
        input  logic illegal_inst,
        input  logic illegal_csr,
        input  logic data_misaligned,
        input  logic data_access_fault,
        input  logic ecall,
        input  logic ebreak,

        // Interrupts
        input  logic mtime_int,
        input  logic uart0_rx_int,
        input  logic uart0_tx_int,
        input  logic timer0_int,
        input  logic timer1_int,
        input  logic gpioa_int_0,
        input  logic gpioa_int_1,
        input  logic gpiob_int_0,
        input  logic gpiob_int_1,
        input  logic gpioc_int_0,
        input  logic gpioc_int_1,

        // Trap return
        input  logic mret,

        // Instruction incomplete flag(s)
        input  logic dbus_wait,

        // Global Exception and Trap Flags
        output logic exception,
        output logic trap
    );

    // CSRs
    rv32::word mtvec;
    interrupt_csr_t mip;
    interrupt_csr_t mie;
    rv32::word mepc;
    rv32::word mcause;
    rv32::word mtval;

    // CSR fields
    logic [1:0] mtvec_mode;
    assign mtvec_mode = mtvec[1:0];
    rv32::word mtvec_base_direct;
    assign mtvec_base_direct = {mtvec[31:2], 2'b0};
    rv32::word mtvec_base_vectored;
    assign mtvec_base_vectored = {mtvec[31:7], 7'b0};

    // MIP standard interrupt causes read-only
    // assign mip.reserved15_12 = 0;
    // assign mip.MEI = 0;
    // assign mip.reserved10 = 0;
    // assign mip.SEI = 0;
    // assign mip.reserved8 = 0;
    // assign mip.MTI = mtime_int;
    // assign mip.reserved6 = 0;
    // assign mip.STI = 0;
    // assign mip.reserved4 = 0;
    // assign mip.MSI = 0;
    // assign mip.reserved2 = 0;
    // assign mip.SSI = 0;
    // assign mip.reserved0 = 0;
    // mepc read-only
    assign mepc[1:0] = 0;

    // Private signals
    logic _reset;           // reset register; high the first cycle after reset, else low
    rv32::word _mcause;     // combinatorial mcause; valid only when trap is asserted


    ////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////
    // BEGIN: Combinatorial Logic
    ////////////////////////////////////////////////////////////
    always_comb begin
        if (!rst_n) begin
            csr_rd_data = 0;
            next_pc     = RESET_ADDR;
            exception   = 0;
            trap        = 0;
            _mcause     = -1;
        end
        else begin
            _mcause     = -1;

            // Set exception, trap, & _mcause
            if (inst_access_fault) begin
                exception   = 1;
                trap        = 1;
                _mcause     = rv32::TRAP_CODE_INST_ACCESS_FAULT;
            end
            else if (inst_misaligned) begin
                exception   = 1;
                trap        = 1;
                _mcause     = rv32::TRAP_CODE_INST_MISALIGNED;
            end
            else if (illegal_inst || illegal_csr) begin
                exception   = 1;
                trap        = 1;
                _mcause     = rv32::TRAP_CODE_ILLEGAL_INST;
            end
            else if (ecall) begin
                exception   = 1;
                trap        = 1;
                _mcause     = rv32::TRAP_CODE_ENV_CALL_MMODE;
            end
            else if (ebreak) begin
                exception   = 1;
                trap        = 1;
                _mcause     = rv32::TRAP_CODE_BREAKPOINT;
            end
            else if (data_misaligned) begin
                exception   = 1;
                trap        = 1;
                _mcause     = (load_store_n) ? rv32::TRAP_CODE_LOAD_MISALIGNED
                                             : rv32::TRAP_CODE_STORE_MISALIGNED;
            end
            else if (data_access_fault) begin
                exception   = 1;
                trap        = 1;
                _mcause     = (load_store_n) ? rv32::TRAP_CODE_LOAD_ACCESS_FAULT
                                             : rv32::TRAP_CODE_STORE_ACCESS_FAULT;
            end
            else begin // interrupts
                exception   = 0;
                trap        = 0;    // overwritten if interrupt trap occurs
                _mcause     = 0;    // overwritten if interrupt trap occurs
                if (global_mie) begin
                    for (integer i=0; i<rv32::XLEN; i=i+1) begin
                        if (mip[i] && mie[i]) begin
                            trap    = 1;
                            _mcause = i;
                            break; // exit loop
                        end
                    end
                end
            end // interrupts


            // Set next_pc
            if (_reset) begin
                next_pc = RESET_ADDR;
            end
            else if (dbus_wait) begin
                next_pc = pc;
            end
            else begin
                if (trap) begin
                    if (mtvec_mode == 2'b01) begin
                        // vectored mode
                        if (exception || _mcause >= 32) begin
                            next_pc = mtvec_base_vectored;
                        end
                        else begin
                            next_pc = mtvec_base_vectored + (_mcause << 2);
                        end
                    end
                    else begin
                        // direct mode
                        next_pc = mtvec_base_direct;
                    end
                end // if (trap)
                else if (mret) begin
                    next_pc = mepc;
                end
                else begin
                    next_pc = decoder_next_pc;
                end
            end

            // CSR read (set csr_rd_data)
            // All CSR privilege checks are performed by the CSR module
            if (csr_rd_en) begin
                case (csr_addr)
                    rv32::csr_addr_mtvec: begin
                        csr_rd_data = mtvec;
                    end
                    rv32::csr_addr_mip: begin
                        csr_rd_data = mip;
                    end
                    rv32::csr_addr_mie: begin
                        csr_rd_data = mie;
                    end
                    rv32::csr_addr_mepc: begin
                        csr_rd_data = mepc;
                    end
                    rv32::csr_addr_mcause: begin
                        csr_rd_data = mcause;
                    end
                    rv32::csr_addr_mtval: begin
                        csr_rd_data = mtval;
                    end
                    default: begin
                        csr_rd_data = 0;
                    end
                endcase
            end // if (csr_rd_en)
            else begin
                csr_rd_data = 0;
            end

        end
    end
    ////////////////////////////////////////////////////////////
    // END: Combinatorial Logic
    ////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////


    ////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////
    // BEGIN: Clocked Logic
    ////////////////////////////////////////////////////////////
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            _reset      <= 1;
            mtvec       <= 0;
            mip[31:16]  <= 0;
            mie         <= 0;
            mepc[31:2]  <= 0;
            mcause      <= 0;
            mtval       <= 0;
        end
        else begin
            _reset <= 0;

            // CSR write
            if (csr_wr_en) begin
                case (csr_addr)
                    rv32::csr_addr_mtvec: begin
                        mtvec <= csr_wr_data;
                    end
                    rv32::csr_addr_mip: begin
                        mip[31:16] <= csr_wr_data[31:16];
                    end
                    rv32::csr_addr_mie: begin
                        mie <= csr_wr_data;
                    end
                    rv32::csr_addr_mepc: begin
                        mepc[31:2] <= csr_wr_data[31:2];
                    end
                    rv32::csr_addr_mcause: begin
                        mcause <= csr_wr_data;
                    end
                    rv32::csr_addr_mtval: begin
                        mtval <= csr_wr_data;
                    end
                endcase
            end // if (csr_wr_en)


            // mepc, mcause, and mtval logic; overwrite CSR write instructions
            if (trap) begin
                mepc[31:2]  <= (exception) ? pc[31:2] : decoder_next_pc[31:2];
                mcause      <= {~exception, _mcause[30:0]};
                if (inst_access_fault) begin
                    mtval <= pc;
                end
                else if (inst_misaligned) begin
                    mtval <= decoder_next_pc;
                end
                else if (illegal_inst || illegal_csr) begin
                    mtval <= inst;
                end
                else if (ebreak) begin
                    mtval <= pc;
                end
                else if (data_misaligned || data_access_fault) begin
                    mtval <= data_addr;
                end
                else begin
                    mtval <= 0;
                end
            end


            // Interrupt pending detect; overwrites CSR write instructions
            if (uart0_rx_int) begin
                mip[TRAP_CODE_UART0RX] <= 1;
            end
            if (uart0_tx_int) begin
                mip[TRAP_CODE_UART0TX] <= 1;
            end
            if (timer0_int) begin
                mip[TRAP_CODE_TIM0] <= 1;
            end
            if (timer1_int) begin
                mip[TRAP_CODE_TIM1] <= 1;
            end
            if (gpioa_int_0) begin
                mip[TRAP_CODE_GPIOA0] <= 1;
            end
            if (gpioa_int_1) begin
                mip[TRAP_CODE_GPIOA1] <= 1;
            end
            if (gpiob_int_0) begin
                mip[TRAP_CODE_GPIOB0] <= 1;
            end
            if (gpiob_int_1) begin
                mip[TRAP_CODE_GPIOB1] <= 1;
            end
            if (gpioc_int_0) begin
                mip[TRAP_CODE_GPIOC0] <= 1;
            end
            if (gpioc_int_1) begin
                mip[TRAP_CODE_GPIOC1] <= 1;
            end

        end
    end
    ////////////////////////////////////////////////////////////
    // END: Clocked Logic
    ////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////

endmodule
