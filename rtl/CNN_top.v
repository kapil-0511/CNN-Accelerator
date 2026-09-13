`timescale 1ns/1ps
// Top-level: 3-channel 64x64 CNN convolution accelerator.
// Input SRAM  : 16384 x 32-bit  (holds 3x64x64 = 12288 elements in lower 8 bits)
// Weight SRAM : 256   x 32-bit  (holds 8x32=256 weight entries in lower 8 bits)
// Output SRAM : 32768 x 32-bit  (holds 8x64x64 = 32768 signed 32-bit results)
// Arbiter: CNN_controller owns all SRAMs when busy; APB slave owns them when idle.

module CNN_top (
    input  wire        pclk,
    input  wire        presetn,
    // APB
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [19:0] paddr,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr
);
    // APB slave outputs
    wire        apb_in_we;
    wire [13:0] apb_in_addr;
    wire [31:0] apb_in_wdata;
    wire        apb_wt_we;
    wire [7:0]  apb_wt_addr;
    wire [31:0] apb_wt_wdata;
    wire [14:0] apb_out_addr;
    wire [31:0] apb_out_rdata;
    wire        ctrl_start, stat_done, stat_busy;

    // Conv controller SRAM outputs
    wire [13:0] cc_in_addr;
    wire [7:0]  cc_wt_addr;
    wire        cc_out_we;
    wire [14:0] cc_out_addr;
    wire [31:0] cc_out_wdata;

    // SRAM shared data
    wire [31:0] in_rdata, wt_rdata, out_rdata;

    // Arbitration: conv_controller owns SRAMs when busy
    wire        in_sram_we    = stat_busy ? 1'b0         : apb_in_we;
    wire [13:0] in_sram_addr  = stat_busy ? cc_in_addr   : apb_in_addr;
    wire [31:0] in_sram_wdata = apb_in_wdata;

    wire        wt_sram_we    = stat_busy ? 1'b0         : apb_wt_we;
    wire [7:0]  wt_sram_addr  = stat_busy ? cc_wt_addr   : apb_wt_addr;
    wire [31:0] wt_sram_wdata = apb_wt_wdata;

    wire        out_sram_we   = cc_out_we;
    wire [14:0] out_sram_addr = stat_busy ? cc_out_addr  : apb_out_addr;

    // Input SRAM: 16384 x 32-bit (12288 used: ch*4096 + row*64 + col)
    sram #(.DEPTH(16384), .AW(14), .DW(32)) u_in_sram (
        .clk   (pclk),
        .we    (in_sram_we),
        .addr  (in_sram_addr),
        .wdata (in_sram_wdata),
        .rdata (in_rdata)
    );

    // Weight SRAM: 256 x 32-bit (216 used: f*32 + k, k=ch*9+kh*3+kw, k<27)
    sram #(.DEPTH(256), .AW(8), .DW(32)) u_wt_sram (
        .clk   (pclk),
        .we    (wt_sram_we),
        .addr  (wt_sram_addr),
        .wdata (wt_sram_wdata),
        .rdata (wt_rdata)
    );

    // Output SRAM: 32768 x 32-bit (f*4096 + row*64 + col)
    sram #(.DEPTH(32768), .AW(15), .DW(32)) u_out_sram (
        .clk   (pclk),
        .we    (out_sram_we),
        .addr  (out_sram_addr),
        .wdata (cc_out_wdata),
        .rdata (out_rdata)
    );

    assign apb_out_rdata = out_rdata;

    apb_slave u_apb (
        .pclk          (pclk),
        .presetn       (presetn),
        .psel          (psel),
        .penable       (penable),
        .pwrite        (pwrite),
        .paddr         (paddr),
        .pwdata        (pwdata),
        .prdata        (prdata),
        .pready        (pready),
        .pslverr       (pslverr),
        .apb_in_we     (apb_in_we),
        .apb_in_addr   (apb_in_addr),
        .apb_in_wdata  (apb_in_wdata),
        .apb_wt_we     (apb_wt_we),
        .apb_wt_addr   (apb_wt_addr),
        .apb_wt_wdata  (apb_wt_wdata),
        .apb_out_addr  (apb_out_addr),
        .apb_out_rdata (apb_out_rdata),
        .ctrl_start    (ctrl_start),
        .stat_done     (stat_done),
        .stat_busy     (stat_busy)
    );

    CNN_controller #(
        .IDW(8), .WDW(8), .ADW(32), .NF(8), .ROWS(64), .COLS(64), .IN_CH(3)
    ) u_cc (
        .clk          (pclk),
        .rst_n        (presetn),
        .start        (ctrl_start),
        .busy         (stat_busy),
        .done         (stat_done),
        .sram_in_addr (cc_in_addr),
        .sram_in_rdata(in_rdata),
        .sram_wt_addr (cc_wt_addr),
        .sram_wt_rdata(wt_rdata),
        .sram_out_we  (cc_out_we),
        .sram_out_addr(cc_out_addr),
        .sram_out_wdata(cc_out_wdata)
    );

endmodule
