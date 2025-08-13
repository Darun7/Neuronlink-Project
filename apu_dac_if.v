// apu_dac_if.v
module apu_dac_if #(
    parameter DATA_WIDTH = 8,       // Width of digital input
    parameter VREF = 1.0            // Reference voltage for DAC (for modeling)
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   enable,
    input  wire [DATA_WIDTH-1:0]  digital_in,
    output real                   analog_out
);

    real internal_analog;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            internal_analog <= 0.0;
        end else if (enable) begin
            // Convert digital input to analog voltage
            internal_analog <= (VREF * digital_in) / ((1 << DATA_WIDTH) - 1);
        end
    end

    assign analog_out = internal_analog;

endmodule
