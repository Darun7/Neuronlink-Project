`timescale 1ns / 1ps

module nc_rx_dll_vc_buffers #(
    parameter DATA_WIDTH = 64,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = 4  // log2(FIFO_DEPTH)
)(
    input wire clk,
    input wire rst_n,
    
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire [1:0] vc_id,

    // Outputs for each VC
    output wire [DATA_WIDTH-1:0] vc0_data_out,
    output wire [DATA_WIDTH-1:0] vc1_data_out,
    output wire [DATA_WIDTH-1:0] vc2_data_out,
    output wire [DATA_WIDTH-1:0] vc3_data_out,
    
    output wire vc0_empty,
    output wire vc1_empty,
    output wire vc2_empty,
    output wire vc3_empty,
    
    input wire vc0_rd_en,
    input wire vc1_rd_en,
    input wire vc2_rd_en,
    input wire vc3_rd_en,
    
    output wire vc0_full,
    output wire vc1_full,
    output wire vc2_full,
    output wire vc3_full
);

    // Simple parameterized FIFO module (inside this file)
    // Synchronous FIFO, single clock
    module fifo #(
        parameter DATA_WIDTH = 64,
        parameter DEPTH = 16,
        parameter ADDR_WIDTH = 4
    ) (
        input  wire clk,
        input  wire rst_n,
        input  wire wr_en,
        input  wire rd_en,
        input  wire [DATA_WIDTH-1:0] data_in,
        output reg  [DATA_WIDTH-1:0] data_out,
        output wire empty,
        output wire full
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

    // Instantiate FIFO for each VC
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) vc0_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(valid_in & (vc_id == 2'd0)),
        .rd_en(vc0_rd_en),
        .data_in(data_in),
        .data_out(vc0_data_out),
        .empty(vc0_empty),
        .full(vc0_full)
    );

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) vc1_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(valid_in & (vc_id == 2'd1)),
        .rd_en(vc1_rd_en),
        .data_in(data_in),
        .data_out(vc1_data_out),
        .empty(vc1_empty),
        .full(vc1_full)
    );

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) vc2_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(valid_in & (vc_id == 2'd2)),
        .rd_en(vc2_rd_en),
        .data_in(data_in),
        .data_out(vc2_data_out),
        .empty(vc2_empty),
        .full(vc2_full)
    );

    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) vc3_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(valid_in & (vc_id == 2'd3)),
        .rd_en(vc3_rd_en),
        .data_in(data_in),
        .data_out(vc3_data_out),
        .empty(vc3_empty),
        .full(vc3_full)
    );

endmodule