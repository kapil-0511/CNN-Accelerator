`timescale 1ns/1ps
// 3-row circular line buffer for 3-channel input.
// Three flat arrays (one per slot), indexed as col*3+ch.
// slot_rX==3 is a virtual zero-pad sentinel; reads return 0.
//
// window_flat layout: k = ch*9 + kh*3 + kw
//   kh=0→slot_r0, kh=1→slot_r1, kh=2→slot_r2
//   kw=0→col-1 (left zero-pad), kw=1→col, kw=2→col+1 (right zero-pad)

module line_buffer #(
    parameter IDW  = 8,
    parameter COLS = 64
)(
    input  wire           clk,
    input  wire           rst_n,
    input  wire           write_en,
    input  wire [1:0]     slot_wr,
    input  wire [5:0]     wr_col,
    input  wire [1:0]     wr_ch,
    input  wire [IDW-1:0] wr_data,
    input  wire [1:0]     slot_r0,
    input  wire [1:0]     slot_r1,
    input  wire [1:0]     slot_r2,
    input  wire [5:0]     rd_col,
    output wire [27*IDW-1:0] window_flat
);
    // Three flat slot arrays: index = col*3 + ch
    reg [IDW-1:0] lb_s0 [0:COLS*3-1];
    reg [IDW-1:0] lb_s1 [0:COLS*3-1];
    reg [IDW-1:0] lb_s2 [0:COLS*3-1];

    integer ci;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (ci = 0; ci < COLS*3; ci = ci+1) begin
                lb_s0[ci] <= {IDW{1'b0}};
                lb_s1[ci] <= {IDW{1'b0}};
                lb_s2[ci] <= {IDW{1'b0}};
            end
        end else if (write_en) begin
            case (slot_wr)
                2'd0: lb_s0[wr_col*3 + wr_ch] <= wr_data;
                2'd1: lb_s1[wr_col*3 + wr_ch] <= wr_data;
                2'd2: lb_s2[wr_col*3 + wr_ch] <= wr_data;
                default: ;
            endcase
        end
    end

    wire [5:0] col_m1 = rd_col - 6'd1;
    wire [5:0] col_p1 = rd_col + 6'd1;

    // 27 intermediate wires — one per (slot, col-offset, ch) combination.
    // Explicit 4-way mux ensures all three arrays are in the sensitivity list.

    // --- slot_r0, col-1 (kh=0, kw=0) ---
    wire [IDW-1:0] sr0_m1_c0 = (slot_r0==2'd0)?lb_s0[col_m1*3+0]:(slot_r0==2'd1)?lb_s1[col_m1*3+0]:(slot_r0==2'd2)?lb_s2[col_m1*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr0_m1_c1 = (slot_r0==2'd0)?lb_s0[col_m1*3+1]:(slot_r0==2'd1)?lb_s1[col_m1*3+1]:(slot_r0==2'd2)?lb_s2[col_m1*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr0_m1_c2 = (slot_r0==2'd0)?lb_s0[col_m1*3+2]:(slot_r0==2'd1)?lb_s1[col_m1*3+2]:(slot_r0==2'd2)?lb_s2[col_m1*3+2]:{IDW{1'b0}};
    // --- slot_r0, col (kh=0, kw=1) ---
    wire [IDW-1:0] sr0_c0    = (slot_r0==2'd0)?lb_s0[rd_col*3+0]:(slot_r0==2'd1)?lb_s1[rd_col*3+0]:(slot_r0==2'd2)?lb_s2[rd_col*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr0_c1    = (slot_r0==2'd0)?lb_s0[rd_col*3+1]:(slot_r0==2'd1)?lb_s1[rd_col*3+1]:(slot_r0==2'd2)?lb_s2[rd_col*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr0_c2    = (slot_r0==2'd0)?lb_s0[rd_col*3+2]:(slot_r0==2'd1)?lb_s1[rd_col*3+2]:(slot_r0==2'd2)?lb_s2[rd_col*3+2]:{IDW{1'b0}};
    // --- slot_r0, col+1 (kh=0, kw=2) ---
    wire [IDW-1:0] sr0_p1_c0 = (slot_r0==2'd0)?lb_s0[col_p1*3+0]:(slot_r0==2'd1)?lb_s1[col_p1*3+0]:(slot_r0==2'd2)?lb_s2[col_p1*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr0_p1_c1 = (slot_r0==2'd0)?lb_s0[col_p1*3+1]:(slot_r0==2'd1)?lb_s1[col_p1*3+1]:(slot_r0==2'd2)?lb_s2[col_p1*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr0_p1_c2 = (slot_r0==2'd0)?lb_s0[col_p1*3+2]:(slot_r0==2'd1)?lb_s1[col_p1*3+2]:(slot_r0==2'd2)?lb_s2[col_p1*3+2]:{IDW{1'b0}};

    // --- slot_r1, col-1 (kh=1, kw=0) ---
    wire [IDW-1:0] sr1_m1_c0 = (slot_r1==2'd0)?lb_s0[col_m1*3+0]:(slot_r1==2'd1)?lb_s1[col_m1*3+0]:(slot_r1==2'd2)?lb_s2[col_m1*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr1_m1_c1 = (slot_r1==2'd0)?lb_s0[col_m1*3+1]:(slot_r1==2'd1)?lb_s1[col_m1*3+1]:(slot_r1==2'd2)?lb_s2[col_m1*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr1_m1_c2 = (slot_r1==2'd0)?lb_s0[col_m1*3+2]:(slot_r1==2'd1)?lb_s1[col_m1*3+2]:(slot_r1==2'd2)?lb_s2[col_m1*3+2]:{IDW{1'b0}};
    // --- slot_r1, col (kh=1, kw=1) ---
    wire [IDW-1:0] sr1_c0    = (slot_r1==2'd0)?lb_s0[rd_col*3+0]:(slot_r1==2'd1)?lb_s1[rd_col*3+0]:(slot_r1==2'd2)?lb_s2[rd_col*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr1_c1    = (slot_r1==2'd0)?lb_s0[rd_col*3+1]:(slot_r1==2'd1)?lb_s1[rd_col*3+1]:(slot_r1==2'd2)?lb_s2[rd_col*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr1_c2    = (slot_r1==2'd0)?lb_s0[rd_col*3+2]:(slot_r1==2'd1)?lb_s1[rd_col*3+2]:(slot_r1==2'd2)?lb_s2[rd_col*3+2]:{IDW{1'b0}};
    // --- slot_r1, col+1 (kh=1, kw=2) ---
    wire [IDW-1:0] sr1_p1_c0 = (slot_r1==2'd0)?lb_s0[col_p1*3+0]:(slot_r1==2'd1)?lb_s1[col_p1*3+0]:(slot_r1==2'd2)?lb_s2[col_p1*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr1_p1_c1 = (slot_r1==2'd0)?lb_s0[col_p1*3+1]:(slot_r1==2'd1)?lb_s1[col_p1*3+1]:(slot_r1==2'd2)?lb_s2[col_p1*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr1_p1_c2 = (slot_r1==2'd0)?lb_s0[col_p1*3+2]:(slot_r1==2'd1)?lb_s1[col_p1*3+2]:(slot_r1==2'd2)?lb_s2[col_p1*3+2]:{IDW{1'b0}};

    // --- slot_r2, col-1 (kh=2, kw=0) ---
    wire [IDW-1:0] sr2_m1_c0 = (slot_r2==2'd0)?lb_s0[col_m1*3+0]:(slot_r2==2'd1)?lb_s1[col_m1*3+0]:(slot_r2==2'd2)?lb_s2[col_m1*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr2_m1_c1 = (slot_r2==2'd0)?lb_s0[col_m1*3+1]:(slot_r2==2'd1)?lb_s1[col_m1*3+1]:(slot_r2==2'd2)?lb_s2[col_m1*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr2_m1_c2 = (slot_r2==2'd0)?lb_s0[col_m1*3+2]:(slot_r2==2'd1)?lb_s1[col_m1*3+2]:(slot_r2==2'd2)?lb_s2[col_m1*3+2]:{IDW{1'b0}};
    // --- slot_r2, col (kh=2, kw=1) ---
    wire [IDW-1:0] sr2_c0    = (slot_r2==2'd0)?lb_s0[rd_col*3+0]:(slot_r2==2'd1)?lb_s1[rd_col*3+0]:(slot_r2==2'd2)?lb_s2[rd_col*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr2_c1    = (slot_r2==2'd0)?lb_s0[rd_col*3+1]:(slot_r2==2'd1)?lb_s1[rd_col*3+1]:(slot_r2==2'd2)?lb_s2[rd_col*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr2_c2    = (slot_r2==2'd0)?lb_s0[rd_col*3+2]:(slot_r2==2'd1)?lb_s1[rd_col*3+2]:(slot_r2==2'd2)?lb_s2[rd_col*3+2]:{IDW{1'b0}};
    // --- slot_r2, col+1 (kh=2, kw=2) ---
    wire [IDW-1:0] sr2_p1_c0 = (slot_r2==2'd0)?lb_s0[col_p1*3+0]:(slot_r2==2'd1)?lb_s1[col_p1*3+0]:(slot_r2==2'd2)?lb_s2[col_p1*3+0]:{IDW{1'b0}};
    wire [IDW-1:0] sr2_p1_c1 = (slot_r2==2'd0)?lb_s0[col_p1*3+1]:(slot_r2==2'd1)?lb_s1[col_p1*3+1]:(slot_r2==2'd2)?lb_s2[col_p1*3+1]:{IDW{1'b0}};
    wire [IDW-1:0] sr2_p1_c2 = (slot_r2==2'd0)?lb_s0[col_p1*3+2]:(slot_r2==2'd1)?lb_s1[col_p1*3+2]:(slot_r2==2'd2)?lb_s2[col_p1*3+2]:{IDW{1'b0}};

    // window_flat[k*IDW+:IDW] = ch*9 + kh*3 + kw
    // ch=0
    assign window_flat[ 0*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr0_m1_c0; // ch0,kh0,kw0
    assign window_flat[ 1*IDW+:IDW] =                                    sr0_c0;    // ch0,kh0,kw1
    assign window_flat[ 2*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr0_p1_c0; // ch0,kh0,kw2
    assign window_flat[ 3*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr1_m1_c0; // ch0,kh1,kw0
    assign window_flat[ 4*IDW+:IDW] =                                    sr1_c0;    // ch0,kh1,kw1
    assign window_flat[ 5*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr1_p1_c0; // ch0,kh1,kw2
    assign window_flat[ 6*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr2_m1_c0; // ch0,kh2,kw0
    assign window_flat[ 7*IDW+:IDW] =                                    sr2_c0;    // ch0,kh2,kw1
    assign window_flat[ 8*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr2_p1_c0; // ch0,kh2,kw2
    // ch=1
    assign window_flat[ 9*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr0_m1_c1;
    assign window_flat[10*IDW+:IDW] =                                    sr0_c1;
    assign window_flat[11*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr0_p1_c1;
    assign window_flat[12*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr1_m1_c1;
    assign window_flat[13*IDW+:IDW] =                                    sr1_c1;
    assign window_flat[14*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr1_p1_c1;
    assign window_flat[15*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr2_m1_c1;
    assign window_flat[16*IDW+:IDW] =                                    sr2_c1;
    assign window_flat[17*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr2_p1_c1;
    // ch=2
    assign window_flat[18*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr0_m1_c2;
    assign window_flat[19*IDW+:IDW] =                                    sr0_c2;
    assign window_flat[20*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr0_p1_c2;
    assign window_flat[21*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr1_m1_c2;
    assign window_flat[22*IDW+:IDW] =                                    sr1_c2;
    assign window_flat[23*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr1_p1_c2;
    assign window_flat[24*IDW+:IDW] = (rd_col==6'd0)   ? {IDW{1'b0}} : sr2_m1_c2;
    assign window_flat[25*IDW+:IDW] =                                    sr2_c2;
    assign window_flat[26*IDW+:IDW] = (rd_col==COLS-1) ? {IDW{1'b0}} : sr2_p1_c2;

endmodule
