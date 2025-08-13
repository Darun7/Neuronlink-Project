module nc_tx_dll_async_fifo #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 4
)(
    input  wire                 wr_clk,
    input  wire                 wr_rst,
    input  wire                 wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                 full,

    input  wire                 rd_clk,
    input  wire                 rd_rst,
    input  wire                 rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                 empty
);

    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [ADDR_WIDTH:0] wr_ptr_bin = 0;
    reg [ADDR_WIDTH:0] rd_ptr_bin = 0;

    reg [ADDR_WIDTH:0] wr_ptr_gray = 0, rd_ptr_gray_sync1 = 0, rd_ptr_gray_sync2 = 0;
    reg [ADDR_WIDTH:0] rd_ptr_gray = 0, wr_ptr_gray_sync1 = 0, wr_ptr_gray_sync2 = 0;

    // Write logic
    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_ptr_bin <= 0;
            wr_ptr_gray <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            wr_ptr_bin <= wr_ptr_bin + 1;
            wr_ptr_gray <= (wr_ptr_bin + 1) ^ ((wr_ptr_bin + 1) >> 1);
        end
    end

    // Read logic
    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rd_ptr_bin <= 0;
            rd_ptr_gray <= 0;
            rd_data <= 0;
        end else if (rd_en && !empty) begin
            rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
            rd_ptr_bin <= rd_ptr_bin + 1;
            rd_ptr_gray <= (rd_ptr_bin + 1) ^ ((rd_ptr_bin + 1) >> 1);
        end
    end

    // Gray sync: Read pointer into write domain
    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // Gray sync: Write pointer into read domain
    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

    wire [ADDR_WIDTH:0] wr_ptr_bin_sync, rd_ptr_bin_sync;
    assign wr_ptr_bin_sync = gray_to_bin(wr_ptr_gray_sync2);
    assign rd_ptr_bin_sync = gray_to_bin(rd_ptr_gray_sync2);

    assign full  = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);

    function [ADDR_WIDTH:0] gray_to_bin;
        input [ADDR_WIDTH:0] gray;
        integer i;
        begin
            gray_to_bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH-1; i >= 0; i = i - 1)
                gray_to_bin[i] = gray_to_bin[i+1] ^ gray[i];
        end
    endfunction

endmodule
