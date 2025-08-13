`timescale 1ns / 1ps

module nc_tx_dll_crm #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,

    // Credit status (1 = credit available)
    input wire vc0_credit,
    input wire vc1_credit,
    input wire vc2_credit,
    input wire vc3_credit,

    // VC buffer signals
    input wire vc0_empty,
    input wire vc1_empty,
    input wire vc2_empty,
    input wire vc3_empty,

    input wire [DATA_WIDTH-1:0] vc0_data_out,
    input wire [DATA_WIDTH-1:0] vc1_data_out,
    input wire [DATA_WIDTH-1:0] vc2_data_out,
    input wire [DATA_WIDTH-1:0] vc3_data_out,

    // Retry buffer signals
    input wire retry_req,
    input wire retry_data_valid,
    input wire [DATA_WIDTH-1:0] retry_data,

    // Output to packager/fifo
    output reg valid_out,
    output reg [DATA_WIDTH-1:0] wr_data,
    output reg [1:0] selected_vc,

    // Control signals to VC FIFOs
    output reg vc0_rd_en,
    output reg vc1_rd_en,
    output reg vc2_rd_en,
    output reg vc3_rd_en,
    output reg wr_en
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_out <= 0;
            wr_data <= 0;
            wr_en <= 0;
            selected_vc <= 0;
            vc0_rd_en <= 0;
            vc1_rd_en <= 0;
            vc2_rd_en <= 0;
            vc3_rd_en <= 0;
        end else begin
            wr_en <= 0;
            valid_out <= 0;
            vc0_rd_en <= 0;
            vc1_rd_en <= 0;
            vc2_rd_en <= 0;
            vc3_rd_en <= 0;

            // Retry logic has priority
            if (retry_req && retry_data_valid) begin
                wr_data <= retry_data;
                valid_out <= 1;
                wr_en <= 1;
                selected_vc <= 2'b11; // retry
            end
            // VC0-VC3 arbitration
            else if (!vc0_empty && vc0_credit) begin
                wr_data <= vc0_data_out;
                selected_vc <= 2'b00;
                vc0_rd_en <= 1;
                valid_out <= 1;
                wr_en <= 1;
            end else if (!vc1_empty && vc1_credit) begin
                wr_data <= vc1_data_out;
                selected_vc <= 2'b01;
                vc1_rd_en <= 1;
                valid_out <= 1;
                wr_en <= 1;
            end else if (!vc2_empty && vc2_credit) begin
                wr_data <= vc2_data_out;
                selected_vc <= 2'b10;
                vc2_rd_en <= 1;
                valid_out <= 1;
                wr_en <= 1;
            end else if (!vc3_empty && vc3_credit) begin
                wr_data <= vc3_data_out;
                selected_vc <= 2'b11;
                vc3_rd_en <= 1;
                valid_out <= 1;
                wr_en <= 1;
            end
        end
    end

endmodule