`timescale 1ns / 1ps

module nc_tx_pl_data_if #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = 4 // log2(FIFO_DEPTH)
)(
    // Write side (DLL domain)
    input  wire                   wr_clk,
    input  wire                   wr_rst_n,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                   wr_en,
    output wire                   wr_full,

    // Read side (PHY domain)
    input  wire                   rd_clk,
    input  wire                   rd_rst_n,
    output reg  [DATA_WIDTH-1:0]  rd_data,
    input  wire                   rd_en,
    output wire                   rd_empty
);

    // FIFO memory
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];

    // Write pointer and its Gray code
    reg [ADDR_WIDTH:0] wr_ptr_bin = 0;
    reg [ADDR_WIDTH:0] wr_ptr_gray = 0;

    // Read pointer and its Gray code
    reg [ADDR_WIDTH:0] rd_ptr_bin = 0;
    reg [ADDR_WIDTH:0] rd_ptr_gray = 0;

    // Synchronized pointers
    reg [ADDR_WIDTH:0] rd_ptr_gray_sync_wr1 = 0, rd_ptr_gray_sync_wr2 = 0;
    reg [ADDR_WIDTH:0] wr_ptr_gray_sync_rd1 = 0, wr_ptr_gray_sync_rd2 = 0;

    // Next pointer values
    wire [ADDR_WIDTH:0] wr_ptr_bin_next = wr_ptr_bin + ((wr_en && !wr_full) ? 1'b1 : 1'b0);
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = bin2gray(wr_ptr_bin_next);
    wire [ADDR_WIDTH:0] rd_ptr_bin_next = rd_ptr_bin + ((rd_en && !rd_empty) ? 1'b1 : 1'b0);
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = bin2gray(rd_ptr_bin_next);

    // Write domain logic
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_ptr_bin <= 0;
            wr_ptr_gray <= 0;
        end else begin
            wr_ptr_bin <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            if (wr_en && !wr_full)
                fifo_mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
        end
    end

    // Read domain logic
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_ptr_bin <= 0;
            rd_ptr_gray <= 0;
            rd_data <= 0;
        end else begin
            rd_ptr_bin <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
            if (rd_en && !rd_empty)
                rd_data <= fifo_mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
        end
    end

    // Synchronize read pointer into write domain
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_ptr_gray_sync_wr1 <= 0;
            rd_ptr_gray_sync_wr2 <= 0;
        end else begin
            rd_ptr_gray_sync_wr1 <= rd_ptr_gray;
            rd_ptr_gray_sync_wr2 <= rd_ptr_gray_sync_wr1;
        end
    end

    // Synchronize write pointer into read domain
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_ptr_gray_sync_rd1 <= 0;
            wr_ptr_gray_sync_rd2 <= 0;
        end else begin
            wr_ptr_gray_sync_rd1 <= wr_ptr_gray;
            wr_ptr_gray_sync_rd2 <= wr_ptr_gray_sync_rd1;
        end
    end

    // Full/Empty logic
    assign wr_full  = ( (wr_ptr_gray_next[ADDR_WIDTH]     != rd_ptr_gray_sync_wr2[ADDR_WIDTH]) &&
                        (wr_ptr_gray_next[ADDR_WIDTH-1]   != rd_ptr_gray_sync_wr2[ADDR_WIDTH-1]) &&
                        (wr_ptr_gray_next[ADDR_WIDTH-2:0] == rd_ptr_gray_sync_wr2[ADDR_WIDTH-2:0]) );
    assign rd_empty = (rd_ptr_gray == wr_ptr_gray_sync_rd2);

    // Functions for conversion
    function [ADDR_WIDTH:0] bin2gray(input [ADDR_WIDTH:0] bin);
        bin2gray = (bin >> 1) ^ bin;
    endfunction

    function [ADDR_WIDTH:0] gray2bin(input [ADDR_WIDTH:0] gray);
        integer i;
        begin
            gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                gray2bin[i] = gray2bin[i+1] ^ gray[i];
        end
    endfunction

endmodule