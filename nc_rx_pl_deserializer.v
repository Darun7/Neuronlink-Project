`timescale 1ns / 1ps

module nc_rx_pl_deserializer #(
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire rx_p,
    input wire rx_n,
    output reg [DATA_WIDTH-1:0] parallel_data,
    output reg data_valid
);

    reg [DATA_WIDTH-1:0] shift_reg = 0;
    reg [3:0] bit_count = 0;

    wire serial_data = (rx_p == 1'b1 && rx_n == 1'b0) ? 1'b1 : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 0;
            bit_count <= 0;
            parallel_data <= 0;
            data_valid <= 0;
        end else begin
            data_valid <= 0;
            shift_reg <= {shift_reg[DATA_WIDTH-2:0], serial_data};
            if (bit_count == DATA_WIDTH-1) begin
                parallel_data <= {shift_reg[DATA_WIDTH-2:0], serial_data};
                data_valid <= 1;
                bit_count <= 0;
            end else begin
                bit_count <= bit_count + 1;
            end
        end
    end

endmodule