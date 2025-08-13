`timescale 1ns / 1ps

module nc_tx_pl_encoder #(
    parameter PAYLOAD_WIDTH = 64,
    parameter HEADER_SYNC_WIDTH = 8,
    parameter HEADER_CHECK_WIDTH = 4,
    parameter HEADER_PACKAGE_WIDTH = 4,
    parameter OUT_WIDTH = PAYLOAD_WIDTH + HEADER_SYNC_WIDTH + HEADER_CHECK_WIDTH + HEADER_PACKAGE_WIDTH
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire                   ready_in,
    input  wire [PAYLOAD_WIDTH-1:0] payload_in,
    output wire                   valid_out,
    output wire [OUT_WIDTH-1:0]   encoded_out
);

    localparam [HEADER_SYNC_WIDTH-1:0] SYNC_HEADER = 8'hA5;
    localparam [HEADER_CHECK_WIDTH-1:0] CHECK_HEADER = 4'hF;
    localparam [HEADER_PACKAGE_WIDTH-1:0] PACKAGE_HEADER = 4'h1;

    reg valid_reg;
    reg [OUT_WIDTH-1:0] encoded_reg;

    wire ready_out;
    assign ready_out = ~valid_reg || ready_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg   <= 1'b0;
            encoded_reg <= {OUT_WIDTH{1'b0}};
        end else if (ready_out) begin
            valid_reg   <= valid_in;
            encoded_reg <= {SYNC_HEADER, CHECK_HEADER, PACKAGE_HEADER, payload_in};
        end
    end

    assign valid_out   = valid_reg;
    assign encoded_out = encoded_reg;

endmodule