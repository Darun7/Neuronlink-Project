`timescale 1ns/1ps

module noc_mesh_top #(
    parameter DATA_WIDTH = 32,
    parameter VC_COUNT   = 4,
    parameter VC_DEPTH   = 4,
    parameter PORT_COUNT = 5, // N/E/S/W/Local
    parameter FIFO_DEPTH = 4,
    parameter MESH_X     = 4,
    parameter MESH_Y     = 4
)(
    input  wire clk,
    input  wire rst_n,
    // Local injection/ejection interfaces for every tile (flattened)
    input  wire [MESH_X*MESH_Y*DATA_WIDTH-1:0] inj_local,
    input  wire [MESH_X*MESH_Y-1:0]            valid_local,
    output wire [MESH_X*MESH_Y-1:0]            ready_local,
    output wire [MESH_X*MESH_Y*DATA_WIDTH-1:0] eject_local,
    output wire [MESH_X*MESH_Y-1:0]            valid_out_local,
    input  wire [MESH_X*MESH_Y-1:0]            ready_out_local
);

    // Internal unpacked arrays for mesh
    wire [DATA_WIDTH-1:0] inj_local_arr    [MESH_X-1:0][MESH_Y-1:0];
    wire                  valid_local_arr  [MESH_X-1:0][MESH_Y-1:0];
    wire                  ready_local_arr  [MESH_X-1:0][MESH_Y-1:0];
    wire [DATA_WIDTH-1:0] eject_local_arr  [MESH_X-1:0][MESH_Y-1:0];
    wire                  valid_out_local_arr [MESH_X-1:0][MESH_Y-1:0];
    wire                  ready_out_local_arr [MESH_X-1:0][MESH_Y-1:0];

    // Flattened to unpacked
    genvar xi, yi;
    generate
        for (xi = 0; xi < MESH_X; xi = xi + 1) begin: FLAT_X
            for (yi = 0; yi < MESH_Y; yi = yi + 1) begin: FLAT_Y
                localparam int idx = xi*MESH_Y+yi;
                assign inj_local_arr[xi][yi]     = inj_local[(idx+1)*DATA_WIDTH-1:idx*DATA_WIDTH];
                assign valid_local_arr[xi][yi]   = valid_local[idx];
                assign ready_out_local_arr[xi][yi]= ready_out_local[idx];
                assign ready_local[idx]          = ready_local_arr[xi][yi];
                assign eject_local[(idx+1)*DATA_WIDTH-1:idx*DATA_WIDTH] = eject_local_arr[xi][yi];
                assign valid_out_local[idx]      = valid_out_local_arr[xi][yi];
            end
        end
    endgenerate

    // Internal mesh links (N/E/S/W) with boundaries
    wire [DATA_WIDTH-1:0] link_north_south_data [MESH_X-1:0][MESH_Y:0];
    wire [DATA_WIDTH-1:0] link_east_west_data  [MESH_X:0][MESH_Y-1:0];
    wire                  link_north_south_valid [MESH_X-1:0][MESH_Y:0];
    wire                  link_east_west_valid  [MESH_X:0][MESH_Y-1:0];
    wire                  link_north_south_ready [MESH_X-1:0][MESH_Y:0];
    wire                  link_east_west_ready  [MESH_X:0][MESH_Y-1:0];

    genvar x, y;
    generate
        for (x = 0; x < MESH_X; x = x + 1) begin : gen_x
            for (y = 0; y < MESH_Y; y = y + 1) begin : gen_y
                // Declarations for packed <-> unpacked conversion
                wire [PORT_COUNT-1:0]        in_valid;
                wire [PORT_COUNT-1:0][DATA_WIDTH-1:0] in_data;
                wire [PORT_COUNT-1:0]        in_ready;
                wire [PORT_COUNT-1:0]        out_valid;
                wire [PORT_COUNT-1:0][DATA_WIDTH-1:0] out_data;
                wire [PORT_COUNT-1:0]        out_ready;

                // NORTH
                assign in_valid[0] = (y == 0) ? 1'b0 : link_north_south_valid[x][y];
                assign in_data [0] = (y == 0) ? {DATA_WIDTH{1'b0}} : link_north_south_data[x][y];
                assign out_ready[0]= (y == 0) ? 1'b0 : link_north_south_ready[x][y];

                // EAST
                assign in_valid[1] = (x == MESH_X-1) ? 1'b0 : link_east_west_valid[x+1][y];
                assign in_data [1] = (x == MESH_X-1) ? {DATA_WIDTH{1'b0}} : link_east_west_data[x+1][y];
                assign out_ready[1]= (x == MESH_X-1) ? 1'b0 : link_east_west_ready[x+1][y];

                // SOUTH
                assign in_valid[2] = (y == MESH_Y-1) ? 1'b0 : link_north_south_valid[x][y+1];
                assign in_data [2] = (y == MESH_Y-1) ? {DATA_WIDTH{1'b0}} : link_north_south_data[x][y+1];
                assign out_ready[2]= (y == MESH_Y-1) ? 1'b0 : link_north_south_ready[x][y+1];

                // WEST
                assign in_valid[3] = (x == 0) ? 1'b0 : link_east_west_valid[x][y];
                assign in_data [3] = (x == 0) ? {DATA_WIDTH{1'b0}} : link_east_west_data[x][y];
                assign out_ready[3]= (x == 0) ? 1'b0 : link_east_west_ready[x][y];

                // LOCAL
                assign in_valid[4] = valid_local_arr[x][y];
                assign in_data [4] = inj_local_arr[x][y];
                assign out_ready[4]= ready_out_local_arr[x][y];

                assign ready_local_arr[x][y]     = in_ready[4];
                assign eject_local_arr[x][y]     = out_data[4];
                assign valid_out_local_arr[x][y] = out_valid[4];

                // Outputs to mesh links
                assign link_north_south_data[x][y] = out_data[0];
                assign link_north_south_valid[x][y]= out_valid[0];
                assign link_north_south_ready[x][y]= in_ready[0];

                assign link_east_west_data[x][y]   = out_data[3];
                assign link_east_west_valid[x][y]  = out_valid[3];
                assign link_east_west_ready[x][y]  = in_ready[3];

                // Cast x, y to correct bit width for router parameters (important for 4x4+ mesh)
                neuronlink_router #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .VC_COUNT(VC_COUNT),
                    .VC_DEPTH(VC_DEPTH),
                    .PORT_COUNT(PORT_COUNT),
                    .FIFO_DEPTH(FIFO_DEPTH),
                    .ROUTER_X(x[1:0]),
                    .ROUTER_Y(y[1:0])
                ) router_inst (
                    .clk(clk),
                    .rst_n(rst_n),
                    .in_valid(in_valid),
                    .in_data(in_data),
                    .in_ready(in_ready),
                    .out_valid(out_valid),
                    .out_data(out_data),
                    .out_ready(out_ready)
                );
            end
        end
    endgenerate

endmodule