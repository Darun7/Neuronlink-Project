`timescale 1ns/1ps

module nl_router_switch_allocator #(
    parameter NUM_INPUTS = 4,
    parameter NUM_OUTPUTS = 4
)(
    input  wire [NUM_INPUTS-1:0] req,
    input  wire [NUM_INPUTS-1:0] prior,
    input  wire clk,
    input  wire rst_n,
    output reg  [NUM_INPUTS-1:0] grant
);

    integer i, idx;
    reg [$clog2(NUM_INPUTS)-1:0] rr_idx; // Round-robin pointer

    reg [NUM_INPUTS-1:0] candidate;
    reg granted_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant   <= 0;
            rr_idx  <= 0;
        end else begin
            // Priority mask
            if ((req & prior) != 0)
                candidate = req & prior;
            else
                candidate = req & ~prior;

            grant = 0;
            granted_flag = 0;

            // Round-robin
            for (i = 0; i < NUM_INPUTS; i = i + 1) begin
                idx = (rr_idx + i) % NUM_INPUTS;
                if (!granted_flag && candidate[idx]) begin
                    grant[idx] = 1'b1;
                    granted_flag = 1'b1;
                    rr_idx = (idx + 1) % NUM_INPUTS;
                end
            end

            if (!granted_flag)
                grant = 0;
        end
    end

endmodule