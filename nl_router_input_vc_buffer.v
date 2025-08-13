`timescale 1ns / 1ps

module nl_router_input_vc_buffer #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire [DATA_WIDTH-1:0] in_data,
    output wire                  in_ready,
    output wire                  out_valid,
    output wire [DATA_WIDTH-1:0] out_data,
    input  wire                  out_ready
);

    reg [DATA_WIDTH-1:0] fifo [0:DEPTH-1];
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    reg [$clog2(DEPTH+1)-1:0] count;

    // Write logic
    wire can_write = in_valid && (count < DEPTH);
    wire can_read  = (count > 0) && out_ready;

    // FIFO write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
        end else if (can_write) begin
            fifo[wr_ptr] <= in_data;
            wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
        end
    end

    // FIFO read
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
        end else if (can_read) begin
            rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
        end
    end

    // FIFO count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({can_write, can_read})
                2'b10: count <= count + 1; // write only
                2'b01: count <= count - 1; // read only
                2'b11: count <= count;     // write+read: count unchanged
                2'b00: count <= count;
            endcase
        end
    end

    assign in_ready  = (count < DEPTH);
    assign out_valid = (count > 0);
    assign out_data  = fifo[rd_ptr];

endmodule