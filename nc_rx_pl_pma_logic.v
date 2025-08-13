`timescale 1ns / 1ps

module nc_rx_pl_pma_logic #(
    parameter DATA_WIDTH = 8,
    parameter ALIGN_PATTERN = 8'hBC
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Input from deserializer
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                   data_valid,

    // Output to PCS layer
    output reg  [DATA_WIDTH-1:0] data_out,
    output reg                   data_out_valid,
    output reg                   aligned
);

    reg searching;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out       <= 0;
            data_out_valid <= 0;
            aligned        <= 0;
            searching      <= 1;
        end else begin
            data_out_valid <= 0;

            if (data_valid) begin
                if (searching) begin
                    if (data_in == ALIGN_PATTERN) begin
                        aligned   <= 1;
                        searching <= 0;
                    end
                end else begin
                    data_out       <= data_in;
                    data_out_valid <= 1;
                end
            end
        end
    end

endmodule