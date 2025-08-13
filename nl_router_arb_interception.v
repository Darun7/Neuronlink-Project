`timescale 1ns / 1ps

module nl_router_arb_interception #(
    parameter NUM_VC = 4  // Number of VCs per input port
)(
    input  wire [NUM_VC-1:0] req,      // Request signals from VCs
    input  wire [NUM_VC-1:0] grant,    // Grant signals from crossbar arb
    output reg  [NUM_VC-1:0] intercept // Interception signals back to VC allocator
);

    integer i, j;
    reg high_pri_req_pending;

    always @(*) begin
        intercept = 0;
        // For each VC, check if there is any higher-priority VC requesting but not granted
        for (i = 0; i < NUM_VC; i = i + 1) begin
            if (req[i] && !grant[i]) begin
                // Check if any higher priority VC has a request (priority = lower index means higher priority)
                high_pri_req_pending = 0;
                for (j = 0; j < i; j = j + 1) begin
                    if (req[j] && !grant[j]) begin
                        high_pri_req_pending = 1;
                    end
                end

                // If higher priority VC(s) requested but not granted,
                // intercept current VC's arbitration
                if (high_pri_req_pending)
                    intercept[i] = 1;
                else
                    intercept[i] = 0;
            end else begin
                intercept[i] = 0;
            end
        end
    end

endmodule