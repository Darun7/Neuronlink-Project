`timescale 1ns / 1ps

module nc_tx_dll_retry_buffer #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 4  // Size of retry buffer = 2^ADDR_WIDTH
)(
    input                      clk,
    input                      rst_n,

    // Write interface: store flits sent
    input                      wr_en,
    input      [DATA_WIDTH-1:0] wr_data,

    // Retry command interface
    input                      retry_req,
    input      [ADDR_WIDTH-1:0] retry_addr,

    // Output data for retry
    output reg                 retry_data_valid,
    output reg [DATA_WIDTH-1:0] retry_data
);

    // Buffer depth
    localparam DEPTH = (1 << ADDR_WIDTH);

    // Memory to store flits
    reg [DATA_WIDTH-1:0] buffer_mem [0:DEPTH-1];

    integer i;

    // Write pointer (address to write next flit)
    reg [ADDR_WIDTH-1:0] wr_ptr;

    // Write flits into buffer
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_ptr <= 0;
            for(i = 0; i < DEPTH; i = i + 1)
                buffer_mem[i] <= {DATA_WIDTH{1'b0}};
        end else begin
            if(wr_en) begin
                buffer_mem[wr_ptr] <= wr_data;
                wr_ptr <= wr_ptr + 1;
            end
        end
    end

    // Retry output logic
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            retry_data <= 0;
            retry_data_valid <= 0;
        end else begin
            if(retry_req) begin
                retry_data <= buffer_mem[retry_addr];
                retry_data_valid <= 1;
            end else begin
                retry_data_valid <= 0;
            end
        end
    end

endmodule