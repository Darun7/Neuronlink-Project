`timescale 1ns / 1ps

module nl_router_score_comp #(
    parameter NUM_PORTS = 5,
    parameter SCORE_WIDTH = 8
)(
    input  wire [SCORE_WIDTH-1:0] scores [NUM_PORTS-1:0],
    output reg  [$clog2(NUM_PORTS)-1:0] grant
);

    integer i;
    reg [SCORE_WIDTH-1:0] max_score;
    reg [$clog2(NUM_PORTS)-1:0] max_index;

    always @(*) begin
        max_score = scores[0];
        max_index = 0;
        for (i = 1; i < NUM_PORTS; i = i + 1) begin
            if (scores[i] > max_score) begin
                max_score = scores[i];
                max_index = i[$clog2(NUM_PORTS)-1:0];
            end
        end
        grant = max_index;
    end

endmodule
