module nc_rx_dll_buffer #(
    parameter DATA_WIDTH = 64,
    parameter DEPTH = 8
)(
    input wire clk,
    input wire rst,

    // Input from Physical Layer
    input wire [DATA_WIDTH-1:0] data_in,
    input wire data_valid,

    // Output to DLL
    output reg [DATA_WIDTH-1:0] data_out,
    output reg data_ready
);

    reg [DATA_WIDTH-1:0] buffer [0:DEPTH-1];
    reg [$clog2(DEPTH):0] wr_ptr = 0;
    reg [$clog2(DEPTH):0] rd_ptr = 0;
    reg [$clog2(DEPTH)+1:0] count = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
            data_out <= 0;
            data_ready <= 0;
        end else begin
            // Write data from PL
            if (data_valid && count < DEPTH) begin
                buffer[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end

            // Output data to DLL
            if (count > 0) begin
                data_out <= buffer[rd_ptr];
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
                data_ready <= 1;
            end else begin
                data_ready <= 0;
            end
        end
    end

endmodule
