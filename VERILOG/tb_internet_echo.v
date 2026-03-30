`timescale 1ns / 1ps

// ============================================================
// Testbench : tb_ethernet_echo.v
// Test du module ethernet_echo.
//
// Trame RX injectée : 23 octets
//   [0..5]   = Dest MAC  : FF FF FF FF FF FF
//   [6..11]  = Src MAC   : 11 22 33 44 55 66
//   [12..13] = EtherType : 88 B5
//   [14..22] = Payload   : 41 41 41 41 41 41 41 41 41
//
// Objectif :
//   afficher clairement :
//     - le payload d'entrée
//     - le payload de sortie après traitement Enigma
// ============================================================

module tb_ethernet_echo;

    // ----------------------------------------------------------
    // Paramètres
    // ----------------------------------------------------------
    parameter integer DEPTH    = 2048;
    parameter integer ADDR_W   = 11;
    parameter [47:0]  FPGA_MAC = 48'hAA_AA_AA_AA_AA_AA;

    localparam integer RX_FRAME_LEN      = 23;
    localparam integer RX_PAYLOAD_START  = 14;
    localparam integer RX_PAYLOAD_LEN    = 9;

    // IMPORTANT :
    // Dans ton design actuel, d'après ton ancien check,
    // les données traitées ressortent à partir de TX[12].
    // Si besoin, change cette valeur à 14 selon ton architecture.
    localparam integer TX_PAYLOAD_START  = 15;

    // ----------------------------------------------------------
    // Signaux DUT
    // ----------------------------------------------------------
    reg clk;
    reg rst;

    // RX AXI-Stream
    reg  [7:0] rx_tdata;
    reg        rx_tvalid;
    reg        rx_tlast;
    reg        rx_tuser;

    // TX AXI-Stream
    wire [7:0] tx_tdata;
    wire       tx_tvalid;
    wire       tx_tlast;
    reg        tx_tready;

    // ----------------------------------------------------------
    // DUT
    // ----------------------------------------------------------
    ethernet_echo #(
        .DEPTH(DEPTH),
        .ADDR_W(ADDR_W),
        .FPGA_MAC(FPGA_MAC)
    ) dut (
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

    // ----------------------------------------------------------
    // Horloge : 100 MHz
    // ----------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------
    // Buffers
    // ----------------------------------------------------------
    reg [7:0] frame_in  [0:63];
    reg [7:0] frame_out [0:255];

    integer frame_len;
    integer out_count;
    integer i;

    // ----------------------------------------------------------
    // Capture TX
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (tx_tvalid && tx_tready) begin
            frame_out[out_count] <= tx_tdata;
            $display("TX[%0d] = %02X   tlast=%0b   time=%0t ns",
                     out_count, tx_tdata, tx_tlast, $time);
            out_count <= out_count + 1;
        end
    end

    // ----------------------------------------------------------
    // Task : envoyer une trame RX
    // ----------------------------------------------------------
    task send_frame;
        input integer length;
        integer k;
    begin
        @(posedge clk);
        for (k = 0; k < length; k = k + 1) begin
            rx_tdata  <= frame_in[k];
            rx_tvalid <= 1'b1;
            rx_tlast  <= (k == length - 1);
            rx_tuser  <= 1'b0;
            @(posedge clk);
        end

        rx_tvalid <= 1'b0;
        rx_tlast  <= 1'b0;
        rx_tdata  <= 8'h00;
        rx_tuser  <= 1'b0;
    end
    endtask

    // ----------------------------------------------------------
    // Affichage payload RX
    // ----------------------------------------------------------
    task print_rx_payload;
        integer k;
    begin
        $write("Payload d'entree est : ");
        for (k = 0; k < RX_PAYLOAD_LEN; k = k + 1) begin
            $write("%02X ", frame_in[RX_PAYLOAD_START + k]);
        end
        $write("\n");
    end
    endtask

    // ----------------------------------------------------------
    // Affichage payload TX
    // ----------------------------------------------------------
    task print_tx_payload;
        integer k;
    begin
        $write("Payload sortie est  : ");
        for (k = 0; k < RX_PAYLOAD_LEN; k = k + 1) begin
            $write("%02X ", frame_out[TX_PAYLOAD_START + k]);
        end
        $write("\n");
    end
    endtask

    // ----------------------------------------------------------
    // Programme principal
    // ----------------------------------------------------------
    initial begin
        // Init
        rst       = 1'b1;
        rx_tdata  = 8'h00;
        rx_tvalid = 1'b0;
        rx_tlast  = 1'b0;
        rx_tuser  = 1'b0;
        tx_tready = 1'b1;
        out_count = 0;
        frame_len = RX_FRAME_LEN;

        // Reset
        repeat(10) @(posedge clk);
        rst = 1'b0;
        repeat(5) @(posedge clk);

        // ------------------------------------------------------
        // Construction de la trame RX
        // ------------------------------------------------------
        // Dest MAC : FF:FF:FF:FF:FF:FF
        frame_in[0]  = 8'hFF;
        frame_in[1]  = 8'hFF;
        frame_in[2]  = 8'hFF;
        frame_in[3]  = 8'hFF;
        frame_in[4]  = 8'hFF;
        frame_in[5]  = 8'hFF;

        // Src MAC : 11:22:33:44:55:66
        frame_in[6]  = 8'h11;
        frame_in[7]  = 8'h22;
        frame_in[8]  = 8'h33;
        frame_in[9]  = 8'h44;
        frame_in[10] = 8'h55;
        frame_in[11] = 8'h66;

        // EtherType : 88B5
        frame_in[12] = 8'h88;
        frame_in[13] = 8'hB5;

        // Payload : "AAAAAAAAA" = 41 41 41 41 41 41 41 41 41
        frame_in[14] = 8'h41;
        frame_in[15] = 8'h41;
        frame_in[16] = 8'h41;
        frame_in[17] = 8'h41;
        frame_in[18] = 8'h41;
        frame_in[19] = 8'h41;
        frame_in[20] = 8'h41;
        frame_in[21] = 8'h41;
        frame_in[22] = 8'h41;

        $display("");
        $display("================================================");
        $display("ENVOI TRAME RX (%0d octets)", frame_len);
        $display("================================================");

        print_rx_payload();
        send_frame(frame_len);

        // Attente de la TX
        $display("");
        $display("... attente traitement Enigma + transmission TX ...");
        repeat(300) @(posedge clk);

        $display("");
        $display("================================================");
        $display("TRAME TX CAPTUREE (%0d octets)", out_count);
        $display("================================================");

        print_tx_payload();

        $display("");
        $display("Comparaison entree / sortie terminee.");
        $display("");

        $finish;
    end

endmodule