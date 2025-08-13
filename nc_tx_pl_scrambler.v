`timescale 1ns / 1ps

module nc_tx_pl_scrambler #(
    parameter DATA_WIDTH = 80
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire                   ready_in,
    input  wire [DATA_WIDTH-1:0]  data_in,
    output wire                   valid_out,
    output wire [DATA_WIDTH-1:0]  data_out
);

    reg valid_reg;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [6:0] scrambler_reg;

    integer i;
    reg [6:0] scrambler_next;
    reg [DATA_WIDTH-1:0] scrambled_data;
    reg scr_bit;

    wire ready_out;
    assign ready_out = ~valid_reg || ready_in;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scrambler_reg <= 7'b1111111;
            valid_reg     <= 1'b0;
            data_reg      <= {DATA_WIDTH{1'b0}};
        end else if (ready_out) begin
            if (valid_in) begin
                scrambled_data[DATA_WIDTH-1 -:16] = data_in[DATA_WIDTH-1 -:16];
                scrambler_next = scrambler_reg;
                for (i = DATA_WIDTH-17; i >= 0; i = i - 1) begin
                    scr_bit = scrambler_next[6] ^ scrambler_next[5] ^ data_in[i];
                    scrambled_data[i] = scr_bit;
                    scrambler_next = {scrambler_next[5:0], scr_bit};
                end
                data_reg      <= scrambled_data;
                scrambler_reg <= scrambler_next;
                valid_reg     <= 1'b1;
            end else begin
                valid_reg <= 1'b0;
                data_reg  <= {DATA_WIDTH{1'b0}};
                scrambler_reg <= scrambler_reg;
            end
        end
    end

    assign valid_out = valid_reg;
    assign data_out  = data_reg;

endmodule