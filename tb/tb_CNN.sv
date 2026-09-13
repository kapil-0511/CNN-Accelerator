// Testbench: 3-channel 64x64 CNN accelerator with 8 filters (3x3 kernel).
// Loads input and weights via APB, fires convolution, reads output via APB,
// compares against software golden reference.

`timescale 1ns/1ps

module tb_CNN;

    logic pclk = 0;
    always #5 pclk = ~pclk;

    logic presetn;
    initial begin presetn = 0; #27; @(posedge pclk); presetn = 1; end

    logic        psel, penable, pwrite;
    logic [19:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pready, pslverr;

    CNN_top dut (
        .pclk    (pclk),
        .presetn (presetn),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

    // APB tasks
    task automatic apb_write(input logic [19:0] addr, input logic [31:0] data);
        @(posedge pclk); #1;
        psel=1; penable=0; pwrite=1; paddr=addr; pwdata=data;
        @(posedge pclk); #1;
        penable=1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        #1; psel=0; penable=0; pwrite=0;
    endtask

    task automatic apb_read(input logic [19:0] addr, output logic [31:0] data);
        @(posedge pclk); #1;
        psel=1; penable=0; pwrite=0; paddr=addr;
        @(posedge pclk); #1;
        penable=1;
        @(posedge pclk);
        while (!pready) @(posedge pclk);
        #1; data=prdata;
        psel=0; penable=0;
    endtask

    // Test data
    // Input:   signed 8-bit,  input_map[ch][row][col]
    // Weights: signed 8-bit,  weight[f][ch][kh][kw]
    logic signed [7:0]  input_map [0:2][0:63][0:63];
    logic signed [7:0]  weight    [0:7][0:2][0:2][0:2];
    logic signed [31:0] ref_out   [0:7][0:63][0:63];

    // Software golden reference
    task compute_reference();
        logic signed [63:0] acc;
        int ir, ic;
        for (int f=0; f<8; f++)
            for (int r=0; r<64; r++)
                for (int c=0; c<64; c++) begin
                    acc = 0;
                    for (int ch=0; ch<3; ch++)
                        for (int kh=0; kh<3; kh++)
                            for (int kw=0; kw<3; kw++) begin
                                ir = r + kh - 1;
                                ic = c + kw - 1;
                                if (ir>=0 && ir<64 && ic>=0 && ic<64)
                                    acc += $signed(input_map[ch][ir][ic]) *
                                           $signed(weight[f][ch][kh][kw]);
                            end
                    ref_out[f][r][c] = acc[31:0];
                end
    endtask

    // Load input SRAM: input[ch][r][c] → paddr[19:18]=00, word_addr=ch*4096+r*64+c
    task load_input();
        logic [19:0] addr;
        for (int ch=0; ch<3; ch++)
            for (int r=0; r<64; r++)
                for (int c=0; c<64; c++) begin
                    addr = 20'h00000 + (ch*4096 + r*64 + c)*4;
                    apb_write(addr, {24'h0, input_map[ch][r][c]});
                end
    endtask

    // Load weight SRAM: weight[f][ch][kh][kw] → paddr[19:18]=01, word_addr=f*32+ch*9+kh*3+kw
    task load_weights();
        logic [19:0] addr;
        int k;
        for (int f=0; f<8; f++)
            for (int ch=0; ch<3; ch++)
                for (int kh=0; kh<3; kh++)
                    for (int kw=0; kw<3; kw++) begin
                        k    = ch*9 + kh*3 + kw;
                        addr = 20'h40000 + (f*32 + k)*4;
                        apb_write(addr, {24'h0, weight[f][ch][kh][kw]});
                    end
    endtask

    // Read output and compare
    task read_and_check(output int pass_cnt, output int fail_cnt);
        logic [31:0] rd_val;
        logic [19:0] addr;
        pass_cnt = 0; fail_cnt = 0;
        for (int f=0; f<8; f++)
            for (int r=0; r<64; r++)
                for (int c=0; c<64; c++) begin
                    addr = 20'h80000 + (f*4096 + r*64 + c)*4;
                    apb_read(addr, rd_val);
                    if ($signed(rd_val) === ref_out[f][r][c])
                        pass_cnt++;
                    else begin
                        $display("  FAIL out[%0d][%0d][%0d] got=%0d exp=%0d",
                                 f, r, c, $signed(rd_val), ref_out[f][r][c]);
                        fail_cnt++;
                    end
                end
    endtask

    // Print first 6 rows x 6 cols of one input channel
    task print_fmap_slice(input string name, input int ch,
                          input logic signed [7:0] fmap[0:63][0:63]);
        $display("\n  %s [ch=%0d] (6x6):", name, ch);
        $write("        ");
        for (int c=0; c<6; c++) $write("  c%0d  ", c);
        $write("\n");
        for (int r=0; r<6; r++) begin
            $write("  r%0d:  ", r);
            for (int c=0; c<6; c++) $write(" %4d ", fmap[r][c]);
            $write("\n");
        end
    endtask

    // Print all 3 channels of one filter's weights (3 x 3x3 grids)
    task print_filter(input int flt);
        $display("\n  Filter %0d weights (ch0 / ch1 / ch2, each 3x3):", flt);
        for (int ch=0; ch<3; ch++) begin
            $display("    ch%0d:", ch);
            for (int kh=0; kh<3; kh++) begin
                $write("      ");
                for (int kw=0; kw<3; kw++) $write(" %4d", weight[flt][ch][kh][kw]);
                $write("\n");
            end
        end
    endtask

    // Print first 6 rows x 6 cols of one filter's reference output
    task print_out_slice(input string name, input int flt);
        $display("\n  %s [filter=%0d] (6x6):", name, flt);
        $write("        ");
        for (int c=0; c<6; c++) $write("  c%-2d  ", c);
        $write("\n");
        for (int r=0; r<6; r++) begin
            $write("  r%0d:  ", r);
            for (int c=0; c<6; c++) $write(" %6d", ref_out[flt][r][c]);
            $write("\n");
        end
    endtask

    localparam NUM_TESTS = 10;

    int total_pass, total_fail;

    initial begin
        psel=0; penable=0; pwrite=0; paddr=0; pwdata=0;
        total_pass=0; total_fail=0;

        @(posedge presetn);
        repeat(5) @(posedge pclk);

        $display("\n============================================================");
        $display("  CNN Accelerator: 3x64x64 input, 8 filters (3x3x3 kernel)");
        $display("  Running %0d randomised test cases", NUM_TESTS);
        $display("============================================================");

        for (int test=0; test<NUM_TESTS; test++) begin
            $display("\n--- Test %0d/%0d  (t=%0t) ---", test+1, NUM_TESTS, $time);

            // Generate fresh random signed inputs (-128..127) and weights each test
            for (int ch=0; ch<3; ch++)
                for (int r=0; r<64; r++)
                    for (int c=0; c<64; c++)
                        input_map[ch][r][c] = $signed(8'($urandom_range(0, 255)));

            for (int f=0; f<8; f++)
                for (int ch=0; ch<3; ch++)
                    for (int kh=0; kh<3; kh++)
                        for (int kw=0; kw<3; kw++)
                            weight[f][ch][kh][kw] = $signed(8'($urandom_range(0, 255)));

            // Compute software golden reference
            compute_reference();

            // Print 6x6 input (all 3 channels), full filter 0, 6x6 reference output
            for (int ch=0; ch<3; ch++)
                print_fmap_slice("Input", ch, input_map[ch]);
            print_filter(0);
            print_out_slice("Reference output", 0);

            // Load input and weights via APB
            $display("  Loading input and weights...");
            load_input();
            load_weights();

            // Kick off hardware
            $display("  t=%0t  Start!", $time);
            apb_write(20'hC0000, 32'h1);

            // Poll status[done]
            begin
                logic [31:0] status;
                status = 0;
                while (!status[0]) begin
                    repeat(20) @(posedge pclk);
                    apb_read(20'hC0004, status);
                end
            end
            $display("  t=%0t  Done!", $time);

            // Read output SRAM and compare against reference
            begin
                int p, f;
                read_and_check(p, f);
                total_pass += p;
                total_fail += f;
                $display("  Test %0d result: %0d PASS  |  %0d FAIL",
                         test+1, p, f);
            end
        end

        $display("\n============================================================");
        $display("  GRAND TOTAL (%0d tests x 32768): %0d PASS  |  %0d FAIL",
                 NUM_TESTS, total_pass, total_fail);
        $display("============================================================\n");
        $finish;
    end

    initial begin
        #5_000_000_000ns;
        $display("TIMEOUT at %0t ns", $time);
        $finish;
    end

    initial begin
        $dumpfile("tb_CNN.vcd");
        $dumpvars(0, tb_CNN);
    end

endmodule
