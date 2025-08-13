`timescale 1ns / 1ps

module nc_tx_dll_vc_buffers #(
    parameter DATA_WIDTH = 64,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = 4
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // Write interface (from analyzer/CRM)
    input  wire                    valid_in,
    input  wire [DATA_WIDTH-1:0]   packet_in,
    input  wire [1:0]              packet_priority, // selects which VC to write

    // Read interface (to CRM)
    output wire [DATA_WIDTH-1:0]   vc0_data_out,
    output wire [DATA_WIDTH-1:0]   vc1_data_out,
    output wire [DATA_WIDTH-1:0]   vc2_data_out,
    output wire [DATA_WIDTH-1:0]   vc3_data_out,
    output wire                    vc0_empty,
    output wire                    vc1_empty,
    output wire                    vc2_empty,
    output wire                    vc3_empty,
    input  wire                    vc0_rd_en,
    input  wire                    vc1_rd_en,
    input  wire                    vc2_rd_en,
    input  wire                    vc3_rd_en,
    output wire                    vc0_full,
    output wire                    vc1_full,
    output wire                    vc2_full,
    output wire                    vc3_full
);

    // Write enables for each FIFO
    wire [3:0] wr_en;
    assign wr_en[0] = valid_in && (packet_priority == 2'b00);
    assign wr_en[1] = valid_in && (packet_priority == 2'b01);
    assign wr_en[2] = valid_in && (packet_priority == 2'b10);
    assign wr_en[3] = valid_in && (packet_priority == 2'b11);

    // VC 0
    nc_simple_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) vc0_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en[0]),
        .wr_data(packet_in),
        .rd_en(vc0_rd_en),
        .rd_data(vc0_data_out),
        .empty(vc0_empty),
        .full(vc0_full)
    );

    // VC 1
    nc_simple_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) vc1_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en[1]),
        .wr_data(packet_in),
        .rd_en(vc1_rd_en),
        .rd_data(vc1_data_out),
        .empty(vc1_empty),
        .full(vc1_full)
    );

    // VC 2
    nc_simple_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) vc2_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en[2]),
        .wr_data(packet_in),
        .rd_en(vc2_rd_en),
        .rd_data(vc2_data_out),
        .empty(vc2_empty),
        .full(vc2_full)
    );

    // VC 3
    nc_simple_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) vc3_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en[3]),
        .wr_data(packet_in),
        .rd_en(vc3_rd_en),
        .rd_data(vc3_data_out),
        .empty(vc3_empty),
        .full(vc3_full)
    );

endmodule

// ----------- FIFO MODULE (synthesizable, ready/valid compatible) -----------
module nc_simple_fifo #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH = 16
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   wr_en,
    input  wire [DATA_WIDTH-1:0]  wr_data,
    input  wire                   rd_en,
    output wire [DATA_WIDTH-1:0]  rd_data,
    output wire                   empty,
    output wire                   full
);

    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH:0]   wr_ptr = 0;
    reg [ADDR_WIDTH:0]   rd_ptr = 0;

    wire [ADDR_WIDTH-1:0] wr_addr = wr_ptr[ADDR_WIDTH-1:0];
    wire [ADDR_WIDTH-1:0] rd_addr = rd_ptr[ADDR_WIDTH-1:0];

    assign empty = (wr_ptr == rd_ptr);
    assign full  = ((wr_ptr[ADDR_WIDTH] != rd_ptr[ADDR_WIDTH]) && (wr_ptr[ADDR_WIDTH-1:0] == rd_ptr[ADDR_WIDTH-1:0]));

    assign rd_data = mem[rd_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_addr] <= wr_data;
            wr_ptr <= wr_ptr + 1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (rd_en && !empty) begin
            rd_ptr <= rd_ptr + 1;
        end
    end

endmodule