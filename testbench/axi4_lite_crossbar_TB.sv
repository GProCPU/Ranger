//depend axi4_lite_manager.sv
`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
`include "axi4_lite.sv"
import ranger::*;


module axi4_lite_crossbar_TB;

    localparam MAX_CYCLES = 128;
    integer clk_count = 0;
    integer fail = 0;
    integer fid;
    logic mutex;

    // Manager Parameters
    parameter ADDR_WIDTH    = 6;                            // address bus width
    parameter TIMEOUT       = DEFAULT_AXI_TIMEOUT;          // bus timeout in cycles

    // DUT Parameters
    parameter WIDTH         = 32;                           // data bus width
    parameter COUNT         = 2;                            // number of downstream subordinates
    parameter integer S_ADDR_WIDTH[COUNT] = {4, 4};         // array of subordinate address width
    parameter integer S_BASE_ADDR[COUNT]  = {'h00, 'h10};   // array of subordinate base addresses

    // Manager Ports
    // inputs
    reg clk;
    reg rst, rst_n;
    reg rd_en;
    reg wr_en;
    reg [ADDR_WIDTH-1:0] addr;
    rv32::word wr_data;
    reg [(rv32::XLEN/8)-1:0] wr_strobe;
    // outputs
    rv32::word rd_data;
    wire access_fault;
    wire busy;

    wire [S_ADDR_WIDTH[0]-1:0] s_addr;
    assign s_addr = addr[S_ADDR_WIDTH[0]-1:0];

    // Crossbar Ports
    axi4_lite #(.WIDTH(WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) axi_m();
    axi4_lite #(.WIDTH(WIDTH), .ADDR_WIDTH(S_ADDR_WIDTH[0])) axi_s0();
    axi4_lite #(.WIDTH(WIDTH), .ADDR_WIDTH(S_ADDR_WIDTH[1])) axi_s1();
    // axi4_lite #(
    //     .WIDTH(WIDTH),
    //     .ADDR_WIDTH(4S_ADDR_WIDTH[0])
    // ) axi_sx[COUNT]();


    assign rst_n = ~rst;

    // Instantiate Manager
    axi4_lite_manager #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .TIMEOUT(TIMEOUT)
    ) axi_manager (
        .clk,
        .rst_n,
        .rd_en,
        .wr_en,
        .addr,
        .wr_data,
        .wr_strobe,
        .rd_data,
        .access_fault,
        .busy,
        .axi_m(axi_m)
    );

    // Instantiate DUT
    axi4_lite_crossbar #(
        .WIDTH(WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .COUNT(COUNT),
        .S_ADDR_WIDTH(S_ADDR_WIDTH),
        .S_BASE_ADDR(S_BASE_ADDR)
    ) DUT (
        .axi_m,
        .axi_sx({axi_s0, axi_s1})
        //.axi_sx
    );


    // 10 MHz clock
    initial clk = 1;
    initial forever #50 clk = ~clk;

    // Initialize
    initial begin
        rd_en   <= 0;
        wr_en   <= 0;
        addr    <= 0;
        wr_data <= 0;
        wr_strobe <= -1;

        axi_s0.awready   <= 0;
        axi_s0.wready    <= 0;
        axi_s0.bvalid    <= 0;
        axi_s0.bresp     <= axi_s0.OKAY;
        axi_s0.arready   <= 0;
        axi_s0.rvalid    <= 0;
        axi_s0.rdata     <= 0;
        axi_s0.rresp     <= axi_s0.OKAY;

        axi_s1.awready   <= 0;
        axi_s1.wready    <= 0;
        axi_s1.bvalid    <= 0;
        axi_s1.bresp     <= axi_s1.OKAY;
        axi_s1.arready   <= 0;
        axi_s1.rvalid    <= 0;
        axi_s1.rdata     <= 0;
        axi_s1.rresp     <= axi_s1.OKAY;

        // Reset
        rst <= 1;
        #200;
        rst <= 0;

        fid = $fopen("axi4_lite_crossbar.log");
        $dumpfile("axi4_lite_crossbar.vcd");
        $dumpvars(2, axi4_lite_crossbar_TB);
    end


    // Stimulus
    logic [1:0] op;
    logic awdone, wdone;    // track write address/data channel status
    initial begin
        #200; // wait for reset
        while (1) begin
            op = $random();
            if (mutex) begin
                $write("    FAILED! Unterminated operation\n");
                $fwrite(fid,"    FAILED! Unterminated operation\n");
                fail = fail + 1;
            end
            mutex = 1;
            case (op)

            // Slow Read Subordinate 0
            0: begin
                $write("Slow Read Subordinate 0:  clk=%03d\n",clk_count);
                $fwrite(fid,"Slow Read Subordinate 0:  clk=%03d\n",clk_count);
                rd_en <= 1;
                addr  <= $random();
                addr[ADDR_WIDTH-1:S_ADDR_WIDTH] <= 0; // override to select subordinate 0
                // read address channel
                #100; // go slow
                while (!axi_s0.arvalid) #100;
                axi_s0.arready <= 1;
                if (axi_s1.arvalid) begin
                    $write("    FAILED! Subordinate 1 arvalid asserted\n");
                    $fwrite(fid,"    FAILED! Subordinate 1 arvalid asserted\n");
                end
                #100; // read address transaction
                if (axi_s0.araddr != s_addr) begin
                    $write("    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", s_addr, axi_s0.araddr);
                    $fwrite(fid,"    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", s_addr, axi_s0.araddr);
                    fail = fail + 1;
                end
                axi_s0.arready <= 0;
                if (!busy) begin
                    $write("    FAILED! Busy signal not asserted\n");
                    $fwrite(fid,"    FAILED! Busy signal not asserted\n");
                    fail = fail + 1;
                end
                // read response channel
                axi_s0.rdata <= $random();
                #200; // go slow
                axi_s0.rvalid <= 1;
                axi_s0.rresp <= axi_s0.OKAY;
                while (!axi_s0.rready) #100;
                if (axi_s1.rready) begin
                    $write("    FAILED! Subordinate 1 rready asserted\n");
                    $fwrite(fid,"    FAILED! Subordinate 1 rready asserted\n");
                end
                #100; // read data transaction
                if (rd_data != axi_s0.rdata) begin
                    $write("    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi_s0.rdata, rd_data);
                    $fwrite(fid,"    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi_s0.rdata, rd_data);
                    fail = fail + 1;
                end
                if (access_fault) begin
                    $write("    FAILED! Access fault asserted on good transmission\n");
                    $fwrite(fid,"    FAILED! Access fault asserted on good transmission\n");
                    fail = fail + 1;
                end
                axi_s0.rvalid <= 0;
                rd_en <= 0;
                if (busy) begin
                    $write("    FAILED! Busy signal asserted after operation complete\n");
                    $fwrite(fid,"    FAILED! Busy signal asserted after operation complete\n");
                    fail = fail + 1;
                end
            end

            // Slow Read Subordinate 1
            1: begin
                $write("Slow Read Subordinate 1:  clk=%03d\n",clk_count);
                $fwrite(fid,"Slow Read Subordinate 1:  clk=%03d\n",clk_count);
                rd_en <= 1;
                addr  <= $random();
                addr[ADDR_WIDTH-1:S_ADDR_WIDTH] <= 'b1; // override to select subordinate 1
                // read address channel
                #100; // go slow
                while (!axi_s1.arvalid) #100;
                axi_s1.arready <= 1;
                if (axi_s0.arvalid) begin
                    $write("    FAILED! Subordinate 0 arvalid asserted\n");
                    $fwrite(fid,"    FAILED! Subordinate 0 arvalid asserted\n");
                end
                #100; // read address transaction
                if (axi_s1.araddr != s_addr) begin
                    $write("    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", s_addr, axi_s1.araddr);
                    $fwrite(fid,"    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", s_addr, axi_s1.araddr);
                    fail = fail + 1;
                end
                axi_s1.arready <= 0;
                if (!busy) begin
                    $write("    FAILED! Busy signal not asserted\n");
                    $fwrite(fid,"    FAILED! Busy signal not asserted\n");
                    fail = fail + 1;
                end
                // read response channel
                axi_s1.rdata <= $random();
                #200; // go slow
                axi_s1.rvalid <= 1;
                axi_s1.rresp <= axi_s1.OKAY;
                while (!axi_s1.rready) #100;
                if (axi_s0.rready) begin
                    $write("    FAILED! Subordinate 0 rready asserted\n");
                    $fwrite(fid,"    FAILED! Subordinate 0 rready asserted\n");
                end
                #100; // read data transaction
                if (rd_data != axi_s1.rdata) begin
                    $write("    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi_s1.rdata, rd_data);
                    $fwrite(fid,"    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi_s1.rdata, rd_data);
                    fail = fail + 1;
                end
                if (access_fault) begin
                    $write("    FAILED! Access fault asserted on good transmission\n");
                    $fwrite(fid,"    FAILED! Access fault asserted on good transmission\n");
                    fail = fail + 1;
                end
                axi_s1.rvalid <= 0;
                rd_en <= 0;
                if (busy) begin
                    $write("    FAILED! Busy signal asserted after operation complete\n");
                    $fwrite(fid,"    FAILED! Busy signal asserted after operation complete\n");
                    fail = fail + 1;
                end
            end

           default: #100; // do nothing

            endcase
            mutex = 0;
        end
    end


    // End Simulation
    always @(posedge clk) begin
        clk_count <= clk_count + 1;
        if (clk_count >= MAX_CYCLES) begin
            if (fail) begin
                $write("\n\nFAILED %d tests\n", fail);
                $fwrite(fid,"\n\nFailed %d tests\n", fail);
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