`timescale 1ns/1ps

module pn_dpu #(
    parameter DATA_WIDTH = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire [DATA_WIDTH-1:0]  in_a,
    input  wire [DATA_WIDTH-1:0]  in_b,
    input  wire                   valid,

    output reg  [31:0]            dpu_out,
    output reg                    dpu_valid,
    output reg  [DATA_WIDTH-1:0]  mult_result,
    output reg  [DATA_WIDTH-1:0]  relu_out,
    output reg  [DATA_WIDTH-1:0]  pooled_out
);

    // Pooling buffer (shift register for last 4 relu_out values)
    reg [DATA_WIDTH-1:0] pool_buffer [3:0];
    integer i;

    // Pipeline registers for predictability
    reg [DATA_WIDTH-1:0] mult_result_r, relu_out_r;
    reg valid_r;

    // Multiplier and pipeline
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mult_result_r <= 0;
            relu_out_r    <= 0;
            valid_r       <= 0;
        end else begin
            if (valid) begin
                mult_result_r <= in_a * in_b;
                relu_out_r    <= in_a * in_b; // ReLU for unsigned, just pass through
                valid_r       <= 1;
            end else begin
                mult_result_r <= 0;
                relu_out_r    <= 0;
                valid_r       <= 0;
            end
        end
    end

    // Output assignments for mult_result and relu_out (for testbench visibility)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mult_result <= 0;
            relu_out    <= 0;
        end else begin
            mult_result <= mult_result_r;
            relu_out    <= relu_out_r;
        end
    end

    // Pooling buffer update (shift register)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                pool_buffer[i] <= 0;
        end else if (valid_r) begin
            pool_buffer[3] <= pool_buffer[2];
            pool_buffer[2] <= pool_buffer[1];
            pool_buffer[1] <= pool_buffer[0];
            pool_buffer[0] <= relu_out_r;
        end
    end

    // Max pooling over last 4 relu_out values (combinational)
    always @(*) begin
        pooled_out = pool_buffer[0];
        for (i = 1; i < 4; i = i + 1) begin
            if (pool_buffer[i] > pooled_out)
                pooled_out = pool_buffer[i];
        end
    end

    // Output packing and valid signal (latched with pipeline)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            dpu_out   <= 0;
            dpu_valid <= 0;
        end else begin
            if (valid_r) begin
                dpu_out   <= {16'b0, relu_out_r, pooled_out}; // pack two 8-bit values
                dpu_valid <= 1;
            end else begin
                dpu_out   <= 0;
                dpu_valid <= 0;
            end
        end
    end

endmodule