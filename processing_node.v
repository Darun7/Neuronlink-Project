`timescale 1ns / 1ps

module processing_node #(
    parameter ADDR_WIDTH   = 8,
    parameter DATA_WIDTH   = 32,    // 32-bit data for DPU, Shared Bus, eDRAM
    parameter APU_DATA_WIDTH = 8,   // 8-bit data width internally for APU
    parameter NUM_DPUS     = 2,
    parameter NUM_APUS     = 2
)(
    input  wire clk,
    input  wire rst_n
);

    // DPU outputs: 32-bit
    wire [DATA_WIDTH-1:0] dpu_out   [NUM_DPUS-1:0];
    wire                  dpu_valid [NUM_DPUS-1:0];

    // APU outputs internally 8-bit, then zero-extended to 32-bit
    wire [APU_DATA_WIDTH-1:0] apu_out_8 [NUM_APUS-1:0];
    wire [DATA_WIDTH-1:0]     apu_out   [NUM_APUS-1:0];
    wire                      apu_valid [NUM_APUS-1:0];

    // eDRAM signals
    wire                    wr_en;
    wire                    rd_en;
    wire [ADDR_WIDTH-1:0]   addr;
    wire [DATA_WIDTH-1:0]   wr_data;
    wire [DATA_WIDTH-1:0]   rd_data;
    wire                    busy;

    // Dynamic inputs for DPUs (8-bit each)
    reg [7:0] in_a [NUM_DPUS-1:0];
    reg [7:0] in_b [NUM_DPUS-1:0];

    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j=0; j<NUM_DPUS; j=j+1) begin
                in_a[j] <= 8'd10 + j;
                in_b[j] <= 8'd20 + j;
            end
        end else begin
            for (j=0; j<NUM_DPUS; j=j+1) begin
                in_a[j] <= in_a[j] + 1;
                in_b[j] <= in_b[j] + 2;
            end
        end
    end

    // Instantiate DPUs
    genvar i;
    generate
        for (i = 0; i < NUM_DPUS; i = i + 1) begin : dpu_array
            pn_dpu #(.DATA_WIDTH(8)) u_dpu (
                .clk(clk),
                .rst(~rst_n),       // active-high reset for submodule
                .in_a(in_a[i]),
                .in_b(in_b[i]),
                .valid(1'b1),
                .dpu_out(dpu_out[i]),   // 32-bit output expected from DPU
                .dpu_valid(dpu_valid[i])
            );
        end
    endgenerate

    // Instantiate APUs (8-bit internally)
    genvar k;
    generate
        for (k = 0; k < NUM_APUS; k = k + 1) begin : apu_array
            pn_apu #(.DATA_WIDTH(APU_DATA_WIDTH)) u_apu (
                .clk(clk),
                .rst(~rst_n),
                .enable(1'b1),
                .digital_in(k[APU_DATA_WIDTH-1:0]),
                .sah_sample_en(1'b0),
                .mem_vin_enable(4'b0000),
                .sah_vout(),
                .mem_iout(),
                .adc_digital_data(apu_out_8[k])
            );
            assign apu_valid[k] = 1'b1;  // always valid for test
            assign apu_out[k] = {24'b0, apu_out_8[k]}; // zero-extend to 32 bits
        end
    endgenerate

    // Instantiate Shared Bus with 32-bit DATA_WIDTH
    pn_shared_bus #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_DPUS(NUM_DPUS),
        .NUM_APUS(NUM_APUS)
    ) u_shared_bus (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .busy(busy),
        .dpu_out(dpu_out),
        .dpu_valid(dpu_valid),
        .apu_out(apu_out),
        .apu_valid(apu_valid)
    );

    // Instantiate eDRAM interface with 32-bit DATA_WIDTH
    pn_edram_if #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_edram_if (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .busy(busy)
    );

endmodule