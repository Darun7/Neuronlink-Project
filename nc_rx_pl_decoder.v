// nc_rx_pl_decoder.v
module nc_rx_pl_decoder (
    input  logic         clk,
    input  logic         rst,
    input  logic [7:0]   data_in,
    input  logic         valid_in,

    output logic [7:0]   payload_data,
    output logic         payload_valid,
    output logic         retransmit_req
);

    typedef enum logic [1:0] {
        IDLE,
        HEADER,
        PAYLOAD,
        CHECK
    } state_t;

    state_t state, next_state;

    logic [7:0] header;
    logic [7:0] payload;
    logic [7:0] checksum;
    logic [7:0] calc_checksum;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            header <= 0;
            payload <= 0;
            checksum <= 0;
            calc_checksum <= 0;
            retransmit_req <= 0;
            payload_valid <= 0;
            payload_data <= 0;
        end else begin
            state <= next_state;
            retransmit_req <= 0;
            payload_valid <= 0;

            if (valid_in) begin
                case (state)
                    IDLE: begin
                        header <= data_in;
                    end

                    HEADER: begin
                        payload <= data_in;
                    end

                    PAYLOAD: begin
                        checksum <= data_in;
                        calc_checksum <= header ^ payload;  // Simple XOR checksum
                    end

                    CHECK: begin
                        if (checksum != calc_checksum) begin
                            retransmit_req <= 1;
                        end else begin
                            payload_data <= payload;
                            payload_valid <= 1;
                        end
                    end
                endcase
            end
        end
    end

    always_comb begin
        next_state = state;
        if (valid_in) begin
            case (state)
                IDLE:    next_state = HEADER;
                HEADER:  next_state = PAYLOAD;
                PAYLOAD: next_state = CHECK;
                CHECK:   next_state = IDLE;
            endcase
        end
    end

endmodule