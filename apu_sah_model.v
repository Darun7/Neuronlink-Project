// apu_sah_model.v
module apu_sah_model (
    input logic         clk,
    input logic         rst_n,
    input logic         sample_en,    // When high, sample vin
    input real          vin,          // Analog input
    output real         vout          // Held analog value
);

    real held_value;

    assign vout = held_value;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            held_value <= 0.0;
        else if (sample_en)
            held_value <= vin;       // Sample current input
        // else: hold last sampled value
    end

endmodule
