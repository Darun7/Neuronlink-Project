`timescale 1ns / 1ps

module nl_router_output_port #(
    parameter DATA_WIDTH = 32,
    parameter FIFO_DEPTH = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Input from crossbar switch
    input  wire                  in_valid,
    input  wire [DATA_WIDTH-1:0] in_data,
    output wire                  in_ready,

    // Output to next stage
    output reg                   out_valid,
    output reg  [DATA_WIDTH-1:0] out_data,
    input  wire                  out_ready
);

    // FIFO storage for outgoing packets
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [$clog2(FIFO_DEPTH)-1:0] wr_ptr, rd_ptr;
    reg [$clog2(FIFO_DEPTH+1)-1:0] fifo_count;

    assign in_ready = (fifo_count < FIFO_DEPTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            fifo_count <= 0;
            out_valid <= 0;
            out_data <= 0;
        end else begin
            // Write
            if (in_valid && in_ready) begin
                fifo_mem[wr_ptr] <= in_data;
                wr_ptr <= (wr_ptr == FIFO_DEPTH-1) ? 0 : wr_ptr + 1;
                fifo_count <= fifo_count + 1;
            end

            // Read
            if (fifo_count > 0 && out_ready) begin
                rd_ptr <= (rd_ptr == FIFO_DEPTH-1) ? 0 : rd_ptr + 1;
                fifo_count <= fifo_count - 1;
            end

            // Output logic
            if (fifo_count > 0)
                out_data <= fifo_mem[rd_ptr];
            else
                out_data <= 0;

            out_valid <= (fifo_count > 0);
        end
    end

endmodule