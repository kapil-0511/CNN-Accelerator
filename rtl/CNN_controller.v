`timescale 1ns/1ps
// Sliding-window convolution controller.
// Computes output[NF][ROWS][COLS] = conv(input[IN_CH][ROWS][COLS], weights[NF][IN_CH][3][3])
// with same-padding (zero-pad border).
//
// FSM loads row r+1 before computing output row r so the line buffer always
// holds rows r-1, r, r+1. Slot 3 is a virtual zero-pad sentinel.
//
// SRAM address layout:
//   Input  : {ch[1:0], row[5:0], col[5:0]}  = 14-bit
//   Weight : {f[2:0],  k[4:0]}              =  8-bit  (k = ch*9 + kh*3 + kw, k<27)
//   Output : {f[2:0],  row[5:0], col[5:0]}  = 15-bit

module CNN_controller #(
    parameter IDW   = 8,
    parameter WDW   = 8,
    parameter ADW   = 32,
    parameter NF    = 8,
    parameter ROWS  = 64,
    parameter COLS  = 64,
    parameter IN_CH = 3
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    output reg         busy,
    output reg         done,
    // Input SRAM
    output reg  [13:0] sram_in_addr,
    input  wire [31:0] sram_in_rdata,
    // Weight SRAM
    output reg  [7:0]  sram_wt_addr,
    input  wire [31:0] sram_wt_rdata,
    // Output SRAM
    output reg         sram_out_we,
    output reg  [14:0] sram_out_addr,
    output reg  [31:0] sram_out_wdata
);
    localparam ST_IDLE        = 4'd0;
    localparam ST_LD_WT_ADDR  = 4'd1;
    localparam ST_LD_WT_DATA  = 4'd2;
    localparam ST_LD_ROW_ADDR = 4'd3;
    localparam ST_LD_ROW_DATA = 4'd4;
    localparam ST_COMPUTE     = 4'd5;
    localparam ST_WRITE_OUT   = 4'd6;
    localparam ST_NEXT_COL    = 4'd7;
    localparam ST_NEXT_ROW    = 4'd8;
    localparam ST_DONE        = 4'd9;

    reg [3:0] state;
    reg [2:0] f_cnt;
    reg [4:0] k_cnt;
    reg [5:0] row_cnt;       // input load row counter
    reg [5:0] out_row_cnt;   // output row being computed / written
    reg [5:0] col_cnt;
    reg [1:0] ch_cnt;
    reg [2:0] flt_cnt;
    reg [1:0] slot_ptr;      // slot being written to during LD_ROW phase
    reg [1:0] slot_curr;     // slot_r1: slot holding out_row_cnt (= out_row_cnt % 3)
    reg       first_done;    // 1 after row 0 has been pre-loaded
    reg       compute_last;  // 1 during the final compute pass (row 63)

    // Slot select wires for the line buffer
    // slot 3 = virtual zero-pad (line_buffer returns 0)
    wire [1:0] slot_r0 = (out_row_cnt == 6'd0) ? 2'd3 :
                         (slot_curr == 2'd0)    ? 2'd2 : slot_curr - 2'd1;
    wire [1:0] slot_r1 = slot_curr;
    wire [1:0] slot_r2 = compute_last ? 2'd3 : slot_ptr;

    // Weight registers: 8 filters x 32 slots (power-of-2 for index concat)
    reg [256*WDW-1:0] weight_regs;

    wire [NF*27*WDW-1:0] weights_flat;
    assign weights_flat[0*27*WDW +: 27*WDW] = weight_regs[0*32*WDW +: 27*WDW];
    assign weights_flat[1*27*WDW +: 27*WDW] = weight_regs[1*32*WDW +: 27*WDW];
    assign weights_flat[2*27*WDW +: 27*WDW] = weight_regs[2*32*WDW +: 27*WDW];
    assign weights_flat[3*27*WDW +: 27*WDW] = weight_regs[3*32*WDW +: 27*WDW];
    assign weights_flat[4*27*WDW +: 27*WDW] = weight_regs[4*32*WDW +: 27*WDW];
    assign weights_flat[5*27*WDW +: 27*WDW] = weight_regs[5*32*WDW +: 27*WDW];
    assign weights_flat[6*27*WDW +: 27*WDW] = weight_regs[6*32*WDW +: 27*WDW];
    assign weights_flat[7*27*WDW +: 27*WDW] = weight_regs[7*32*WDW +: 27*WDW];

    // Line buffer control
    reg           lb_we;
    reg [1:0]     lb_slot_wr;
    reg [5:0]     lb_col_wr;
    reg [1:0]     lb_ch_wr;
    reg [IDW-1:0] lb_data;
    reg [5:0]     lb_rd_col;

    wire [27*IDW-1:0] window_flat;

    line_buffer #(.IDW(IDW), .COLS(COLS)) u_lb (
        .clk         (clk),
        .rst_n       (rst_n),
        .write_en    (lb_we),
        .slot_wr     (lb_slot_wr),
        .wr_col      (lb_col_wr),
        .wr_ch       (lb_ch_wr),
        .wr_data     (lb_data),
        .slot_r0     (slot_r0),
        .slot_r1     (slot_r1),
        .slot_r2     (slot_r2),
        .rd_col      (lb_rd_col),
        .window_flat (window_flat)
    );

    wire [NF*ADW-1:0] results_flat;

    filter_bank #(.IDW(IDW), .WDW(WDW), .ADW(ADW), .NF(NF)) u_fb (
        .window_flat  (window_flat),
        .weights_flat (weights_flat),
        .results_flat (results_flat)
    );

    reg [ADW-1:0] result_regs [0:NF-1];

    // ── Combinational output drives ──────────────────────────────────────────
    always @(*) begin
        sram_in_addr   = 14'd0;
        sram_wt_addr   =  8'd0;
        sram_out_we    =  1'b0;
        sram_out_addr  = 15'd0;
        sram_out_wdata = 32'd0;
        lb_we          =  1'b0;
        lb_slot_wr     =  2'd0;
        lb_col_wr      =  6'd0;
        lb_ch_wr       =  2'd0;
        lb_data        = {IDW{1'b0}};
        lb_rd_col      = col_cnt;

        case (state)
            ST_LD_WT_ADDR: begin
                sram_wt_addr = {f_cnt, k_cnt};
            end

            ST_LD_ROW_ADDR: begin
                sram_in_addr = {ch_cnt, row_cnt, col_cnt};
            end

            ST_LD_ROW_DATA: begin
                lb_we      = 1'b1;
                lb_slot_wr = slot_ptr;
                lb_col_wr  = col_cnt;
                lb_ch_wr   = ch_cnt;
                lb_data    = sram_in_rdata[IDW-1:0];
            end

            ST_COMPUTE: begin
                lb_rd_col = col_cnt;
            end

            ST_WRITE_OUT: begin
                sram_out_we    = 1'b1;
                sram_out_addr  = {flt_cnt, out_row_cnt, col_cnt};
                sram_out_wdata = result_regs[flt_cnt];
            end

            default: ;
        endcase
    end

    // ── Sequential FSM ───────────────────────────────────────────────────────
    integer n;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= ST_IDLE;
            busy         <= 1'b0;
            done         <= 1'b0;
            f_cnt        <= 3'd0;
            k_cnt        <= 5'd0;
            row_cnt      <= 6'd0;
            out_row_cnt  <= 6'd0;
            col_cnt      <= 6'd0;
            ch_cnt       <= 2'd0;
            flt_cnt      <= 3'd0;
            slot_ptr     <= 2'd0;
            slot_curr    <= 2'd0;
            first_done   <= 1'b0;
            compute_last <= 1'b0;
            weight_regs  <= {(256*WDW){1'b0}};
            for (n = 0; n < NF; n = n+1)
                result_regs[n] <= {ADW{1'b0}};
        end else begin
            case (state)

                ST_IDLE: begin
                    if (start) begin
                        busy         <= 1'b1;
                        done         <= 1'b0;
                        f_cnt        <= 3'd0;
                        k_cnt        <= 5'd0;
                        row_cnt      <= 6'd0;
                        out_row_cnt  <= 6'd0;
                        col_cnt      <= 6'd0;
                        ch_cnt       <= 2'd0;
                        flt_cnt      <= 3'd0;
                        slot_ptr     <= 2'd0;
                        slot_curr    <= 2'd0;
                        first_done   <= 1'b0;
                        compute_last <= 1'b0;
                        state        <= ST_LD_WT_ADDR;
                    end
                end

                // ── Weight loading ───────────────────────────────────────────
                ST_LD_WT_ADDR: begin
                    state <= ST_LD_WT_DATA;
                end

                ST_LD_WT_DATA: begin
                    weight_regs[{f_cnt, k_cnt} * WDW +: WDW] <= sram_wt_rdata[WDW-1:0];
                    if (k_cnt < 5'd26) begin
                        k_cnt <= k_cnt + 5'd1;
                        state <= ST_LD_WT_ADDR;
                    end else begin
                        k_cnt <= 5'd0;
                        if (f_cnt < NF-1) begin
                            f_cnt <= f_cnt + 3'd1;
                            state <= ST_LD_WT_ADDR;
                        end else begin
                            f_cnt   <= 3'd0;
                            row_cnt <= 6'd0;
                            col_cnt <= 6'd0;
                            ch_cnt  <= 2'd0;
                            state   <= ST_LD_ROW_ADDR;
                        end
                    end
                end

                // ── Row loading ──────────────────────────────────────────────
                ST_LD_ROW_ADDR: begin
                    state <= ST_LD_ROW_DATA;
                end

                ST_LD_ROW_DATA: begin
                    if (ch_cnt < IN_CH-1) begin
                        ch_cnt <= ch_cnt + 2'd1;
                        state  <= ST_LD_ROW_ADDR;
                    end else begin
                        ch_cnt <= 2'd0;
                        if (col_cnt < COLS-1) begin
                            col_cnt <= col_cnt + 6'd1;
                            state   <= ST_LD_ROW_ADDR;
                        end else begin
                            // Row fully loaded
                            col_cnt <= 6'd0;
                            if (!first_done) begin
                                // Pre-load row 1 before first compute
                                first_done <= 1'b1;
                                slot_ptr   <= 2'd1;
                                row_cnt    <= 6'd1;
                                ch_cnt     <= 2'd0;
                                state      <= ST_LD_ROW_ADDR;
                            end else begin
                                out_row_cnt <= row_cnt - 6'd1;
                                state       <= ST_COMPUTE;
                            end
                        end
                    end
                end

                // ── Compute one output column ────────────────────────────────
                ST_COMPUTE: begin
                    result_regs[0] <= results_flat[0*ADW +: ADW];
                    result_regs[1] <= results_flat[1*ADW +: ADW];
                    result_regs[2] <= results_flat[2*ADW +: ADW];
                    result_regs[3] <= results_flat[3*ADW +: ADW];
                    result_regs[4] <= results_flat[4*ADW +: ADW];
                    result_regs[5] <= results_flat[5*ADW +: ADW];
                    result_regs[6] <= results_flat[6*ADW +: ADW];
                    result_regs[7] <= results_flat[7*ADW +: ADW];
                    flt_cnt <= 3'd0;
                    state   <= ST_WRITE_OUT;
                end

                // ── Write 8 filter results for current column ────────────────
                ST_WRITE_OUT: begin
                    if (flt_cnt < NF-1) begin
                        flt_cnt <= flt_cnt + 3'd1;
                    end else begin
                        flt_cnt <= 3'd0;
                        state   <= ST_NEXT_COL;
                    end
                end

                // ── Advance to next column or end of row ─────────────────────
                ST_NEXT_COL: begin
                    if (col_cnt < COLS-1) begin
                        col_cnt <= col_cnt + 6'd1;
                        state   <= ST_COMPUTE;
                    end else begin
                        col_cnt <= 6'd0;
                        state   <= ST_NEXT_ROW;
                    end
                end

                // ── End of output row: advance or finish ─────────────────────
                ST_NEXT_ROW: begin
                    // Advance output-row tracking
                    out_row_cnt <= out_row_cnt + 6'd1;
                    slot_curr   <= (slot_curr == 2'd2) ? 2'd0 : slot_curr + 2'd1;

                    if (compute_last) begin
                        state <= ST_DONE;
                    end else if (row_cnt < ROWS-1) begin
                        slot_ptr <= (slot_ptr == 2'd2) ? 2'd0 : slot_ptr + 2'd1;
                        row_cnt  <= row_cnt + 6'd1;
                        col_cnt  <= 6'd0;
                        ch_cnt   <= 2'd0;
                        state    <= ST_LD_ROW_ADDR;
                    end else begin
                        // No more input rows; compute last output row with slot_r2=zero-pad
                        compute_last <= 1'b1;
                        col_cnt      <= 6'd0;
                        ch_cnt       <= 2'd0;
                        state        <= ST_COMPUTE;
                    end
                end

                ST_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
