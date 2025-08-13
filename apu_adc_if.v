module apu_adc_if (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,      // ADC enable
    input  real        analog_in,   // Analog input voltage (0.0 to 1.0)
    output reg  [7:0]  digital_out  // 8-bit digital output
);

    parameter real VREF = 1.0;  // Reference voltage for ADC

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digital_out <= 8'd0;
        end else if (enable) begin
            if (analog_in <= 0.0)
                digital_out <= 8'd0;
            else if (analog_in >= VREF)
                digital_out <= 8'd255;
            else
                digital_out <= $rtoi((analog_in / VREF) * 255.0);
        end
    end

endmodule
