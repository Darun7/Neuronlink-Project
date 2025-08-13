`timescale 1ns / 1ps

module nl_router_vc_input_buffer #(
    parameter DATA_WIDTH = 32,
    parameter VC_COUNT = 4,
    parameter VC_DEPTH = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  pkt_valid,
    input  wire [DATA_WIDTH-1:0] pkt_data,
    input  wire                  rc_ready,        // Handshake: downstream ready to dequeue
    output reg                   rc_valid,
    output reg  [DATA_WIDTH-1:0] rc_header_out
);

    reg [DATA_WIDTH-1:0] vc_fifo [VC_COUNT-1:0][VC_DEPTH-1:0];
    reg [$clog2(VC_DEPTH):0] wr_ptr [VC_COUNT-1:0];
    reg [$clog2(VC_DEPTH):0] rd_ptr [VC_COUNT-1:0];
    integer i;

    wire [$clog2(VC_COUNT)-1:0] vc_select = pkt_data[31:30];

    reg found;
    reg [$clog2(VC_COUNT)-1:0] chosen_vc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < VC_COUNT; i = i + 1) begin
                wr_ptr[i] <= 0;
                rd_ptr[i] <= 0;
            end
            rc_valid <= 0;
            rc_header_out <= 0;
            chosen_vc <= 0;
        end else begin
            // Write if valid and not full
            if (pkt_valid && (wr_ptr[vc_select] < VC_DEPTH)) begin
                vc_fifo[vc_select][wr_ptr[vc_select]] <= pkt_data;
                wr_ptr[vc_select] <= wr_ptr[vc_select] + 1;
            end

            // Output logic (lowest non-empty VC)
            found = 0;
            rc_valid = 0;
            rc_header_out = 0;
            chosen_vc = 0;
            for (i = 0; i < VC_COUNT; i = i + 1) begin
                if (!found && wr_ptr[i] > rd_ptr[i]) begin
                    rc_valid = 1;
                    rc_header_out = vc_fifo[i][rd_ptr[i]];
                    chosen_vc = i;
                    found = 1;
                end
            end

            // Dequeue if downstream ready and valid
            if (rc_valid && rc_ready) begin
                rd_ptr[chosen_vc] <= rd_ptr[chosen_vc] + 1;
            end
        end
    end
endmodule