//depend mem/rom.sv
//depend mem/ram.sv
//cmd cd ${PROJ_DIR}/sw/projects/core_test && make build dump
//cmd cp ${PROJ_DIR}/sw/projects/core_test/rom.hex .
`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
import ranger::*;


module core_TB;

    localparam MAX_CYCLES = 2048;
    integer clk_count = 0;
    integer fail = 0;
    integer fid;

    localparam DONE_CODE     = 'h0D15EA5E; // zero disease
    localparam FAIL_CODE        = 'hDEADBEEF;

    // DUT Parameters
    parameter ROM_ADDR_WIDTH    = DEFAULT_ROM_ADDR_WIDTH;       // ROM address width (word-addressable, default 4kB)
    parameter RAM_ADDR_WIDTH    = DEFAULT_RAM_ADDR_WIDTH;       // RAM address width (word-addressable, default 4kB)
    parameter AXI_ADDR_WIDTH    = DEFAULT_AXI_ADDR_WIDTH;       // AXI bus address space width (byte-addressable)
    parameter ROM_BASE_ADDR     = DEFAULT_ROM_BASE_ADDR;        // ROM base address (must be aligned to ROM size)
    parameter RAM_BASE_ADDR     = DEFAULT_RAM_BASE_ADDR;        // RAM base address (must be aligned to RAM size)
    parameter MTIME_BASE_ADDR   = DEFAULT_MTIME_BASE_ADDR;      // machine timer base address (see [CSR](./CSR.md))
    parameter AXI_BASE_ADDR     = DEFAULT_AXI_BASE_ADDR;        // AXI bus address space base (must be aligned to AXI address space)
    parameter HART_ID           = 0;                            // hardware thread id (see mhartid CSR)
    parameter RESET_ADDR        = DEFAULT_RESET_ADDR;           // program counter reset/boot address
    parameter USE_CSR           = 1;                            // enable generation of the CSR module
    parameter USE_TRAP          = 1;                            // enable generation of the Trap Unit (requires CSR)
    parameter USE_MTIME         = 0;                            // enable generation of machine timer address space
    parameter USE_AXI           = 0;                            // enable generation of AXI address space

    // DUT Ports
    logic clk;                                          // global system clock
    logic rst, rst_n;                                   // global reset, active-low
    // ROM ports
    logic rom_rd_en1;                                   // IBus
    logic [ROM_ADDR_WIDTH-1:0] rom_addr1;               // IBus
    rv32::word rom_rd_data1;                            // IBus
    logic rom_rd_en2;                                   // DBus
    logic [ROM_ADDR_WIDTH-1:0] rom_addr2;               // DBus
    rv32::word rom_rd_data2;                            // DBus
    // RAM ports
    logic ram_rd_en;                                    // DBus
    logic ram_wr_en;                                    // DBus
    logic [RAM_ADDR_WIDTH-1:0] ram_addr;                // DBus
    rv32::word ram_rd_data;                             // DBus
    // AXI ports
    logic axi_rd_en;                                    // DBus
    logic axi_wr_en;                                    // DBus
    logic [AXI_ADDR_WIDTH-1:0] axi_addr;                // DBus
    rv32::word axi_rd_data;                             // DBus
    logic axi_access_fault;                             // DBus
    logic axi_busy;                                     // DBus
    rv32::word wr_data;                                 // shared write data
    logic [(rv32::XLEN/8)-1:0] wr_strobe;               // shared write strobe
    // Interrupt flags
    logic gpioa_int_0;                                  // GPIOA interrupt 0
    logic gpioa_int_1;                                  // GPIOA interrupt 1
    logic gpiob_int_0;                                  // GPIOA interrupt 0
    logic gpiob_int_1;                                  // GPIOA interrupt 1
    logic gpioc_int_0;                                  // GPIOA interrupt 0
    logic gpioc_int_1;                                  // GPIOA interrupt 1
    logic uart0_rx_int;                                 // UART0 RX interrupt
    logic uart0_tx_int;                                 // UART0 TX interrupt
    logic timer0_int;                                   // timer0 interrupt
    logic timer1_int;                                   // timer1 interrupt


    assign rst_n = ~rst;




    // Instantiate DUT
    core #(
        .ROM_ADDR_WIDTH(ROM_ADDR_WIDTH),
        .RAM_ADDR_WIDTH(RAM_ADDR_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
        .ROM_BASE_ADDR(ROM_BASE_ADDR),
        .RAM_BASE_ADDR(RAM_BASE_ADDR),
        .MTIME_BASE_ADDR(MTIME_BASE_ADDR),
        .AXI_BASE_ADDR(AXI_BASE_ADDR),
        .HART_ID(HART_ID),
        .RESET_ADDR(RESET_ADDR),
        .USE_CSR(USE_CSR),
        .USE_TRAP(USE_TRAP),
        .USE_MTIME(USE_MTIME),
        .USE_AXI(USE_AXI)
    ) DUT (
        .clk,
        .rst_n,
        .rom_rd_en1,
        .rom_addr1,
        .rom_rd_data1,
        .rom_rd_en2,
        .rom_addr2,
        .rom_rd_data2,
        .ram_rd_en,
        .ram_wr_en,
        .ram_addr,
        .ram_rd_data,
        .axi_rd_en,
        .axi_wr_en,
        .axi_addr,
        .axi_rd_data,
        .axi_access_fault,
        .axi_busy,
        .wr_data,
        .wr_strobe,
        .gpioa_int_0,
        .gpioa_int_1,
        .gpiob_int_0,
        .gpiob_int_1,
        .gpioc_int_0,
        .gpioc_int_1,
        .uart0_rx_int,
        .uart0_tx_int,
        .timer0_int,
        .timer1_int
    );

    // Instantiate ROM
    rom #(
        .ADDR_WIDTH(ROM_ADDR_WIDTH)
    ) ROM0 (
        .rd_en1(rom_rd_en1),
        .addr1(rom_addr1),
        .rd_data1(rom_rd_data1),
        .rd_en2(rom_rd_en2),
        .addr2(rom_addr2),
        .rd_data2(rom_rd_data2)
    );

    // Instantiate RAM
    ram #(
        .ADDR_WIDTH(RAM_ADDR_WIDTH),
        .DUMP_MEM(1)
    ) RAM0 (
        .clk,
        .rd_en(ram_rd_en),
        .wr_en(ram_wr_en),
        .addr(ram_addr),
        .wr_data,
        .wr_strobe,
        .rd_data(ram_rd_data)
    );




    // 10 MHz clock
    initial clk = 0;
    initial forever #50 clk = ~clk;

    // Initialize
    initial begin
        // AXI (unused)
        axi_rd_data = 0;
        axi_access_fault = 0;
        axi_busy = 0;
        // interrupts (unused)
        gpioa_int_0 = 0;
        gpioa_int_1 = 0;
        gpiob_int_0 = 0;
        gpiob_int_1 = 0;
        gpioc_int_0 = 0;
        gpioc_int_1 = 0;
        uart0_rx_int = 0;
        uart0_tx_int = 0;
        timer0_int = 0;
        timer1_int = 0;

        // Reset
        rst = 1;
        #200;
        rst = 0;

        fid = $fopen("core.log");
        $dumpfile("core.vcd");
        $dumpvars(3, core_TB);
    end


    // Verification
    always @(posedge clk) begin
        if (rst) begin

        end
        else begin
            if (DUT.Decoder_inst.opcode == DUT.Decoder_inst.MISC_MEM
            && DUT.Decoder_inst.funct3 == DUT.Decoder_inst.FUNCT3_FENCE) begin
                // FENCE instruction triggers simulation check function
                case (DUT.gen_csr.CSR_inst.mscratch)
                    0: begin // confirm x10 == x11
                        $write("clk_count=%5d    ", clk_count);
                        $fwrite(fid,"clk_count=%5d    ", clk_count);
                        if (DUT.RegFile_inst.data[10] == DUT.RegFile_inst.data[11]) begin
                            $write("check passed, called from 0x%h\n", DUT.RegFile_inst.data[1]-4);
                            $fwrite(fid,"check passed, called from 0x%h\n", DUT.RegFile_inst.data[1]-4);
                        end
                        else begin
                            fail <= fail + 1;
                            $write("check FAILED, called from 0x%h", DUT.RegFile_inst.data[1]-4);
                            $write("    0x%h != 0x%h\n", DUT.RegFile_inst.data[10], DUT.RegFile_inst.data[11]);
                            $fwrite(fid,"check FAILED, called from 0x%h", DUT.RegFile_inst.data[1]-4);
                            $fwrite(fid,"    0x%h != 0x%h\n", DUT.RegFile_inst.data[10], DUT.RegFile_inst.data[11]);
                        end
                    end
                    1: begin // check all failed
                        fail <= fail + 1;
                        $write("clk_count=%5d    ", clk_count);
                        $write("check_all FAILED, called from 0x%h", DUT.RegFile_inst.data[1]-4);
                        $write("    register 0x%2d incorrect\n", DUT.RegFile_inst.data[10]);
                        $fwrite(fid,"clk_count=%5d    ", clk_count);
                        $fwrite(fid,"check_all FAILED, called from 0x%h", DUT.RegFile_inst.data[1]-4);
                        $fwrite(fid,"    register 0x%2d incorrect\n", DUT.RegFile_inst.data[10]);
                    end
                    DONE_CODE: begin
                        $write("Reached done state");
                        $fwrite(fid,"Reached done state");
                        clk_count <= MAX_CYCLES + 1;
                    end
                    FAIL_CODE: begin
                        fail <= fail + 1;
                        $write("\n\nReached FAILED state\n");
                        $fwrite(fid,"\n\nReached FAILED state\n");
                        $fclose(fid);
                        $finish();
                    end
                    default: begin
                        $write("clk_count=%5d    ", clk_count);
                        $write("error, unknown ebreak call, mscratch = 0x%h\n", DUT.gen_csr.CSR_inst.mscratch);
                        $fwrite(fid,"clk_count=%5d    ", clk_count);
                        $fwrite(fid,"error, unknown ebreak call, mscratch = 0x%h\n", DUT.gen_csr.CSR_inst.mscratch);
                    end
                endcase
            end
        end
    end


    // End Simulation
    always @(posedge clk) begin
        clk_count <= clk_count + 1;
        if (clk_count >= MAX_CYCLES) begin
            if (fail) begin
                $write("\n\nFAILED %3d tests\n", fail);
                $fwrite(fid,"\n\nFailed %3d tests\n", fail);
            end
            else if (DUT.gen_csr.CSR_inst.mscratch != DONE_CODE) begin
                $write("\n\nFAILED, never reached done state\n");
                $fwrite(fid,"\n\nFAILED, never reached done state\n");
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