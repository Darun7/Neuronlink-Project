`timescale 1ns / 1ps

module nl_router_input_port #(
    parameter DATA_WIDTH = 32,
    parameter VC_COUNT   = 4,
    parameter VC_DEPTH   = 4
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Incoming packet interface
    input  wire                  pkt_valid,
    input  wire [DATA_WIDTH-1:0] pkt_data,

    // Outputs to route computation
    output wire                  rc_valid,
    output wire [DATA_WIDTH-1:0] rc_header_out,

    // VC allocator interface
    input  wire [VC_COUNT-1:0]   vc_alloc_grant,
    output wire [VC_COUNT-1:0]   vc_alloc_req
);

    // Handshake for buffer dequeue: any grant triggers dequeue if valid
    wire rc_ready;
    assign rc_ready = rc_valid && (|vc_alloc_grant);

    // Instantiate the VC input buffer
    nl_router_vc_input_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .VC_COUNT(VC_COUNT),
        .VC_DEPTH(VC_DEPTH)
    ) vc_input_buffer (
        .clk(clk),
        .rst_n(rst_n),
        .pkt_valid(pkt_valid),
        .pkt_data(pkt_data),
        .rc_ready(rc_ready),
        .rc_valid(rc_valid),
        .rc_header_out(rc_header_out)
    );

    // VC request logic: request all VCs if header valid (can be refined)
    assign vc_alloc_req = rc_valid ? {VC_COUNT{1'b1}} : {VC_COUNT{1'b0}};

endmodule