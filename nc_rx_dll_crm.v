`timescale 1ns / 1ps

module nc_rx_dll_crm #(
    parameter DATA_WIDTH = 64,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = 4  // log2(FIFO_DEPTH)
)(
    input wire clk,
    input wire rst_n,

    // From Physical Layer Decoder
    input wire retransmit_req,

    // Input data from DLL buffer
    input wire valid_in,
    input wire [DATA_WIDTH-1:0] data_in,
    input wire [1:0] vc_id_in,  // VC id for incoming data

    // Control signals to VC buffers
    output reg vc0_rd_en,
    output reg vc1_rd_en,
    output reg vc2_rd_en,
    output reg vc3_rd_en,

    // Output data and control to VC buffers
    output reg valid_out,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg [1:0] vc_id_out,

    // Retry command output
    output reg retry_cmd,

    // Local credit counts per VC
    output reg [ADDR_WIDTH:0] vc0_credit,
    output reg [ADDR_WIDTH:0] vc1_credit,
    output reg [ADDR_WIDTH:0] vc2_credit,
    output reg [ADDR_WIDTH:0] vc3_credit,

    // Credit upgrade command outputs (to TX side)
    output reg credit_upd_vc0,
    output reg credit_upd_vc1,
    output reg credit_upd_vc2,
    output reg credit_upd_vc3
);

    // States for retry handling
    typedef enum logic [1:0] {
        NORMAL,
        RETRY_WAIT,
        RETRY_ACTIVE
    } retry_state_t;

    retry_state_t retry_state, next_retry_state;

    // Credit counters initialized to FIFO_DEPTH
    localparam MAX_CREDIT = FIFO_DEPTH;

    // Internal counters for credits, initialized elsewhere or on reset
    reg [ADDR_WIDTH:0] credit_count [0:3]; // for VC0 to VC3

    // Assign credit outputs from internal registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            credit_count[0] <= MAX_CREDIT;
            credit_count[1] <= MAX_CREDIT;
            credit_count[2] <= MAX_CREDIT;
            credit_count[3] <= MAX_CREDIT;

            vc0_credit <= MAX_CREDIT;
            vc1_credit <= MAX_CREDIT;
            vc2_credit <= MAX_CREDIT;
            vc3_credit <= MAX_CREDIT;

            retry_state <= NORMAL;

            retry_cmd <= 0;

            // Clear outputs
            vc0_rd_en <= 0;
            vc1_rd_en <= 0;
            vc2_rd_en <= 0;
            vc3_rd_en <= 0;

            valid_out <= 0;
            data_out <= 0;
            vc_id_out <= 0;

            credit_upd_vc0 <= 0;
            credit_upd_vc1 <= 0;
            credit_upd_vc2 <= 0;
            credit_upd_vc3 <= 0;
        end else begin
            retry_state <= next_retry_state;

            // Update credit outputs from internal
            vc0_credit <= credit_count[0];
            vc1_credit <= credit_count[1];
            vc2_credit <= credit_count[2];
            vc3_credit <= credit_count[3];

            retry_cmd <= 0;  // default no retry command

            credit_upd_vc0 <= 0;
            credit_upd_vc1 <= 0;
            credit_upd_vc2 <= 0;
            credit_upd_vc3 <= 0;

            // Retry state machine
            case (retry_state)
                NORMAL: begin
                    if (retransmit_req) begin
                        retry_cmd <= 1; // send retry command
                        next_retry_state <= RETRY_WAIT;
                        // Optionally reset data outputs and disables reads here
                        valid_out <= 0;
                        vc0_rd_en <= 0;
                        vc1_rd_en <= 0;
                        vc2_rd_en <= 0;
                        vc3_rd_en <= 0;
                    end else begin
                        next_retry_state <= NORMAL;
                        // Normal processing below:
                        if (valid_in) begin
                            // Pass data to VC buffers and update credits
                            data_out <= data_in;
                            vc_id_out <= vc_id_in;
                            valid_out <= 1;

                            // Read enable signals based on VC id
                            vc0_rd_en <= (vc_id_in == 2'd0) ? 1 : 0;
                            vc1_rd_en <= (vc_id_in == 2'd1) ? 1 : 0;
                            vc2_rd_en <= (vc_id_in == 2'd2) ? 1 : 0;
                            vc3_rd_en <= (vc_id_in == 2'd3) ? 1 : 0;

                            // Update credit counters on each valid data receipt
                            if (credit_count[vc_id_in] > 0)
                                credit_count[vc_id_in] <= credit_count[vc_id_in] - 1;
                            // When credits freed by VC read, credit update signals can be generated (this part depends on VC read feedback)
                        end else begin
                            valid_out <= 0;
                            vc0_rd_en <= 0;
                            vc1_rd_en <= 0;
                            vc2_rd_en <= 0;
                            vc3_rd_en <= 0;
                        end
                    end
                end
                RETRY_WAIT: begin
                    // Wait for retransmission to be ready, e.g. wait some cycles or external signal (not shown here)
                    // Transition to RETRY_ACTIVE or back to NORMAL after retransmission
                    // Placeholder logic:
                    next_retry_state <= RETRY_ACTIVE;
                end
                RETRY_ACTIVE: begin
                    // Accept retransmitted data, resume normal operation
                    if (!retransmit_req) begin
                        next_retry_state <= NORMAL;
                    end else begin
                        next_retry_state <= RETRY_ACTIVE;
                    end
                end
                default: next_retry_state <= NORMAL;
            endcase
        end
    end

    // Additional logic for credit upgrade commands (not shown: needs info from VC read signals)
    // When VC FIFOs free space (credits increase), assert credit_upd_vcx to inform TX side.

endmodule
