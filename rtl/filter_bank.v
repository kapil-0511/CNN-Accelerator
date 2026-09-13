`timescale 1ns/1ps
// 8 parallel filter units — one mac_unit per output channel.
// window_flat : 27 x IDW-bit current 3x3x3 input window (shared by all filters)
// weights_flat: 8 x 27 x WDW-bit weights  (layout: filter*27*WDW + k*WDW)
// results_flat: 8 x ADW-bit dot products

module filter_bank #(
    parameter IDW = 8,
    parameter WDW = 8,
    parameter ADW = 32,
    parameter NF  = 8     // number of filters
)(
    input  wire [27*IDW-1:0]    window_flat,
    input  wire [NF*27*WDW-1:0] weights_flat,
    output wire [NF*ADW-1:0]    results_flat
);
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f0 (.window_flat(window_flat), .weight_flat(weights_flat[ 0*27*WDW +: 27*WDW]), .result(results_flat[ 0*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f1 (.window_flat(window_flat), .weight_flat(weights_flat[ 1*27*WDW +: 27*WDW]), .result(results_flat[ 1*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f2 (.window_flat(window_flat), .weight_flat(weights_flat[ 2*27*WDW +: 27*WDW]), .result(results_flat[ 2*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f3 (.window_flat(window_flat), .weight_flat(weights_flat[ 3*27*WDW +: 27*WDW]), .result(results_flat[ 3*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f4 (.window_flat(window_flat), .weight_flat(weights_flat[ 4*27*WDW +: 27*WDW]), .result(results_flat[ 4*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f5 (.window_flat(window_flat), .weight_flat(weights_flat[ 5*27*WDW +: 27*WDW]), .result(results_flat[ 5*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f6 (.window_flat(window_flat), .weight_flat(weights_flat[ 6*27*WDW +: 27*WDW]), .result(results_flat[ 6*ADW +: ADW]));
    mac_unit #(.IDW(IDW),.WDW(WDW),.ADW(ADW)) u_f7 (.window_flat(window_flat), .weight_flat(weights_flat[ 7*27*WDW +: 27*WDW]), .result(results_flat[ 7*ADW +: ADW]));

endmodule
