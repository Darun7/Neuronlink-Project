module nc_rx_pl_cmd_if (
    input logic         clk,
    input logic         rst,
    input logic [63:0]  data_in,
    input logic         valid_in,

    output logic [31:0] cmd_out,
    output logic        valid_cmd_out
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cmd_out       <= 0;
            valid_cmd_out <= 0;
        end else begin
            if (valid_in && data_in[63:56] == 8'hAA) begin // 0xAA is command header
                cmd_out       <= data_in[31:0];
                valid_cmd_out <= 1;
            end else begin
                valid_cmd_out <= 0;
            end
        end
    end
endmodule
