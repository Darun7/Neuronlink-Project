`timescale 1ns / 1ps

module nl_router_crossbar_switch #(
    parameter DATA_WIDTH = 32,
    parameter VC_COUNT   = 2,
    parameter PORT_COUNT = 3
)(
    input  wire [PORT_COUNT-1:0][VC_COUNT-1:0][DATA_WIDTH-1:0] pkt_data_in,
    input  wire [PORT_COUNT-1:0][VC_COUNT-1:0]                 pkt_valid_in,
    input  wire [PORT_COUNT-1:0][PORT_COUNT*VC_COUNT-1:0]      grant, // grant[out_port][in_port*VC_COUNT+vc]
    output reg  [PORT_COUNT-1:0][DATA_WIDTH-1:0]               pkt_data_out,
    output reg  [PORT_COUNT-1:0]                               pkt_valid_out
);

    integer out_port, in_port, vc;
    integer found;

    always @(*) begin
        for (out_port = 0; out_port < PORT_COUNT; out_port = out_port + 1) begin
            pkt_data_out[out_port]  = {DATA_WIDTH{1'b0}};
            pkt_valid_out[out_port] = 1'b0;
            found = 0;
            for (in_port = 0; in_port < PORT_COUNT; in_port = in_port + 1) begin
                for (vc = 0; vc < VC_COUNT; vc = vc + 1) begin
                    if (!found && grant[out_port][in_port*VC_COUNT + vc]) begin
                        pkt_data_out[out_port]  = pkt_data_in[in_port][vc];
                        pkt_valid_out[out_port] = pkt_valid_in[in_port][vc];
                        found = 1;
                    end
                end
            end
        end
    end

endmodule