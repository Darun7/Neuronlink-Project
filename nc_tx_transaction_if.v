`timescale 1ns / 1ps

module nc_tx_transaction_if #(
    parameter DATA_WIDTH = 64,   // Width of the packet data
    parameter ACK_WIDTH  = 4     // 4-bit acknowledge signal width
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Inputs from NoC (Transaction Layer)
    input  wire [DATA_WIDTH-1:0]  pkt_data_in,
    input  wire                   pkt_req_in,
    output reg                    pkt_ack_out,   // Ack back to NoC (1 bit for handshake)

    // Outputs to DLL (Data Link Layer)
    output reg  [DATA_WIDTH-1:0]  dll_data_out,
    output reg                    dll_valid_out,
    input  wire [ACK_WIDTH-1:0]   dll_ack_in    // 4-bit DLL acknowledge signals
);

    // State machine states for handshaking
    localparam IDLE    = 1'b0;
    localparam SEND    = 1'b1;

    reg state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            dll_valid_out <= 0;
            pkt_ack_out <= 0;
            dll_data_out <= 0;
        end else begin
            case (state)
                IDLE: begin
                    dll_valid_out <= 0;
                    pkt_ack_out <= 0;
                    if (pkt_req_in) begin
                        dll_data_out <= pkt_data_in;
                        dll_valid_out <= 1;
                        pkt_ack_out <= 1;  // Acknowledge receipt to NoC
                        state <= SEND;
                    end
                end

                SEND: begin
                    // Wait for DLL to acknowledge all bits (all 4 bits asserted)
                    if (&dll_ack_in) begin
                        dll_valid_out <= 0;
                        pkt_ack_out <= 0;
                        state <= IDLE;
                    end else begin
                        // Keep valid asserted until DLL fully acknowledges
                        dll_valid_out <= 1;
                        pkt_ack_out <= 1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule