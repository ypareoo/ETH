

module ethernet_echo_axis (
    input wire clk,             // clk_mac
    input wire rst_n,            // reset actif bas

    // RX
    input wire [7:0] rx_tdata,
    input wire       rx_tvalid,
    input wire       rx_tlast,
    input wire       rx_tuser,

    // TX
    input wire       tx_tready,
    output wire [7:0] tx_tdata,
    output wire       tx_tvalid,
    output wire       tx_tlast
);

    wire rst;
    assign rst = ~rst_n; 

    ethernet_echo #(
        .DEPTH(2048),
        .ADDR_W(11),
        .FPGA_MAC(48'hAA_AA_AA_AA_AA_AA)
    ) u_core (
        .clk(clk),
        .rst(rst),

        .rx_tdata(rx_tdata),
        .rx_tvalid(rx_tvalid),
        .rx_tlast(rx_tlast),
        .rx_tuser(rx_tuser),

        .tx_tdata(tx_tdata),
        .tx_tvalid(tx_tvalid),
        .tx_tlast(tx_tlast),
        .tx_tready(tx_tready)
    );

endmodule
