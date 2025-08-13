`timescale 1ns/1ps

module pn_edram_if #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter BUSY_CYCLES = 3
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   wr_en,
    input  wire                   rd_en,
    input  wire [ADDR_WIDTH-1:0] addr,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output reg                    busy,
    output reg  [DATA_WIDTH-1:0] rd_data
);

    reg [DATA_WIDTH-1:0] mem [0:(1 << ADDR_WIDTH)-1];
    reg [ADDR_WIDTH-1:0] latched_addr;
    reg rd_active;
    reg [1:0] busy_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            busy_cnt <= 0;
            rd_data <= 0;
            rd_active <= 0;
        end else begin
            if (wr_en && !busy) begin
                mem[addr] <= wr_data;
                busy <= 1;
                busy_cnt <= BUSY_CYCLES - 1;
                rd_active <= 0;
            end else if (rd_en && !busy) begin
                latched_addr <= addr;
                busy <= 1;
                busy_cnt <= BUSY_CYCLES - 1;
                rd_active <= 1;
            end else if (busy) begin
                if (busy_cnt > 0) begin
                    busy_cnt <= busy_cnt - 1;
                end else begin
                    busy <= 0;
                    if (rd_active) begin
                        rd_data <= mem[latched_addr];
                        rd_active <= 0;
                    end
                end
            end
        end
    end

endmodule
