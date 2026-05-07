`timescale 1ns / 1ps

module tb_ethernet_echo;

    reg clk;
    reg rst;

    reg  [7:0] rx_tdata;
    reg        rx_tvalid;
    reg        rx_tlast;
    reg        rx_tuser;

    wire [7:0] tx_tdata;
    wire       tx_tvalid;
    wire       tx_tlast;
    reg        tx_tready;

    integer i;
    integer tx_count;
    integer frame_no;

    // ----------------------------------------------------------
    // DUT
    // ----------------------------------------------------------
    ethernet_echo dut (
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
    // Clock
    // ----------------------------------------------------------
    always #5 clk = ~clk;

    // ----------------------------------------------------------
    // Envoi d'une trame :
    // header Ethernet + payload = A1 puis 25 fois AA
    // ----------------------------------------------------------
    task send_frame_AA;
        begin
            $display("");
            $display("====================================");
            $display("Envoi d une trame");
            $display("Payload : A1 puis 25 fois AA");
            $display("====================================");

            // Dest MAC
            send_byte(8'hFF, 1'b0);
            send_byte(8'hFF, 1'b0);
            send_byte(8'hFF, 1'b0);
            send_byte(8'hFF, 1'b0);
            send_byte(8'hFF, 1'b0);
            send_byte(8'hFF, 1'b0);

            // Src MAC
            send_byte(8'hAA, 1'b0);
            send_byte(8'hBB, 1'b0);
            send_byte(8'hCC, 1'b0);
            send_byte(8'hDD, 1'b0);
            send_byte(8'hEE, 1'b0);
            send_byte(8'hFF, 1'b0);

            // EtherType
            send_byte(8'h88, 1'b0);
            send_byte(8'hB5, 1'b0);

            // Payload
            send_byte(8'hAA, 1'b0);

            for (i = 0; i < 24; i = i + 1) begin
                send_byte(8'hAA, 1'b0);
            end

            send_byte(8'hAA, 1'b1);

            // retour au repos
            @(posedge clk);
            rx_tvalid <= 1'b0;
            rx_tlast  <= 1'b0;
            rx_tdata  <= 8'h00;
            rx_tuser  <= 1'b0;

            // pause entre deux trames
            repeat(200) @(posedge clk);
        end
    endtask

    // ----------------------------------------------------------
    // Envoi d'un octet sur RX AXIS
    // ----------------------------------------------------------
    task send_byte;
        input [7:0] data;
        input       last;
        begin
            @(posedge clk);
            rx_tdata  <= data;
            rx_tvalid <= 1'b1;
            rx_tlast  <= last;
            rx_tuser  <= 1'b0;
        end
    endtask

    // ----------------------------------------------------------
    // Affichage très simple de la sortie TX
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (tx_tvalid && tx_tready) begin
            $display("TX frame=%0d byte=%0d data=%02x last=%b time=%0t",
                     frame_no, tx_count, tx_tdata, tx_tlast, $time);
            tx_count = tx_count + 1;

            if (tx_tlast) begin
                $display("---- fin trame TX %0d ----", frame_no);
                frame_no = frame_no + 1;
                tx_count = 0;
            end
        end
    end

    // ----------------------------------------------------------
    // Stimulus principal
    // ----------------------------------------------------------
    initial begin
        clk      = 0;
        rst      = 1;
        rx_tdata = 8'h00;
        rx_tvalid= 1'b0;
        rx_tlast = 1'b0;
        rx_tuser = 1'b0;
        tx_tready= 1'b1;

        tx_count = 0;
        frame_no = 1;

        // reset
        repeat(10) @(posedge clk);
        rst = 0;

        // attente
        repeat(20) @(posedge clk);

        // 3 trames
        send_frame_AA();
        send_frame_AA();
        send_frame_AA();

        // attendre longtemps
        repeat(5000) @(posedge clk);

        $stop;
    end

endmodule
