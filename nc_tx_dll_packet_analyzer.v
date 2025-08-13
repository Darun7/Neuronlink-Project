`timescale 1ns / 1ps

module nc_tx_dll_packet_analyzer(
    input  wire         clk,
    input  wire         rst_n,
    input  wire         valid_in,
    input  wire         ready_in,        // handshake: downstream ready
    input  wire [63:0]  packet_in,
    output reg  [3:0]   packet_priority,
    output reg          multicast,
    output reg  [8:0]   dest_addr,
    output reg          valid_out
);

    // Hold output until downstream ready
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_priority <= 4'b0;
            multicast       <= 1'b0;
            dest_addr       <= 9'b0;
            valid_out       <= 1'b0;
        end else if (~valid_out || ready_in) begin
            valid_out       <= valid_in;
            if (valid_in) begin
                packet_priority <= packet_in[63:60];
                multicast       <= packet_in[59];
                dest_addr       <= packet_in[58:50];
            end
        end
    end

endmodule