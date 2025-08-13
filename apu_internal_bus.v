module apu_internal_bus #(
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
    output real                   mem_iout [M],
    output reg  [DATA_WIDTH-1:0]  adc_digital_data
);

    // Internal connections
    real analog_out;          // Output of DAC
    real mem_vin [N];         // Inputs to memristor
    real mem_outputs [M];     // Outputs from memristor
    real sah_output;          // Output of sample-and-hold
    real adc_input;           // Input to ADC

    assign sah_vout = sah_output;

    // DAC instance
    apu_dac_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .VREF(VREF)
    ) u_dac (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .digital_in(digital_in),
        .analog_out(analog_out)
    );

    // Generate analog inputs to memristor
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : vin_gen
            always_comb begin
                mem_vin[i] = mem_vin_enable[i] ? analog_out : 0.0;
            end
        end
    endgenerate

    // Memristor crossbar instance
    apu_memristor_xbar_model #(
        .N(N),
        .M(M)
    ) u_memristor (
        .vin(mem_vin),
        .iout(mem_iout)
    );

    // Sample-and-hold
    apu_sah_model u_sah (
        .clk(clk),
        .rst_n(~rst),
        .sample_en(sah_sample_en),
        .vin(analog_out),
        .vout(sah_output)
    );

    // ADC
    apu_adc_if u_adc (
        .clk(clk),
        .rst_n(~rst),
        .enable(enable),
        .analog_in(sah_output),
        .digital_out(adc_digital_data)
    );

endmodule
