`timescale 1ns/1ps
// Combinational 27-input signed MAC for one 3x3x3 convolution filter.
// window_flat: 27 x IDW-bit input values  (layout: ch*9 + kh*3 + kw)
// weight_flat: 27 x WDW-bit weight values (same layout)
// result     : signed ADW-bit dot product

module mac_unit #(
    parameter IDW = 8,
    parameter WDW = 8,
    parameter ADW = 32
)(
    input  wire [27*IDW-1:0]     window_flat,
    input  wire [27*WDW-1:0]     weight_flat,
    output wire signed [ADW-1:0] result
);
    // Unpack and compute 27 signed products
    wire signed [ADW-1:0] p0  = $signed(window_flat[ 0*IDW +: IDW]) * $signed(weight_flat[ 0*WDW +: WDW]);
    wire signed [ADW-1:0] p1  = $signed(window_flat[ 1*IDW +: IDW]) * $signed(weight_flat[ 1*WDW +: WDW]);
    wire signed [ADW-1:0] p2  = $signed(window_flat[ 2*IDW +: IDW]) * $signed(weight_flat[ 2*WDW +: WDW]);
    wire signed [ADW-1:0] p3  = $signed(window_flat[ 3*IDW +: IDW]) * $signed(weight_flat[ 3*WDW +: WDW]);
    wire signed [ADW-1:0] p4  = $signed(window_flat[ 4*IDW +: IDW]) * $signed(weight_flat[ 4*WDW +: WDW]);
    wire signed [ADW-1:0] p5  = $signed(window_flat[ 5*IDW +: IDW]) * $signed(weight_flat[ 5*WDW +: WDW]);
    wire signed [ADW-1:0] p6  = $signed(window_flat[ 6*IDW +: IDW]) * $signed(weight_flat[ 6*WDW +: WDW]);
    wire signed [ADW-1:0] p7  = $signed(window_flat[ 7*IDW +: IDW]) * $signed(weight_flat[ 7*WDW +: WDW]);
    wire signed [ADW-1:0] p8  = $signed(window_flat[ 8*IDW +: IDW]) * $signed(weight_flat[ 8*WDW +: WDW]);
    wire signed [ADW-1:0] p9  = $signed(window_flat[ 9*IDW +: IDW]) * $signed(weight_flat[ 9*WDW +: WDW]);
    wire signed [ADW-1:0] p10 = $signed(window_flat[10*IDW +: IDW]) * $signed(weight_flat[10*WDW +: WDW]);
    wire signed [ADW-1:0] p11 = $signed(window_flat[11*IDW +: IDW]) * $signed(weight_flat[11*WDW +: WDW]);
    wire signed [ADW-1:0] p12 = $signed(window_flat[12*IDW +: IDW]) * $signed(weight_flat[12*WDW +: WDW]);
    wire signed [ADW-1:0] p13 = $signed(window_flat[13*IDW +: IDW]) * $signed(weight_flat[13*WDW +: WDW]);
    wire signed [ADW-1:0] p14 = $signed(window_flat[14*IDW +: IDW]) * $signed(weight_flat[14*WDW +: WDW]);
    wire signed [ADW-1:0] p15 = $signed(window_flat[15*IDW +: IDW]) * $signed(weight_flat[15*WDW +: WDW]);
    wire signed [ADW-1:0] p16 = $signed(window_flat[16*IDW +: IDW]) * $signed(weight_flat[16*WDW +: WDW]);
    wire signed [ADW-1:0] p17 = $signed(window_flat[17*IDW +: IDW]) * $signed(weight_flat[17*WDW +: WDW]);
    wire signed [ADW-1:0] p18 = $signed(window_flat[18*IDW +: IDW]) * $signed(weight_flat[18*WDW +: WDW]);
    wire signed [ADW-1:0] p19 = $signed(window_flat[19*IDW +: IDW]) * $signed(weight_flat[19*WDW +: WDW]);
    wire signed [ADW-1:0] p20 = $signed(window_flat[20*IDW +: IDW]) * $signed(weight_flat[20*WDW +: WDW]);
    wire signed [ADW-1:0] p21 = $signed(window_flat[21*IDW +: IDW]) * $signed(weight_flat[21*WDW +: WDW]);
    wire signed [ADW-1:0] p22 = $signed(window_flat[22*IDW +: IDW]) * $signed(weight_flat[22*WDW +: WDW]);
    wire signed [ADW-1:0] p23 = $signed(window_flat[23*IDW +: IDW]) * $signed(weight_flat[23*WDW +: WDW]);
    wire signed [ADW-1:0] p24 = $signed(window_flat[24*IDW +: IDW]) * $signed(weight_flat[24*WDW +: WDW]);
    wire signed [ADW-1:0] p25 = $signed(window_flat[25*IDW +: IDW]) * $signed(weight_flat[25*WDW +: WDW]);
    wire signed [ADW-1:0] p26 = $signed(window_flat[26*IDW +: IDW]) * $signed(weight_flat[26*WDW +: WDW]);

    assign result = p0+p1+p2+p3+p4+p5+p6+p7+p8+
                    p9+p10+p11+p12+p13+p14+p15+p16+p17+
                    p18+p19+p20+p21+p22+p23+p24+p25+p26;

endmodule
