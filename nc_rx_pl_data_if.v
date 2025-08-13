module nc_rx_pl_data_if (
    input logic         clk,
    input logic         rst,
    input logic [63:0]  data_in,
    input logic         valid_in,

    output logic [31:0] data_out,
    output logic        valid_data_out
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out       <= 0;
            valid_data_out <= 0;
        end else begin
            if (valid_in && data_in[63:56] == 8'h55) begin // 0x55 is data header
                data_out       <= data_in[31:0];
                valid_data_out <= 1;
            end else begin
                valid_data_out <= 0;
            end
        end
    end
endmodule