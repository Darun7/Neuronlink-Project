`timescale 1ns / 1ps

module nc_tx_pl_gearbox #(
    parameter IN_WIDTH = 80,
    parameter OUT_WIDTH = 20,
    parameter NUM_CHUNKS = IN_WIDTH / OUT_WIDTH
)(
    input  wire                   clk,
    input  wire                   rst_n,

    // Input interface (from encoder/scrambler)
    input  wire                   valid_in,
    input  wire [IN_WIDTH-1:0]    data_in,
    output reg                    ready_in,

    // Output interface (to serializer)
    output reg                    valid_out,
    output reg [OUT_WIDTH-1:0]    data_out,
    input  wire                   ready_out
);

    reg [IN_WIDTH-1:0] data_reg;
    reg [$clog2(NUM_CHUNKS)-1:0] chunk_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 0;
            chunk_counter <= 0;
            valid_out <= 0;
            ready_in <= 1;
            data_out <= 0;
        end else begin
            if (ready_in && valid_in) begin
                // Accept new data
                data_reg <= data_in;
                chunk_counter <= 0;
                valid_out <= 1;
                ready_in <= 0;
                data_out <= data_in[IN_WIDTH-1 -: OUT_WIDTH];
            end else if (valid_out && ready_out) begin
                if (chunk_counter == NUM_CHUNKS - 1) begin
                    // Last chunk sent, ready for new data
                    valid_out <= 0;
                    ready_in <= 1;
                end else begin
                    chunk_counter <= chunk_counter + 1;
                    data_out <= data_reg[IN_WIDTH - 1 - OUT_WIDTH*(chunk_counter+1) -: OUT_WIDTH];
                end
            end
        end
    end

endmodule