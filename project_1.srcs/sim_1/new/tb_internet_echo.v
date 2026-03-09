`timescale 1ns / 1ps

// ============================================================
// Testbench : tb_ethernet_echo.v
// Teste le module ethernet_echo (echo_instMK2.v) en isolation.
//
// Trame RX injectée (20 octets) :
//   [0..5]  = Dest MAC  : FF FF FF FF FF FF  (broadcast)
//   [6..11] = Src MAC   : AA BB CC DD EE FF
//   [12..13]= EtherType : 88 B5
//   [14..19]= Payload   : A1 01 02 03 04 05
//
// Résultat TX attendu (60 octets) :
//   [0..5]  = Dest MAC  : AA BB CC DD EE FF  (src RX -> dest TX)
//   [6..11] = Src MAC   : 02 12 34 56 78 9A  (FPGA_MAC)
//   [12..59]= Payload+1 : chaque octet RX + 1
// ============================================================

module tb_ethernet_echo;

    // ----------------------------------------------------------
    // Paramètres
    // ----------------------------------------------------------
    parameter integer DEPTH    = 2048;
    parameter integer ADDR_W   = 11;
    parameter [47:0]  FPGA_MAC = 48'hAA_AA_AA_AA_AA_AA;

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
    initial clk = 0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------
    // Stockage trame TX capturée
    // ----------------------------------------------------------
    reg [7:0]  frame_out [0:255];
    integer    out_count;

    always @(posedge clk) begin
        if (tx_tvalid && tx_tready) begin
            frame_out[out_count] <= tx_tdata;
            $display("  TX[%02d] = 8'h%02X  (tlast=%0b)  @%0t ns",
                     out_count, tx_tdata, tx_tlast, $time);
            out_count <= out_count + 1;
        end
    end

    // ----------------------------------------------------------
    // Trame RX à envoyer
    // ----------------------------------------------------------
    reg [7:0] frame_in [0:63];
    integer   frame_len;

    // ----------------------------------------------------------
    // Task : injection trame RX octet par octet
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
    end
    endtask

    // ----------------------------------------------------------
    // Task : vérification des octets TX attendus
    // ----------------------------------------------------------
    integer err_count;

    task check_byte;
        input integer idx;
        input [7:0]   expected;
        input [63:0]  label; // label court en ASCII
    begin
        if (frame_out[idx] !== expected) begin
            $display("  [FAIL] TX[%02d] attendu=0x%02X recu=0x%02X  (%s)",
                     idx, expected, frame_out[idx], label);
            err_count = err_count + 1;
        end else begin
            $display("  [OK]   TX[%02d] = 0x%02X  (%s)", idx, expected, label);
        end
    end
    endtask

    // ----------------------------------------------------------
    // Programme principal
    // ----------------------------------------------------------
    integer i;

    initial begin
        // Init
        rst       = 1;
        rx_tvalid = 0;
        rx_tdata  = 0;
        rx_tlast  = 0;
        rx_tuser  = 0;
        tx_tready = 1;
        out_count = 0;
        err_count = 0;

        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);

        // -------------------------------------------------------
        // Construction trame Ethernet RX (20 octets)
        // -------------------------------------------------------
        //  Dest MAC  : FF:FF:FF:FF:FF:FF
        frame_in[0]  = 8'hFF; frame_in[1]  = 8'hFF;
        frame_in[2]  = 8'hFF; frame_in[3]  = 8'hFF;
        frame_in[4]  = 8'hFF; frame_in[5]  = 8'hFF;
        //  Src MAC   : AA:BB:CC:DD:EE:FF
        frame_in[6]  = 8'hAA; frame_in[7]  = 8'hBB;
        frame_in[8]  = 8'hCC; frame_in[9]  = 8'hDD;
        frame_in[10] = 8'hEE; frame_in[11] = 8'hFF;
        //  EtherType : 0x88B5
        frame_in[12] = 8'h88; frame_in[13] = 8'hB5;
        //  Payload   : A1 01 02 03 04 05
        frame_in[14] = 8'h2A; frame_in[15] = 8'h01;
        frame_in[16] = 8'h02; frame_in[17] = 8'h03;
        frame_in[18] = 8'h04; frame_in[19] = 8'h05;

        frame_len = 20;

        $display("");
        $display("================================================");
        $display("  ENVOI TRAME RX (%0d octets)", frame_len);
        $display("================================================");
        send_frame(frame_len);

        // Attente fin traitement + transmission TX
        $display("");
        $display("  ... attente traitement + TX ...");
        repeat(300) @(posedge clk);

        // -------------------------------------------------------
        // Vérification trame TX reçue
        // -------------------------------------------------------
        $display("");
        $display("================================================");
        $display("  VERIFICATION TRAME TX (%0d octets captures)", out_count);
        $display("================================================");

        // Dest MAC = Src MAC de la trame RX
        check_byte( 0, 8'hAA, "DST_MAC[0]");
        check_byte( 1, 8'hBB, "DST_MAC[1]");
        check_byte( 2, 8'hCC, "DST_MAC[2]");
        check_byte( 3, 8'hDD, "DST_MAC[3]");
        check_byte( 4, 8'hEE, "DST_MAC[4]");
        check_byte( 5, 8'hFF, "DST_MAC[5]");

        // Src MAC = FPGA_MAC = 02:12:34:56:78:9A
        check_byte( 6, 8'h02, "SRC_MAC[0]");
        check_byte( 7, 8'h12, "SRC_MAC[1]");
        check_byte( 8, 8'h34, "SRC_MAC[2]");
        check_byte( 9, 8'h56, "SRC_MAC[3]");
        check_byte(10, 8'h78, "SRC_MAC[4]");
        check_byte(11, 8'h9A, "SRC_MAC[5]");

        // Payload = octets RX[12..19] + 1
        check_byte(12, 8'h89, "PAYLOAD[0]  88+1");
        check_byte(13, 8'hB6, "PAYLOAD[1]  B5+1");
        check_byte(14, 8'hA2, "PAYLOAD[2]  A1+1");
        check_byte(15, 8'h02, "PAYLOAD[3]  01+1");
        check_byte(16, 8'h03, "PAYLOAD[4]  02+1");
        check_byte(17, 8'h04, "PAYLOAD[5]  03+1");
        check_byte(18, 8'h05, "PAYLOAD[6]  04+1");
        check_byte(19, 8'h06, "PAYLOAD[7]  05+1");

        // Padding : octets 20..59 = 0x00 + 1 = 0x01
        for (i = 20; i < 60; i = i + 1)
            check_byte(i, 8'h01, "PADDING+1  ");

        // -------------------------------------------------------
        // Bilan
        // -------------------------------------------------------
        $display("");
        $display("================================================");
        if (err_count == 0)
            $display("  RESULTAT : SUCCES - 0 erreur !");
        else
            $display("  RESULTAT : ECHEC  - %0d erreur(s) detectee(s)", err_count);
        $display("================================================");
        $display("");

        $finish;
    end

endmodule