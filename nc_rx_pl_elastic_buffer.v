`timescale 1ns / 1ps

module nc_rx_pl_elastic_buffer #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 16
)(
    input  wire                  rx_clk,      // Write clock (from recovered RX)
    input  wire                  rx_rst,      // Reset for rx_clk domain
    input  wire                  wr_en,       // Write enable from RX domain
    input  wire [DATA_WIDTH-1:0] din,         // Data in

    input  wire                  local_clk,   // Read clock (local domain)
    input  wire                  local_rst,   // Reset for local_clk domain
    input  wire                  rd_en,       // Read enable from local domain
    output reg  [DATA_WIDTH-1:0] dout,        // Data out
    output reg                   valid_out    // Data valid
);

    reg [DATA_WIDTH-1:0] buffer [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wr_ptr = 0;
    reg [$clog2(DEPTH):0] rd_ptr = 0;

    // Write Logic (RX clock domain)
    always @(posedge rx_clk or posedge rx_rst) begin
        if (rx_rst) begin
            wr_ptr <= 0;
        end else if (wr_en) begin
            buffer[wr_ptr[$clog2(DEPTH)-1:0]] <= din;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read Logic (Local clock domain)
    always @(posedge local_clk or posedge local_rst) begin
        if (local_rst) begin
            rd_ptr <= 0;
            dout <= 0;
            valid_out <= 0;
        end else if (rd_en && (rd_ptr != wr_ptr)) begin
            dout <= buffer[rd_ptr[$clog2(DEPTH)-1:0]];
            rd_ptr <= rd_ptr + 1;
            valid_out <= 1;
        end else begin
            valid_out <= 0;
        end
    end

endmodule