`timescale 1ns / 1ps

module nc_rx_dll_noc_if #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 4,
    parameter FIFO_DEPTH = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Input interface from DLL (Data Link Layer)
    input  wire                  dll_valid,
    input  wire [DATA_WIDTH-1:0] dll_data,
    output wire                  dll_ready,

    // Output interface to NoC (Network on Chip)
    output reg                   noc_valid,
    output reg  [DATA_WIDTH-1:0] noc_data,
    input  wire                  noc_ready
);

    // FIFO buffer to hold packets before sending to NoC
    reg [DATA_WIDTH-1:0] fifo_mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;
    reg [ADDR_WIDTH:0]   count;

    assign dll_ready = (count < FIFO_DEPTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            noc_valid <= 0;
            noc_data <= 0;
        end else begin
            // Write into FIFO from DLL input if valid and space available
            if (dll_valid && dll_ready) begin
                fifo_mem[wr_ptr] <= dll_data;
                wr_ptr <= wr_ptr + 1;
                count <= count + 1;
            end

            // Read from FIFO and send to NoC if NoC ready or no valid data currently
            if ((!noc_valid || noc_ready) && (count > 0)) begin
                noc_data <= fifo_mem[rd_ptr];
                noc_valid <= 1;
                rd_ptr <= rd_ptr + 1;
                count <= count - 1;
            end else if (noc_ready) begin
                // If NoC accepted data, clear valid if no data to send
                if (count == 0) noc_valid <= 0;
            end
        end
    end

endmodule