`timescale 1ns / 1ps

module nc_tx_pl_control_field_gen #(
    parameter WIDTH = 80  // total control field width (10 bytes * 8 bits)
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire         back_pressure,
    input  wire         not_ready,
    input  wire         channel_bonding,
    input  wire         idle,

    output reg [WIDTH-1:0] control_field_out
);

    // Control field patterns from Table III (example values)
    localparam [7:0] CTRL_BACK_PRESSURE  = 8'hFF; // example pattern
    localparam [7:0] CTRL_NOT_READY      = 8'hAA; // example pattern
    localparam [7:0] CTRL_CHANNEL_BOND   = 8'hCC; // example pattern
    localparam [7:0] CTRL_IDLE           = 8'h00; // example pattern
    localparam [7:0] CTRL_NORMAL         = 8'h55; // normal (data) control

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_field_out <= {WIDTH{1'b0}};
        end else begin
            for (i = 0; i < WIDTH/8; i = i + 1) begin
                if (back_pressure) begin
                    control_field_out[i*8 +: 8] <= CTRL_BACK_PRESSURE;
                end else if (not_ready) begin
                    control_field_out[i*8 +: 8] <= CTRL_NOT_READY;
                end else if (channel_bonding) begin
                    control_field_out[i*8 +: 8] <= CTRL_CHANNEL_BOND;
                end else if (idle) begin
                    control_field_out[i*8 +: 8] <= CTRL_IDLE;
                end else begin
                    control_field_out[i*8 +: 8] <= CTRL_NORMAL;
                end
            end
        end
    end

endmodule
