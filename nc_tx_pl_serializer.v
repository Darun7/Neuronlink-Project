`timescale 1ns / 1ps

module nc_tx_pl_serializer #(
    parameter DATA_WIDTH = 20
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             valid_in,
    input  wire [DATA_WIDTH-1:0] data_in,
    output reg              busy,          // Serializer busy output
    output reg              serial_out     // Serial output bitstream (to TX+ / TX- differential pair)
);

    reg [DATA_WIDTH-1:0] shift_reg;
    reg [$clog2(DATA_WIDTH):0] bit_cnt;  // Counter up to DATA_WIDTH

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            serial_out <= 0;
        end else begin
            if (!busy && valid_in) begin
                // Load new parallel data into shift register
                shift_reg <= data_in;
                bit_cnt <= 0;
                busy <= 1;
                serial_out <= data_in[DATA_WIDTH-1]; // MSB first
            end else if (busy) begin
                // Shift out bits one by one MSB first
                if (bit_cnt < DATA_WIDTH-1) begin
                    bit_cnt <= bit_cnt + 1;
                    shift_reg <= {shift_reg[DATA_WIDTH-2:0], 1'b0};
                    serial_out <= shift_reg[DATA_WIDTH-2];
                end else begin
                    // Finished sending current word
                    busy <= 0;
                    bit_cnt <= 0;
                    serial_out <= 0;
                end
            end else begin
                // Idle state
                serial_out <= 0;
            end
        end
    end

endmodule
