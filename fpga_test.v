`timescale 1ns / 1ps

module top_vc_input_buffer_fpga (
    input wire clk,         // 100 MHz from Basys 3
    input wire btnC,        // Center button for reset
    input wire [3:0] sw,    // Switches: [0]:pkt_valid, [2:1]: VC select, [3]:rc_ready
    output wire [15:0] led  // View debug info on LEDs
);

    // Reset and signal wires
    wire rst_n       = btnC;
    wire pkt_valid   = sw[0];
    wire [1:0] vc_select = sw[2:1];
    wire rc_ready    = sw[3];

    // Compose packet: [31:30] = VC ID, [29:0] = dummy data
    wire [31:0] pkt_data = {vc_select, 30'h12345678};

    wire rc_valid;
    wire [31:0] rc_header_out;

    // Instantiate your VC input buffer (DUT)
    nl_router_vc_input_buffer #(
        .DATA_WIDTH(32),
        .VC_COUNT(4),
        .VC_DEPTH(4)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .pkt_valid(pkt_valid),
        .pkt_data(pkt_data),
        .rc_ready(rc_ready),
        .rc_valid(rc_valid),
        .rc_header_out(rc_header_out)
    );

    // Display outputs using LEDs
    assign led[0]   = rc_valid;
    assign led[1]   = rc_ready;
    assign led[3:2] = vc_select;
    assign led[7:4] = rc_header_out[3:0]; // Lower nibble of header

    // ILA instance (generated via IP Catalog in Vivado)
    ila_1 ila_inst (
        .clk(clk),
        .probe0(pkt_valid),       // 1-bit
        .probe1(pkt_data),        // 32-bit
        .probe2(rc_ready),        // 1-bit
        .probe3(rc_valid),        // 1-bit
        .probe4(rc_header_out)    // 32-bit
    );

endmodule
