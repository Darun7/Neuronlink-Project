module nl_router_weight_comp #(
    parameter NUM_PORTS = 5,
    parameter NUM_VCS   = 4,
    parameter WIDTH     = 8,
    parameter AGE_WEIGHT  = 1,
    parameter CONG_WEIGHT = 2
)(
    input  wire [WIDTH-1:0] age_matrix [NUM_PORTS-1:0][NUM_VCS-1:0],
    input  wire [WIDTH-1:0] congestion_matrix [NUM_PORTS-1:0][NUM_VCS-1:0],
    input  wire req_matrix [NUM_PORTS-1:0][NUM_VCS-1:0],
    output reg  signed [WIDTH-1:0] score_matrix_flat [NUM_PORTS * NUM_VCS - 1 : 0]
);
    genvar p, v;
    generate
        for (p = 0; p < NUM_PORTS; p = p + 1) begin : port_loop
            for (v = 0; v < NUM_VCS; v = v + 1) begin : vc_loop
                always @(*) begin
                    if (req_matrix[p][v]) begin
                        score_matrix_flat[p * NUM_VCS + v] = 
                            (AGE_WEIGHT * $signed(age_matrix[p][v])) -
                            (CONG_WEIGHT * $signed(congestion_matrix[p][v]));
                    end else begin
                        score_matrix_flat[p * NUM_VCS + v] = 0;
                    end
                end
            end
        end
    endgenerate
endmodule