`timescale 1ns / 1ps

module fifo #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = 4
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                wr_en,
    input  wire                rd_en,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg  [DATA_WIDTH-1:0] data_out,
    output wire                empty,
    output wire                full
);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0] wr_ptr = 0;
    reg [ADDR_WIDTH:0] rd_ptr = 0;
    reg [ADDR_WIDTH:0] count = 0;

    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count  <= 0;
            data_out <= 0;
        end else begin
            // Write
            if (wr_en && !full) begin
                mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
                wr_ptr <= wr_ptr + 1;
                count  <= count + 1;
            end
            // Read
            if (rd_en && !empty) begin
                data_out <= mem[rd_ptr[ADDR_WIDTH-1:0]];
                rd_ptr <= rd_ptr + 1;
                count  <= count - 1;
            end
        end
    end

endmodule