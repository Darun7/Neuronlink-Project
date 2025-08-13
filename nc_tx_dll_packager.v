`timescale 1ns / 1ps

module nc_tx_dll_packager (
    input  wire         clk,
    input  wire         rst_n,

    // VC buffer inputs
    input  wire         vc0_valid,
    input  wire [63:0]  vc0_data,
    input  wire         vc1_valid,
    input  wire [63:0]  vc1_data,
    input  wire         vc2_valid,
    input  wire [63:0]  vc2_data,
    input  wire         vc3_valid,
    input  wire [63:0]  vc3_data,

    // Retry buffer input
    input  wire         retry_valid,
    input  wire [63:0]  retry_data,

    // Pipeline handshake
    input  wire         ready_in,  // from downstream
    output wire         valid_out,
    output wire [63:0]  data_out
);

    reg valid_reg;
    reg [63:0] data_reg;

    wire mux_valid;
    reg [63:0] mux_data;
    assign mux_valid = retry_valid | vc0_valid | vc1_valid | vc2_valid | vc3_valid;

    always @(*) begin
        if (retry_valid)
            mux_data = retry_data;
        else if (vc0_valid)
            mux_data = vc0_data;
        else if (vc1_valid)
            mux_data = vc1_data;
        else if (vc2_valid)
            mux_data = vc2_data;
        else if (vc3_valid)
            mux_data = vc3_data;
        else
            mux_data = 64'd0;
    end

    wire ready_out;
    assign ready_out = ~valid_reg || ready_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_reg <= 1'b0;
            data_reg  <= 64'd0;
        end else if (ready_out) begin
            valid_reg <= mux_valid;
            data_reg  <= mux_data;
        end
    end

    assign valid_out = valid_reg;
    assign data_out  = data_reg;

endmodule