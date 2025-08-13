`timescale 1ns / 1ps

module nl_router_route_comp #(
    parameter ROUTER_X = 0,
    parameter ROUTER_Y = 0
)(
    input  wire [7:0] header,   // Packet header
    output reg  [2:0] out_port  // 3 bits for 5 ports
);

    localparam DIR_NORTH = 3'd0;
    localparam DIR_EAST  = 3'd1;
    localparam DIR_SOUTH = 3'd2;
    localparam DIR_WEST  = 3'd3;
    localparam DIR_LOCAL = 3'd4;

    // Extract destination coordinates from header
    wire [2:0] dest_x, dest_y;
    assign dest_x = header[6:4];
    assign dest_y = header[3:1];

    // Use Odd-Even Routing Algorithm for ALL packets (unicast & multicast)
    always @(*) begin
        if (ROUTER_X == dest_x && ROUTER_Y == dest_y) begin
            out_port = DIR_LOCAL;
        end else if (ROUTER_X != dest_x) begin
            if (ROUTER_X < dest_x) begin
                // EAST preferred
                if (!(ROUTER_X[0] == 1'b1 && ROUTER_Y != dest_y))
                    out_port = DIR_EAST;
                else
                    out_port = (ROUTER_Y < dest_y) ? DIR_SOUTH : DIR_NORTH;
            end else begin
                // WEST preferred
                if (!(ROUTER_X[0] == 1'b0 && ROUTER_Y != dest_y))
                    out_port = DIR_WEST;
                else
                    out_port = (ROUTER_Y < dest_y) ? DIR_SOUTH : DIR_NORTH;
            end
        end else begin
            out_port = (ROUTER_Y < dest_y) ? DIR_SOUTH : DIR_NORTH;
        end
    end

endmodule