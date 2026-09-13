`timescale 1ns/1ps
// APB slave for CNN accelerator.
//
// Address map (byte addresses, paddr[19:0]):
//   paddr[19:18]=00  Input  SRAM   word_addr = paddr[15:2]  (max 12287)
//   paddr[19:18]=01  Weight SRAM   word_addr = paddr[9:2]   (max 255)
//   paddr[19:18]=10  Output SRAM   word_addr = paddr[16:2]  (max 32767, read-only)
//   0xC0000          Control reg   [0]=start
//   0xC0004          Status  reg   [0]=done  [1]=busy
//
// pready is tied high (zero-wait-state).
// Read timing: addr driven in SETUP; rdata valid in ACCESS (1-cycle SRAM latency).

module apb_slave (
    input  wire        pclk,
    input  wire        presetn,
    // APB
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [19:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,
    // Input SRAM port
    output reg         apb_in_we,
    output reg  [13:0] apb_in_addr,
    output reg  [31:0] apb_in_wdata,
    // Weight SRAM port
    output reg         apb_wt_we,
    output reg  [7:0]  apb_wt_addr,
    output reg  [31:0] apb_wt_wdata,
    // Output SRAM port (read-only from APB)
    output reg  [14:0] apb_out_addr,
    input  wire [31:0] apb_out_rdata,
    // Control / status
    output reg         ctrl_start,
    input  wire        stat_done,
    input  wire        stat_busy
);
    assign pready  = 1'b1;
    assign pslverr = 1'b0;

    wire sel_in  = (paddr[19:18] == 2'b00);
    wire sel_wt  = (paddr[19:18] == 2'b01);
    wire sel_out = (paddr[19:18] == 2'b10);
    wire sel_csr = (paddr[19:18] == 2'b11);
    wire sel_ctrl = sel_csr && (paddr[3:0] == 4'h0);
    wire sel_stat = sel_csr && (paddr[3:0] == 4'h4);

    // Combinational: drive SRAM addresses (in SETUP for read pipelining)
    // and write data / write-enable (in ACCESS only)
    always @(*) begin
        apb_in_we    = 1'b0;
        apb_in_addr  = 14'd0;
        apb_in_wdata = 32'd0;
        apb_wt_we    = 1'b0;
        apb_wt_addr  =  8'd0;
        apb_wt_wdata = 32'd0;
        apb_out_addr = 15'd0;
        ctrl_start   = 1'b0;

        if (psel) begin
            if (pwrite && penable) begin
                if (sel_in) begin
                    apb_in_we    = 1'b1;
                    apb_in_addr  = paddr[15:2];
                    apb_in_wdata = pwdata;
                end else if (sel_wt) begin
                    apb_wt_we    = 1'b1;
                    apb_wt_addr  = paddr[9:2];
                    apb_wt_wdata = pwdata;
                end else if (sel_ctrl) begin
                    ctrl_start = pwdata[0];
                end
            end else if (!pwrite) begin
                if (sel_in)
                    apb_in_addr  = paddr[15:2];
                else if (sel_wt)
                    apb_wt_addr  = paddr[9:2];
                else if (sel_out)
                    apb_out_addr = paddr[16:2];
            end
        end
    end

    always @(*) begin
        prdata = 32'd0;
        if (psel && penable && !pwrite) begin
            if      (sel_in  || sel_wt) prdata = 32'd0;  // not used (write-only from host side)
            else if (sel_out)           prdata = apb_out_rdata;
            else if (sel_stat)          prdata = {30'd0, stat_busy, stat_done};
        end
    end

endmodule
