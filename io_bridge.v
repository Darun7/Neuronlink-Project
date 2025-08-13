`timescale 1ns / 1ps

module io_bridge #(
    parameter DATA_WIDTH = 64,
    parameter ADDR_WIDTH = 4,
    parameter RX_SMALL_WIDTH = 8,
    parameter RX_FIFO_DEPTH = 16
)(
    input  wire                    clk,
    input  wire                    rst_n,

    // PCIe interface
    input  wire [DATA_WIDTH-1:0]   pcie_rx_data,
    input  wire                    pcie_rx_valid,
    output wire                    pcie_rx_ready,
    output wire [DATA_WIDTH-1:0]   pcie_tx_data,
    output wire                    pcie_tx_valid,
    input  wire                    pcie_tx_ready,

    // NoC interface in (to TX pipeline)
    input  wire                    noc_in_valid,
    input  wire [DATA_WIDTH-1:0]   noc_in_data,
    output wire                    noc_in_ready,

    // NoC interface out (from RX pipeline)
    output wire [DATA_WIDTH-1:0]   noc_out_data,
    output wire                    noc_out_valid,
    input  wire                    noc_out_ready,

    // NeuronLink-C serial
    input  wire                    rx_p,
    input  wire                    rx_n,
    output wire                    tx_serial_out
);

    //========== Control Logic ==========
    reg  tx_busy;
    wire tx_path_ready;
    wire [1:0] selected_vc;

    // TX PIPELINE HANDSHAKE SIGNALS
    wire packager_valid, encoder_valid, scrambler_valid, ser_valid;
    wire packager_ready, encoder_ready, scrambler_ready, gearbox_ready, serializer_ready;

    assign serializer_ready = ~busy;

    // TX Path Activity Control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_busy <= 1'b0;
        else if (noc_in_valid && tx_path_ready)
            tx_busy <= 1'b1;
        else if (ser_valid && serializer_ready)
            tx_busy <= 1'b0;
    end

    //========== PCIe Interface ==========
    wire [ADDR_WIDTH-1:0]  pcie_app_addr;
    wire [DATA_WIDTH-1:0]  pcie_app_wdata;
    wire                   pcie_app_write;
    wire                   pcie_app_read;
    wire [DATA_WIDTH-1:0]  pcie_app_rdata;
    wire                   pcie_app_ready;

    pcie_interface_logic #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_pcie (
        .clk(clk),
        .rst_n(rst_n),
        .pcie_rx_data(pcie_rx_data),
        .pcie_rx_valid(pcie_rx_valid),
        .pcie_rx_ready(pcie_rx_ready),
        .pcie_tx_data(pcie_tx_data),
        .pcie_tx_valid(pcie_tx_valid),
        .pcie_tx_ready(pcie_tx_ready),
        .app_addr(pcie_app_addr),
        .app_wdata(pcie_app_wdata),
        .app_write(pcie_app_write),
        .app_read(pcie_app_read),
        .app_rdata(pcie_app_rdata),
        .app_ready(pcie_app_ready)
    );

    //========== TX PATH (NoC to serial_out) ==========
    // Packet Analyzer
    wire [3:0]   tx_packet_priority;
    wire         tx_multicast;
    wire [8:0]   tx_dest_addr;
    wire         tx_analyzed_valid;

    nc_tx_dll_packet_analyzer u_packet_analyzer (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(noc_in_valid && tx_path_ready),
        .packet_in(noc_in_data),
        .packet_priority(tx_packet_priority),
        .multicast(tx_multicast),
        .dest_addr(tx_dest_addr),
        .valid_out(tx_analyzed_valid)
    );

    // VC Buffers
    wire [DATA_WIDTH-1:0] vc0_data_out, vc1_data_out, vc2_data_out, vc3_data_out;
    wire                  vc0_empty,    vc1_empty,    vc2_empty,    vc3_empty;
    wire                  vc0_full,     vc1_full,     vc2_full,     vc3_full;
    wire                  vc0_rd_en,    vc1_rd_en,    vc2_rd_en,    vc3_rd_en;

    assign selected_vc = tx_packet_priority[1:0];

    nc_tx_dll_vc_buffers #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(16),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_vc_buffers (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(tx_analyzed_valid),
        .packet_in(noc_in_data),
        .packet_priority(selected_vc),
        .vc0_data_out(vc0_data_out),
        .vc1_data_out(vc1_data_out),
        .vc2_data_out(vc2_data_out),
        .vc3_data_out(vc3_data_out),
        .vc0_empty(vc0_empty),
        .vc1_empty(vc1_empty),
        .vc2_empty(vc2_empty),
        .vc3_empty(vc3_empty),
        .vc0_rd_en(vc0_rd_en),
        .vc1_rd_en(vc1_rd_en),
        .vc2_rd_en(vc2_rd_en),
        .vc3_rd_en(vc3_rd_en),
        .vc0_full(vc0_full),
        .vc1_full(vc1_full),
        .vc2_full(vc2_full),
        .vc3_full(vc3_full)
    );

    // Credit Management
    wire [1:0]   crm_selected_vc;
    wire         crm_valid_out;
    wire [DATA_WIDTH-1:0] crm_wr_data;
    wire                  crm_wr_en;

    nc_tx_dll_crm #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_crm (
        .clk(clk),
        .rst_n(rst_n),
        .vc0_credit(~vc0_full),
        .vc1_credit(~vc1_full),
        .vc2_credit(~vc2_full),
        .vc3_credit(~vc3_full),
        .vc0_empty(vc0_empty),
        .vc1_empty(vc1_empty),
        .vc2_empty(vc2_empty),
        .vc3_empty(vc3_empty),
        .vc0_data_out(vc0_data_out),
        .vc1_data_out(vc1_data_out),
        .vc2_data_out(vc2_data_out),
        .vc3_data_out(vc3_data_out),
        .retry_req(1'b0),
        .retry_data_valid(1'b0),
        .retry_data({DATA_WIDTH{1'b0}}),
        .valid_out(crm_valid_out),
        .wr_data(crm_wr_data),
        .selected_vc(crm_selected_vc),
        .vc0_rd_en(vc0_rd_en),
        .vc1_rd_en(vc1_rd_en),
        .vc2_rd_en(vc2_rd_en),
        .vc3_rd_en(vc3_rd_en),
        .wr_en(crm_wr_en)
    );

    //========== PIPELINED TX DATAPATH ==========
    wire [DATA_WIDTH-1:0] packager_data_out;
    wire [79:0] encoder_data_out, scrambler_data_out;
    wire [19:0] ser_data;
    wire busy;

    nc_tx_dll_packager u_packager (
        .clk(clk),
        .rst_n(rst_n),
        .vc0_valid((crm_selected_vc==2'b00) & crm_valid_out),
        .vc0_data(crm_wr_data),
        .vc1_valid((crm_selected_vc==2'b01) & crm_valid_out),
        .vc1_data(crm_wr_data),
        .vc2_valid((crm_selected_vc==2'b10) & crm_valid_out),
        .vc2_data(crm_wr_data),
        .vc3_valid((crm_selected_vc==2'b11) & crm_valid_out),
        .vc3_data(crm_wr_data),
        .retry_valid(1'b0),
        .retry_data({DATA_WIDTH{1'b0}}),
        .ready_in(packager_ready),
        .valid_out(packager_valid),
        .data_out(packager_data_out)
    );

    nc_tx_pl_encoder u_encoder (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(packager_valid),
        .ready_in(encoder_ready),
        .payload_in(packager_data_out),
        .valid_out(encoder_valid),
        .encoded_out(encoder_data_out)
    );

    nc_tx_pl_scrambler u_scrambler (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(encoder_valid),
        .ready_in(scrambler_ready),
        .data_in(encoder_data_out),
        .valid_out(scrambler_valid),
        .data_out(scrambler_data_out)
    );

    nc_tx_pl_gearbox u_gearbox (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(scrambler_valid),
        .data_in(scrambler_data_out),
        .ready_in(gearbox_ready),
        .valid_out(ser_valid),
        .data_out(ser_data),
        .ready_out(gearbox_ready)
    );

    nc_tx_pl_serializer u_serializer (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(ser_valid),
        .data_in(ser_data),
        .busy(busy),
        .serial_out(tx_serial_out)
    );

    // Handshake chain: ready goes downstream to upstream
    assign packager_ready   = encoder_ready;
    assign encoder_ready    = scrambler_ready;
    assign scrambler_ready  = gearbox_ready;
    assign gearbox_ready    = serializer_ready;

    // TX Path Ready Logic
    assign tx_path_ready = !tx_busy && !vc0_full;
    assign noc_in_ready = tx_path_ready;

    //========== RX PATH Implementation ==========
    // [RX path implementation remains unchanged -- see your original file for RX logic]

    //============ NeuronLink-C RX Path (Serial to NoC) ============

    wire [RX_SMALL_WIDTH-1:0] deser_parallel_data;
    wire deser_data_valid;
    nc_rx_pl_deserializer #(
        .DATA_WIDTH(RX_SMALL_WIDTH)
    ) u_deserializer (
        .clk(clk),
        .rst_n(rst_n),
        .rx_p(rx_p),
        .rx_n(rx_n),
        .parallel_data(deser_parallel_data),
        .data_valid(deser_data_valid)
    );

    wire [RX_SMALL_WIDTH-1:0] pma_data_out;
    wire pma_data_out_valid;
    wire pma_aligned;
    nc_rx_pl_pma_logic #(
        .DATA_WIDTH(RX_SMALL_WIDTH)
    ) u_pma (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(deser_parallel_data),
        .data_valid(deser_data_valid),
        .data_out(pma_data_out),
        .data_out_valid(pma_data_out_valid),
        .aligned(pma_aligned)
    );

    wire [RX_SMALL_WIDTH-1:0] descrambled_out;
    wire                      descrambled_valid;
    nc_rx_pl_descrambler #(
        .DATA_WIDTH(RX_SMALL_WIDTH)
    ) u_descrambler (
        .clk(clk),
        .rst_n(rst_n),
        .data_in_valid(pma_data_out_valid),
        .data_in(pma_data_out),
        .data_out_valid(descrambled_valid),
        .data_out(descrambled_out)
    );

    wire [RX_SMALL_WIDTH-1:0] decoder_payload_data;
    wire                      decoder_payload_valid;
    wire                      decoder_retransmit_req;
    nc_rx_pl_decoder u_decoder (
        .clk(clk),
        .rst(rst_n),
        .data_in(descrambled_out),
        .valid_in(descrambled_valid),
        .payload_data(decoder_payload_data),
        .payload_valid(decoder_payload_valid),
        .retransmit_req(decoder_retransmit_req)
    );

    wire [RX_SMALL_WIDTH-1:0] elastic_out;
    wire                      elastic_valid;
    nc_rx_pl_elastic_buffer #(
        .DATA_WIDTH(RX_SMALL_WIDTH),
        .DEPTH(RX_FIFO_DEPTH)
    ) u_elastic_buf (
        .rx_clk(clk),
        .rx_rst(~rst_n),
        .wr_en(decoder_payload_valid),
        .din(decoder_payload_data),
        .local_clk(clk),
        .local_rst(~rst_n),
        .rd_en(1'b1),
        .dout(elastic_out),
        .valid_out(elastic_valid)
    );

    // Recombine 8b chunks into 64b words for DLL
    reg  [DATA_WIDTH-1:0] dll_repack_data = 0;
    reg  [2:0]            dll_repack_cnt = 0;
    reg                   dll_repack_valid = 0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dll_repack_data <= 0;
            dll_repack_cnt  <= 0;
            dll_repack_valid<= 0;
        end else if (elastic_valid) begin
            dll_repack_data <= {dll_repack_data[DATA_WIDTH-9:0], elastic_out};
            if (dll_repack_cnt == (DATA_WIDTH/RX_SMALL_WIDTH-1)) begin
                dll_repack_cnt <= 0;
                dll_repack_valid <= 1;
            end else begin
                dll_repack_cnt <= dll_repack_cnt + 1;
                dll_repack_valid <= 0;
            end
        end else begin
            dll_repack_valid <= 0;
        end
    end

    wire [DATA_WIDTH-1:0] dll_buffer_out;
    wire                  dll_buffer_ready;
    nc_rx_dll_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(8)
    ) u_dll_buffer (
        .clk(clk),
        .rst(~rst_n),
        .data_in(dll_repack_data),
        .data_valid(dll_repack_valid),
        .data_out(dll_buffer_out),
        .data_ready(dll_buffer_ready)
    );

    wire [1:0]         crm_vc_id_out;
    wire [DATA_WIDTH-1:0] crm_data_out;
    wire               crm_vc0_rd_en, crm_vc1_rd_en, crm_vc2_rd_en, crm_vc3_rd_en;
    wire [ADDR_WIDTH:0] crm_vc0_credit, crm_vc1_credit, crm_vc2_credit, crm_vc3_credit;
    wire               crm_credit_upd_vc0, crm_credit_upd_vc1, crm_credit_upd_vc2, crm_credit_upd_vc3;
    wire               crm_retry_cmd;
    nc_rx_dll_crm #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(RX_FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_dll_crm (
        .clk(clk),
        .rst_n(rst_n),
        .retransmit_req(decoder_retransmit_req),
        .valid_in(dll_buffer_ready),
        .data_in(dll_buffer_out),
        .vc_id_in(2'b00), // For demo; real code: extract VC
        .vc0_rd_en(crm_vc0_rd_en),
        .vc1_rd_en(crm_vc1_rd_en),
        .vc2_rd_en(crm_vc2_rd_en),
        .vc3_rd_en(crm_vc3_rd_en),
        .valid_out(crm_valid_out),
        .data_out(crm_data_out),
        .vc_id_out(crm_vc_id_out),
        .retry_cmd(crm_retry_cmd),
        .vc0_credit(crm_vc0_credit),
        .vc1_credit(crm_vc1_credit),
        .vc2_credit(crm_vc2_credit),
        .vc3_credit(crm_vc3_credit),
        .credit_upd_vc0(crm_credit_upd_vc0),
        .credit_upd_vc1(crm_credit_upd_vc1),
        .credit_upd_vc2(crm_credit_upd_vc2),
        .credit_upd_vc3(crm_credit_upd_vc3)
    );

    wire [DATA_WIDTH-1:0] rx_vc0_data_out, rx_vc1_data_out, rx_vc2_data_out, rx_vc3_data_out;
    wire                  rx_vc0_empty, rx_vc1_empty, rx_vc2_empty, rx_vc3_empty;
    wire                  rx_vc0_full, rx_vc1_full, rx_vc2_full, rx_vc3_full;
    nc_rx_dll_vc_buffers #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(RX_FIFO_DEPTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_rx_vc_buffers (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(crm_valid_out),
        .data_in(crm_data_out),
        .vc_id(crm_vc_id_out),
        .vc0_data_out(rx_vc0_data_out),
        .vc1_data_out(rx_vc1_data_out),
        .vc2_data_out(rx_vc2_data_out),
        .vc3_data_out(rx_vc3_data_out),
        .vc0_empty(rx_vc0_empty),
        .vc1_empty(rx_vc1_empty),
        .vc2_empty(rx_vc2_empty),
        .vc3_empty(rx_vc3_empty),
        .vc0_rd_en(crm_vc0_rd_en),
        .vc1_rd_en(crm_vc1_rd_en),
        .vc2_rd_en(crm_vc2_rd_en),
        .vc3_rd_en(crm_vc3_rd_en),
        .vc0_full(rx_vc0_full),
        .vc1_full(rx_vc1_full),
        .vc2_full(rx_vc2_full),
        .vc3_full(rx_vc3_full)
    );

    nc_rx_dll_noc_if #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(RX_FIFO_DEPTH)
    ) u_noc_if (
        .clk(clk),
        .rst_n(rst_n),
        .dll_valid(~rx_vc0_empty),
        .dll_data(rx_vc0_data_out),
        .dll_ready(),
        .noc_valid(noc_out_valid),
        .noc_data(noc_out_data),
        .noc_ready(noc_out_ready)
    );

endmodule