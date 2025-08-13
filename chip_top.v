`timescale 1ns / 1ps

module chip_top #(
    parameter MESH_X = 4,
    parameter MESH_Y = 4,
    parameter DATA_WIDTH = 32,
    parameter VC_COUNT = 4,
    parameter VC_DEPTH = 4,
    parameter PORT_COUNT = 5,
    parameter FIFO_DEPTH = 4,
    parameter PN_ADDR_WIDTH = 8,
    parameter PN_DATA_WIDTH = 32,
    parameter IO_BRIDGE_DATA_WIDTH = 64,
    parameter IO_BRIDGE_ADDR_WIDTH = 4
)(
    input  wire clk,
    input  wire rst_n,

    // IO Bridge PCIe
    input  wire [IO_BRIDGE_DATA_WIDTH-1:0] pcie_rx_data,
    input  wire                            pcie_rx_valid,
    output wire                            pcie_rx_ready,
    output wire [IO_BRIDGE_DATA_WIDTH-1:0] pcie_tx_data,
    output wire                            pcie_tx_valid,
    input  wire                            pcie_tx_ready,

    // NeuronLink-C
    input  wire                            rx_p,
    input  wire                            rx_n,
    output wire                            tx_serial_out
);

    // -------- Local Mesh <-> Nodes/IO flattening --------
    wire [MESH_X*MESH_Y*DATA_WIDTH-1:0] inj_local;
    wire [MESH_X*MESH_Y-1:0]            valid_local;
    wire [MESH_X*MESH_Y-1:0]            ready_local;
    wire [MESH_X*MESH_Y*DATA_WIDTH-1:0] eject_local;
    wire [MESH_X*MESH_Y-1:0]            valid_out_local;
    wire [MESH_X*MESH_Y-1:0]            ready_out_local;

    // -------- Processing Nodes (placeholders for user logic connection) --------
    genvar px, py;
    generate
        for (px = 0; px < MESH_X; px = px + 1) begin: gen_pn_x
            for (py = 0; py < MESH_Y; py = py + 1) begin: gen_pn_y
                localparam int idx = px*MESH_Y + py;
                processing_node #(
                    .ADDR_WIDTH(PN_ADDR_WIDTH),
                    .DATA_WIDTH(PN_DATA_WIDTH)
                ) u_pn (
                    .clk(clk),
                    .rst_n(rst_n)
                    // Extend here to connect mesh tile IO to node, if needed
                    // Example: connect inj_local, valid_local, etc. to local node logic
                );
            end
        end
    endgenerate

    // -------- NoC Mesh Top --------
    noc_mesh_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .VC_COUNT(VC_COUNT),
        .VC_DEPTH(VC_DEPTH),
        .PORT_COUNT(PORT_COUNT),
        .FIFO_DEPTH(FIFO_DEPTH),
        .MESH_X(MESH_X),
        .MESH_Y(MESH_Y)
    ) u_noc_mesh (
        .clk(clk),
        .rst_n(rst_n),
        .inj_local(inj_local),
        .valid_local(valid_local),
        .ready_local(ready_local),
        .eject_local(eject_local),
        .valid_out_local(valid_out_local),
        .ready_out_local(ready_out_local)
    );

    // -------- IO Bridge <-> Mesh tile [0][0] example --------
    io_bridge #(
        .DATA_WIDTH(IO_BRIDGE_DATA_WIDTH),
        .ADDR_WIDTH(IO_BRIDGE_ADDR_WIDTH)
    ) u_io_bridge (
        .clk(clk),
        .rst_n(rst_n),
        .pcie_rx_data(pcie_rx_data),
        .pcie_rx_valid(pcie_rx_valid),
        .pcie_rx_ready(pcie_rx_ready),
        .pcie_tx_data(pcie_tx_data),
        .pcie_tx_valid(pcie_tx_valid),
        .pcie_tx_ready(pcie_tx_ready),

        // Connect the IO bridge to mesh tile [0][0] local port
        .noc_in_valid(valid_local[0]),
        .noc_in_data(inj_local[DATA_WIDTH-1:0]),
        .noc_in_ready(ready_local[0]),
        .noc_out_data(eject_local[DATA_WIDTH-1:0]),
        .noc_out_valid(valid_out_local[0]),
        .noc_out_ready(ready_out_local[0]),

        .rx_p(rx_p),
        .rx_n(rx_n),
        .tx_serial_out(tx_serial_out)
    );

    // NOTE: 
    // - To connect IO bridge to a different tile, change the index [0].
    // - To connect nodes for data injection/ejection, assign their signals to inj_local, valid_local, etc.

endmodule