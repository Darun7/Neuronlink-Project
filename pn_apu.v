`timescale 1ns / 1ps

module pn_apu #(
    parameter DATA_WIDTH = 8,
    parameter VREF = 1.0,
    parameter N = 4,
    parameter M = 4
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   enable,
    input  wire [DATA_WIDTH-1:0]  digital_in,
    input  wire                   sah_sample_en,
    input  wire [N-1:0]           mem_vin_enable,

    output real                   sah_vout,
    output real                   mem_iout[M],
    output reg  [DATA_WIDTH-1:0]  adc_digital_data
);

    // Internal bus instance connects all components:
    apu_internal_bus #(
        .DATA_WIDTH(DATA_WIDTH),
        .VREF(VREF),
        .N(N),
        .M(M)
    ) u_internal_bus (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .digital_in(digital_in),
        .sah_sample_en(sah_sample_en),
        .mem_vin_enable(mem_vin_enable),
        .sah_vout(sah_vout),
        .mem_iout(mem_iout),
        .adc_digital_data(adc_digital_data)
    );

endmodule
