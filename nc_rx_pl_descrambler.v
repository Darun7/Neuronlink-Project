`timescale 1ns / 1ps

module nc_rx_pl_descrambler #(
    parameter DATA_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   data_in_valid,
    input  wire [DATA_WIDTH-1:0]  data_in,
    output reg                    data_out_valid,
    output reg  [DATA_WIDTH-1:0]  data_out
);

    reg [6:0] lfsr;

    integer i;
    reg [6:0] next_lfsr;
    reg [DATA_WIDTH-1:0] next_data_out;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 7'b1111111;
            data_out <= 0;
            data_out_valid <= 0;
        end else if (data_in_valid) begin
            next_lfsr = lfsr;
            for (i = 0; i < DATA_WIDTH; i = i + 1) begin
                next_data_out[i] = data_in[i] ^ next_lfsr[6] ^ next_lfsr[5];
                next_lfsr = {next_lfsr[5:0], next_data_out[i]};
            end
            data_out <= next_data_out;
            lfsr <= next_lfsr;
            data_out_valid <= 1;
        end else begin
            data_out_valid <= 0;
        end
    end

endmodule