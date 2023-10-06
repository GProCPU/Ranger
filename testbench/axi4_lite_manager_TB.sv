`timescale 1ns/1ps

`include "rv32.sv"
`include "ranger.sv"
`include "axi4_lite.sv"
import ranger::*;


module axi4_lite_manager_TB;

    localparam MAX_CYCLES = 128;
    integer clk_count = 0;
    integer fail = 0;
    integer fid;
    logic mutex;

    // DUT Parameters
    parameter WIDTH         = 32;                       // data width
    parameter ADDR_WIDTH    = 32;                       // address bus width
    parameter TIMEOUT       = DEFAULT_AXI_TIMEOUT;      // bus timeout in cycles

    // DUT Ports
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

    axi4_lite #(.WIDTH(WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) axi();


    assign rst_n = ~rst;

    // Instantiate DUT
    axi4_lite_manager #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .TIMEOUT(TIMEOUT)
    ) DUT (
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
        .axi_m(axi.manager)
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

        axi.awready   <= 0;
        axi.wready    <= 0;
        axi.bvalid    <= 0;
        axi.bresp     <= axi.OKAY;
        axi.arready   <= 0;
        axi.rvalid    <= 0;
        axi.rdata     <= 0;
        axi.rresp     <= axi.OKAY;

        // Reset
        rst <= 1;
        #200;
        rst <= 0;

        fid = $fopen("axi4_lite_manager.log");
        $dumpfile("axi4_lite_manager.vcd");
        $dumpvars(2, axi4_lite_manager_TB);
    end


    // Stimulus
    logic [2:0] state;
    logic awdone, wdone;    // track write address/data channel status
    initial begin
        #200;
        while (1) begin
            state = $random();
            if (mutex) begin
                $write("    FAILED! Unterminated operation\n");
                $fwrite(fid,"    FAILED! Unterminated operation\n");
                fail = fail + 1;
            end
            mutex = 1;
            case (state)

            // Slow Read
            0: begin
                $write("Slow Read Operation:  clk=%03d\n",clk_count);
                $fwrite(fid,"Slow Read Operation:  clk=%03d\n",clk_count);
                rd_en <= 1;
                addr  <= $random();
                // read address channel
                #100; // go slow
                while (!axi.arvalid) #100;
                axi.arready <= 1;
                #100; // read address transaction
                if (axi.araddr != addr) begin
                    $write("    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", addr, axi.araddr);
                    $fwrite(fid,"    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", addr, axi.araddr);
                    fail = fail + 1;
                end
                axi.arready <= 0;
                if (!busy) begin
                    $write("    FAILED! Busy signal not asserted\n");
                    $fwrite(fid,"    FAILED! Busy signal not asserted\n");
                    fail = fail + 1;
                end
                // read response channel
                axi.rdata <= $random();
                #200; // go slow
                axi.rvalid <= 1;
                axi.rresp <= axi.OKAY;
                while (!axi.rready) #100;
                #100; // read data transaction
                if (rd_data != axi.rdata) begin
                    $write("    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi.rdata, rd_data);
                    $fwrite(fid,"    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi.rdata, rd_data);
                    fail = fail + 1;
                end
                if (access_fault) begin
                    $write("    FAILED! Access fault asserted on good transmission\n");
                    $fwrite(fid,"    FAILED! Access fault asserted on good transmission\n");
                    fail = fail + 1;
                end
                axi.rvalid <= 0;
                rd_en <= 0;
                if (busy) begin
                    $write("    FAILED! Busy signal asserted after operation complete\n");
                    $fwrite(fid,"    FAILED! Busy signal asserted after operation complete\n");
                    fail = fail + 1;
                end
            end

            // Slow Write
            1: begin
                $write("Slow Write Operation:  clk=%03d\n",clk_count);
                $fwrite(fid,"Slow Write Operation:  clk=%03d\n",clk_count);
                wr_en <= 1;
                addr  <= $random();
                wr_data <= $random();
                // write address channel
                #100; // go slow
                while (!axi.awvalid) #100;
                axi.awready <= 1;
                #100; // write address transaction
                if (axi.awaddr != addr) begin
                    $write("    FAILED! Incorrect write address. Expected 0x%h, got 0x%h\n", addr, axi.awaddr);
                    $fwrite(fid,"    FAILED! Incorrect write address. Expected 0x%h, got 0x%h\n", addr, axi.awaddr);
                    fail = fail + 1;
                end
                axi.awready <= 0;
                if (!busy) begin
                    $write("    FAILED! Busy signal not asserted\n");
                    $fwrite(fid,"    FAILED! Busy signal not asserted\n");
                    fail = fail + 1;
                end
                // write data channel
                #100; // go slow
                while (!axi.wvalid) #100;
                axi.wready <= 1;
                #100; // write data transaction
                if (axi.wdata != wr_data) begin
                    $write("    FAILED! Incorrect write data. Expected 0x%h, got 0x%h\n", wr_data, axi.wdata);
                    $fwrite(fid,"    FAILED! Incorrect write data. Expected 0x%h, got 0x%h\n", wr_data, axi.wdata);
                    fail = fail + 1;
                end
                axi.wready <= 0;
                // write response channel
                #200; // go slow
                axi.bresp  <= axi.OKAY;
                axi.bvalid <= 1;
                while (!axi.bready) #100;
                #100; // write response transaction
                if (access_fault) begin
                    $write("    FAILED! Access fault asserted on good transmission\n");
                    $fwrite(fid,"    FAILED! Access fault asserted on good transmission\n");
                    fail = fail + 1;
                end
                axi.bvalid <= 0;
                wr_en <= 0;
                if (busy) begin
                    $write("    FAILED! Busy signal asserted after operation complete\n");
                    $fwrite(fid,"    FAILED! Busy signal asserted after operation complete\n");
                    fail = fail + 1;
                end
            end

            // Fast Read
            2: begin
                $write("Fast Read Operation:  clk=%03d\n",clk_count);
                $fwrite(fid,"Fast Read Operation:  clk=%03d\n",clk_count);
                rd_en <= 1;
                addr  <= $random();
                axi.arready <= 1;
                // read address channel
                while (!axi.arvalid) #100; // read address transaction
                if (axi.araddr != addr) begin
                    $write("    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", addr, axi.araddr);
                    $fwrite(fid,"    FAILED! Incorrect read address. Expected 0x%h, got 0x%h\n", addr, axi.araddr);
                    fail = fail + 1;
                end
                axi.arready <= 0;
                if (!busy) begin
                    $write("    FAILED! Busy signal not asserted\n");
                    $fwrite(fid,"    FAILED! Busy signal not asserted\n");
                    fail = fail + 1;
                end
                // read response channel
                axi.rdata <= $random();
                axi.rvalid <= 1;
                axi.rresp <= axi.OKAY;
                while (!axi.rready) #100; // read data transaction
                if (rd_data != axi.rdata) begin
                    $write("    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi.rdata, rd_data);
                    $fwrite(fid,"    FAILED! Incorrect read data. Expected 0x%h, got 0x%h\n", axi.rdata, rd_data);
                    fail = fail + 1;
                end
                if (access_fault) begin
                    $write("    FAILED! Access fault asserted on good transmission\n");
                    $fwrite(fid,"    FAILED! Access fault asserted on good transmission\n");
                    fail = fail + 1;
                end
                axi.rvalid <= 0;
                rd_en <= 0;
                if (busy) begin
                    $write("    FAILED! Busy signal asserted after operation complete\n");
                    $fwrite(fid,"    FAILED! Busy signal asserted after operation complete\n");
                    fail = fail + 1;
                end
            end

            // Fast Write
            3: begin
                $write("Fast Write Operation:  clk=%03d\n",clk_count);
                $fwrite(fid,"Fast Write Operation:  clk=%03d\n",clk_count);
                wr_en <= 1;
                addr  <= $random();
                wr_data <= $random();
                // write address/data channels
                axi.awready <= 1;
                axi.wready  <= 1;
                awdone = 0;
                wdone  = 0;
                while (!awdone || !wdone) begin
                    #100;
                    if (axi.awvalid) begin
                        awdone = 1;
                        axi.awready <= 0;
                    end
                    if (axi.wvalid) begin
                        wdone = 1;
                        axi.wready <= 0;
                    end
                end
                // write response channel
                axi.bresp  <= axi.OKAY;
                axi.bvalid <= 1;
                #100;
                while (!axi.bready) #100; // write response transaction
                if (access_fault) begin
                    $write("    FAILED! Access fault asserted on good transmission\n");
                    $fwrite(fid,"    FAILED! Access fault asserted on good transmission\n");
                    fail = fail + 1;
                end
                axi.bvalid <= 0;
                wr_en <= 0;
                if (busy) begin
                    $write("    FAILED! Busy signal asserted after operation complete\n");
                    $fwrite(fid,"    FAILED! Busy signal asserted after operation complete\n");
                    fail = fail + 1;
                end
            end

            // Wait
            4: begin
                $write("No Operation:  clk=%03d\n",clk_count);
                $fwrite(fid,"No Operation:  clk=%03d",clk_count);
                #100;
            end

            default: ;// nothing, get next random

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