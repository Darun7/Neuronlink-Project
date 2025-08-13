`timescale 1ns/1ps

module pn_shared_bus #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32,
    parameter NUM_DPUS   = 1,
    parameter NUM_APUS   = 0
)(
    input  wire                   clk,
    input  wire                   rst_n,

    output reg                    wr_en,
    output reg                    rd_en,
    output reg  [ADDR_WIDTH-1:0]  addr,
    output reg  [DATA_WIDTH-1:0]  wr_data,
    input  wire [DATA_WIDTH-1:0]  rd_data,
    input  wire                   busy,

    input  wire [DATA_WIDTH-1:0]  dpu_out  [NUM_DPUS-1:0],
    input  wire                   dpu_valid [NUM_DPUS-1:0],
    input  wire [DATA_WIDTH-1:0]  apu_out  [NUM_APUS-1:0],
    input  wire                   apu_valid [NUM_APUS-1:0]
);

    localparam IDLE = 0, WRITE_DPU = 1, WRITE_APU = 2;

    reg [1:0] state, next_state;
    reg [DATA_WIDTH-1:0] selected_data;
    reg selected_valid, selected_type;
    integer source_index;
    reg [ADDR_WIDTH-1:0] wr_addr;

    // Separate round-robin pointers for DPU and APU
    reg [$clog2(NUM_DPUS)-1:0] rr_dpu_ptr;
    reg [$clog2(NUM_APUS)-1:0] rr_apu_ptr;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Round-robin pointer updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rr_dpu_ptr <= 0;
        else if ((state == WRITE_DPU) && !busy)
            rr_dpu_ptr <= (rr_dpu_ptr + 1) % NUM_DPUS;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rr_apu_ptr <= 0;
        else if ((state == WRITE_APU) && !busy)
            rr_apu_ptr <= (rr_apu_ptr + 1) % NUM_APUS;
    end

    // Next state and selection logic (round-robin between all DPUs, then all APUs)
    always @(*) begin
        next_state = IDLE;
        selected_data = 0;
        selected_valid = 0;
        selected_type = 0;
        source_index = 0;

        if (busy)
            next_state = IDLE;
        else begin
            // Try all DPUs starting from rr_dpu_ptr
            integer offset, idx;
            selected_valid = 0;
            for (offset = 0; offset < NUM_DPUS; offset = offset + 1) begin
                idx = (rr_dpu_ptr + offset) % NUM_DPUS;
                if (!selected_valid && dpu_valid[idx]) begin
                    selected_data = dpu_out[idx];
                    selected_valid = 1;
                    selected_type = 0;
                    source_index = idx;
                    next_state = WRITE_DPU;
                end
            end
            // If no valid DPU, try all APUs starting from rr_apu_ptr
            if (!selected_valid && NUM_APUS > 0) begin
                integer a_offset, a_idx;
                for (a_offset = 0; a_offset < NUM_APUS; a_offset = a_offset + 1) begin
                    a_idx = (rr_apu_ptr + a_offset) % NUM_APUS;
                    if (!selected_valid && apu_valid[a_idx]) begin
                        selected_data = apu_out[a_idx];
                        selected_valid = 1;
                        selected_type = 1;
                        source_index = a_idx;
                        next_state = WRITE_APU;
                    end
                end
            end
        end
    end

    // Write address update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wr_addr <= 0;
        else if ((state == WRITE_DPU || state == WRITE_APU) && !busy)
            wr_addr <= wr_addr + 1;
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_en <= 0;
            rd_en <= 0;
            wr_data <= 0;
            addr <= 0;
        end else begin
            wr_en <= 0;
            rd_en <= 0;
            wr_data <= 0;
            addr <= 0;

            if ((state == WRITE_DPU || state == WRITE_APU) && !busy && selected_valid) begin
                wr_en <= 1;
                wr_data <= selected_data;
                addr <= wr_addr;

                $display("[%0t] Writing from %s[%0d]: addr=%0d, data=0x%08X",
                         $time,
                         (selected_type == 0) ? "DPU" : "APU",
                         source_index,
                         wr_addr,
                         selected_data);
            end
        end
    end

endmodule