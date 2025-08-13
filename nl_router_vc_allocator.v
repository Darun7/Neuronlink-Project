`timescale 1ns / 1ps

module nl_router_vc_allocator #(
    parameter NUM_VC = 4,
    parameter SCORE_WIDTH = 8
)(
    input  wire [NUM_VC-1:0] req,
    input  wire [NUM_VC-1:0] intercept,
    input  wire [NUM_VC*SCORE_WIDTH-1:0] score,  // concatenated scores per VC
    output reg  [NUM_VC-1:0] grant
);

    integer i;
    reg [SCORE_WIDTH-1:0] max_score;
    reg [NUM_VC-1:0] req_masked;
    reg [NUM_VC-1:0] grant_temp;

    always @(*) begin
        grant = 0;
        max_score = 0;
        req_masked = req & ~intercept;
        grant_temp = 0;

        // Find the VC with the highest score, tie-breaker: lowest index wins
        for (i = 0; i < NUM_VC; i = i + 1) begin
            if (req_masked[i]) begin
                if ((grant_temp == 0) || (score[i*SCORE_WIDTH +: SCORE_WIDTH] > max_score)) begin
                    max_score = score[i*SCORE_WIDTH +: SCORE_WIDTH];
                    grant_temp = 0;
                    grant_temp[i] = 1;
                end
            end
        end
        grant = grant_temp;
    end

endmodule