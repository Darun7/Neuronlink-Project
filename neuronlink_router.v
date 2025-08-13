`timescale 1ns / 1ps

module neuronlink_router #(
    parameter DATA_WIDTH = 32,
    parameter VC_COUNT   = 4,
    parameter VC_DEPTH   = 4,
    parameter PORT_COUNT = 5, // N/E/S/W/Local
    parameter FIFO_DEPTH = 4,
    parameter ROUTER_X   = 0,
    parameter ROUTER_Y   = 0
)(
    input  wire clk,
    input  wire rst_n,

    input  wire [PORT_COUNT-1:0]                  in_valid,
    input  wire [PORT_COUNT-1:0][DATA_WIDTH-1:0]  in_data,
    output wire [PORT_COUNT-1:0]                  in_ready,

    output wire [PORT_COUNT-1:0]                  out_valid,
    output wire [PORT_COUNT-1:0][DATA_WIDTH-1:0]  out_data,
    input  wire [PORT_COUNT-1:0]                  out_ready
);

    // VC-level signal declarations
    wire [PORT_COUNT-1:0][VC_COUNT-1:0]           vc_buf_valid, vc_buf_in_ready, vc_buf_out_ready;
    wire [PORT_COUNT-1:0][VC_COUNT-1:0][DATA_WIDTH-1:0] vc_buf_data_out;
    wire [PORT_COUNT-1:0][VC_COUNT-1:0]           vc_alloc_req, vc_alloc_grant;
    wire [PORT_COUNT-1:0][VC_COUNT-1:0][2:0]      route_out_port;

    wire [PORT_COUNT-1:0][PORT_COUNT*VC_COUNT-1:0] sw_req, sw_grant;
    wire [PORT_COUNT-1:0][VC_COUNT-1:0][DATA_WIDTH-1:0] crossbar_data_in;
    wire [PORT_COUNT-1:0][VC_COUNT-1:0]           crossbar_valid_in; // <--- Declare
    wire [PORT_COUNT-1:0][DATA_WIDTH-1:0]         crossbar_out_data;
    wire [PORT_COUNT-1:0]                         crossbar_out_valid;

    // Age & congestion tracking
    wire [7:0] age_matrix        [PORT_COUNT-1:0][VC_COUNT-1:0];
    wire [7:0] congestion_matrix [PORT_COUNT-1:0][VC_COUNT-1:0];
    wire       req_matrix        [PORT_COUNT-1:0][VC_COUNT-1:0];
    wire signed [7:0] score_matrix_flat [PORT_COUNT*VC_COUNT-1:0];
    wire signed [7:0] score_matrix      [PORT_COUNT-1:0][VC_COUNT-1:0];

    // Assign Request Matrix (elementwise)
    genvar rp, rv;
    generate
        for (rp = 0; rp < PORT_COUNT; rp = rp + 1) begin: req_assign
            for (rv = 0; rv < VC_COUNT; rv = rv + 1) begin: req_assign_inner
                assign req_matrix[rp][rv] = vc_alloc_req[rp][rv];
            end
        end
    endgenerate

    // Dummy Age & Congestion (stub, replace later)
    genvar ap, av;
    generate
        for (ap = 0; ap < PORT_COUNT; ap = ap + 1) begin: gen_age_cong
            for (av = 0; av < VC_COUNT; av = av + 1) begin: age_cong
                assign age_matrix[ap][av]        = 8'd5 + ap + av;
                assign congestion_matrix[ap][av] = 8'd1 + ((ap + av) % 3);
            end
        end
    endgenerate

    // Score Matrix Unpacking
    genvar sp, sv;
    generate
        for (sp = 0; sp < PORT_COUNT; sp = sp + 1) begin: score_unpack
            for (sv = 0; sv < VC_COUNT; sv = sv + 1) begin: score_unpack_inner
                assign score_matrix[sp][sv] = score_matrix_flat[sp * VC_COUNT + sv];
            end
        end
    endgenerate

    // Hybrid Score Calculator
    nl_router_weight_comp #(
        .NUM_PORTS(PORT_COUNT),
        .NUM_VCS(VC_COUNT),
        .WIDTH(8),
        .AGE_WEIGHT(1),
        .CONG_WEIGHT(2)
    ) u_weight_comp (
        .age_matrix(age_matrix),
        .congestion_matrix(congestion_matrix),
        .req_matrix(req_matrix),
        .score_matrix_flat(score_matrix_flat)
    );

    // Input ports - VC buffers and route computation
    genvar p, v;
    generate
        for (p = 0; p < PORT_COUNT; p = p + 1) begin: input_ports
            for (v = 0; v < VC_COUNT; v = v + 1) begin: vcs
                nl_router_input_vc_buffer #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .DEPTH(VC_DEPTH)
                ) vc_buf (
                    .clk(clk),
                    .rst_n(rst_n),
                    .in_valid(in_valid[p] && (v == 0)),
                    .in_data(in_data[p]),
                    .in_ready(vc_buf_in_ready[p][v]),
                    .out_valid(vc_buf_valid[p][v]),
                    .out_data(vc_buf_data_out[p][v]),
                    .out_ready(vc_buf_out_ready[p][v])
                );

                nl_router_route_comp #(
                    .ROUTER_X(ROUTER_X),
                    .ROUTER_Y(ROUTER_Y)
                ) route_comp (
                    .header(vc_buf_data_out[p][v][7:0]),
                    .out_port(route_out_port[p][v])
                );

                assign vc_alloc_req[p][v]      = vc_buf_valid[p][v];
                assign crossbar_data_in[p][v]  = vc_buf_data_out[p][v];
                assign crossbar_valid_in[p][v] = vc_buf_valid[p][v]; // <--- FIXED: connect valid to crossbar
                assign vc_buf_out_ready[p][v]  = vc_alloc_grant[p][v] &&
                                                 sw_grant[route_out_port[p][v]][p * VC_COUNT + v];
            end
        end
    endgenerate

    // VC allocators using hybrid score_matrix
    generate
        for (p = 0; p < PORT_COUNT; p = p + 1) begin: vc_allocators
            wire [VC_COUNT*8-1:0] packed_scores;
            for (v = 0; v < VC_COUNT; v = v + 1) begin: pack_scores
                assign packed_scores[(VC_COUNT-v)*8-1 -: 8] = score_matrix[p][v];
            end
            nl_router_vc_allocator #(
                .NUM_VC(VC_COUNT),
                .SCORE_WIDTH(8)
            ) vc_alloc (
                .req(vc_alloc_req[p]),
                .intercept({VC_COUNT{1'b0}}),
                .score(packed_scores),
                .grant(vc_alloc_grant[p])
            );
        end
    endgenerate

    // Switch request generation
    genvar out_p, in_p, vv;
    generate
        for (out_p = 0; out_p < PORT_COUNT; out_p = out_p + 1) begin: sw_req_gen
            for (in_p = 0; in_p < PORT_COUNT; in_p = in_p + 1) begin: in_port_sw
                for (vv = 0; vv < VC_COUNT; vv = vv + 1) begin: vc_sw
                    assign sw_req[out_p][in_p * VC_COUNT + vv] =
                        vc_alloc_grant[in_p][vv] &&
                        vc_buf_valid[in_p][vv] &&
                        (route_out_port[in_p][vv] == out_p);
                end
            end
        end
    endgenerate

    // Switch allocators
    generate
        for (p = 0; p < PORT_COUNT; p = p + 1) begin: sw_allocators
            nl_router_switch_allocator #(
                .NUM_INPUTS(PORT_COUNT * VC_COUNT),
                .NUM_OUTPUTS(1)
            ) sw_alloc (
                .req(sw_req[p]),
                .prior({PORT_COUNT * VC_COUNT{1'b1}}),
                .clk(clk),
                .rst_n(rst_n),
                .grant(sw_grant[p])
            );
        end
    endgenerate

    // Crossbar
    nl_router_crossbar_switch #(
        .DATA_WIDTH(DATA_WIDTH),
        .VC_COUNT(VC_COUNT),
        .PORT_COUNT(PORT_COUNT)
    ) crossbar (
        .pkt_valid_in(crossbar_valid_in), // <--- NOW CONNECTED
        .grant(sw_grant),
        .pkt_data_in(crossbar_data_in),
        .pkt_data_out(crossbar_out_data),
        .pkt_valid_out(crossbar_out_valid)
    );

    // Output ports
    generate
        for (p = 0; p < PORT_COUNT; p = p + 1) begin: output_ports
            nl_router_output_port #(
                .DATA_WIDTH(DATA_WIDTH),
                .FIFO_DEPTH(FIFO_DEPTH)
            ) out_port (
                .clk(clk),
                .rst_n(rst_n),
                .in_valid(crossbar_out_valid[p]),
                .in_data(crossbar_out_data[p]),
                .in_ready(), // Not used
                .out_valid(out_valid[p]),
                .out_data(out_data[p]),
                .out_ready(out_ready[p])
            );
        end
    endgenerate

    // Input ready = any VC buffer has space
    generate
        for (p = 0; p < PORT_COUNT; p = p + 1) begin: in_ready_gen
            assign in_ready[p] = |vc_buf_in_ready[p];
        end
    endgenerate

endmodule