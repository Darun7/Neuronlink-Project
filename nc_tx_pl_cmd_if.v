`timescale 1ns / 1ps

module nc_tx_pl_cmd_if #(
    parameter CMD_WIDTH = 8
)(
    input  wire             clk,
    input  wire             rst_n,

    // From Data Link Layer (async domain)
    input  wire [CMD_WIDTH-1:0] cmd_in,
    input  wire                 cmd_valid,
    output reg                  cmd_ready,

    // To Physical Layer Serializer (sync domain)
    output reg [CMD_WIDTH-1:0]  cmd_out,
    output reg                  cmd_out_valid,
    input  wire                 cmd_out_ready
);

    reg cmd_latched;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd_ready <= 1;
            cmd_out_valid <= 0;
            cmd_latched <= 0;
        end else begin
            if (cmd_valid && cmd_ready) begin
                // Latch incoming command
                cmd_out <= cmd_in;
                cmd_out_valid <= 1;
                cmd_ready <= 0;  // Busy until cmd consumed
                cmd_latched <= 1;
            end else if (cmd_out_valid && cmd_out_ready) begin
                // Command consumed by next stage
                cmd_out_valid <= 0;
                cmd_ready <= 1;
                cmd_latched <= 0;
            end
        end
    end

endmodule
