`timescale 1ns / 1ps

module pcie_interface_logic #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // PCIe physical (user-facing) ports (abstracted)
    input  wire [DATA_WIDTH-1:0] pcie_rx_data,
    input  wire                  pcie_rx_valid,
    output wire                  pcie_rx_ready,

    output wire [DATA_WIDTH-1:0] pcie_tx_data,
    output wire                  pcie_tx_valid,
    input  wire                  pcie_tx_ready,

    // Application interface (NoC, bridge or memory-mapped)
    output reg  [ADDR_WIDTH-1:0] app_addr,
    output reg  [DATA_WIDTH-1:0] app_wdata,
    output reg                   app_write,
    output reg                   app_read,
    input  wire [DATA_WIDTH-1:0] app_rdata,
    input  wire                  app_ready
);

    // Simple RX handling (PCIe to application)
    reg rx_ready_r;
    assign pcie_rx_ready = rx_ready_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            app_addr  <= 0;
            app_wdata <= 0;
            app_write <= 0;
            app_read  <= 0;
            rx_ready_r <= 1;
        end else begin
            app_write <= 0;
            app_read  <= 0;
            if (pcie_rx_valid && rx_ready_r) begin
                // For demonstration, treat lower ADDR_WIDTH bits as address, upper as data
                app_addr  <= pcie_rx_data[ADDR_WIDTH-1:0];
                app_wdata <= pcie_rx_data;
                app_write <= 1'b1;
                rx_ready_r <= 0;
            end else if (!pcie_rx_valid) begin
                rx_ready_r <= 1;
            end
        end
    end

    // Simple TX handling (application to PCIe)
    reg tx_valid_r;
    reg [DATA_WIDTH-1:0] tx_data_r;

    assign pcie_tx_valid = tx_valid_r;
    assign pcie_tx_data  = tx_data_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_valid_r <= 0;
            tx_data_r  <= 0;
        end else begin
            tx_valid_r <= 0;
            if (app_ready) begin
                tx_data_r  <= app_rdata;
                tx_valid_r <= 1'b1;
            end
        end
    end

endmodule