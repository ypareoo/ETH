// ============================================================
// frame_processing_v3.v
//
// Basé sur frame_processing_style2.v (version fonctionnelle)
// Modifications minimales :
//
//  [CLEAN 1] P_LOAD : case à 53 lignes remplacé par offset calculé
//  [CLEAN 2] payload_byte() supprimée -> accès direct r_payload[i - PAYLOAD_START]
//  [CLEAN 3] Payload dynamique : r_payload dimensionné au max, borné par rx_len
//  [FIX 1]   EtherType octet 1 : écrit à i=14 dans le header (PAYLOAD_START = 15)
// ============================================================

module frame_processing_v3 #(
    parameter integer ADDR_W   = 11,
    parameter [47:0]  FPGA_MAC = 48'hAA_AA_AA_AA_AA_AA
)(
    input  wire              clk,
    input  wire              rst,

    input  wire              start,
    input  wire [ADDR_W-1:0] rx_len,
    output reg               done,

    output reg  [ADDR_W-1:0] tx_len,

    // RAM_RX read port
    output reg  [ADDR_W-1:0] rx_raddr,
    input  wire [7:0]        rx_rdata,

    // RAM_TX write port
    output reg               tx_we,
    output reg  [ADDR_W-1:0] tx_waddr,
    output reg  [7:0]        tx_wdata
);

    // ----------------------------------------------------------
    // Constantes
    // ----------------------------------------------------------
    localparam [ADDR_W-1:0] RX_SRC_MAC_START = 6;
    localparam [ADDR_W-1:0] RX_PAYLOAD_START = 15;  // octet 14 = etype[1], payload dès 15

    // [FIX 1] PAYLOAD_START = 15 : les octets 0-14 sont le header complet
    //         (0-5 dst MAC, 6-12 src MAC+FPGA, 13 etype[0], 14 etype[1])
    localparam [ADDR_W-1:0] PAYLOAD_START = 15;

    // [CLEAN 3] Buffer dimensionné au maximum théorique
    localparam integer MAX_PAYLOAD = (2**ADDR_W) - 15;

    // ----------------------------------------------------------
    // FSM (identique à style2)
    // ----------------------------------------------------------
    localparam [2:0]
        P_IDLE    = 3'd0,
        P_RST_TXR = 3'd1,
        P_LOAD    = 3'd2,
        P_BUILD   = 3'd3,
        P_DONE    = 3'd4;

    reg [2:0]        st;
    reg [ADDR_W-1:0] i;
    reg [1:0]        rst_cnt;

    // ----------------------------------------------------------
    // Stockage des champs RX
    // ----------------------------------------------------------
    reg [7:0] r_src_mac [0:5];
    reg [7:0] r_etype   [0:1];

    // [CLEAN 3] Tableau dynamique, plus de taille fixe à 44
    reg [7:0] r_payload [0:MAX_PAYLOAD-1];

    // ----------------------------------------------------------
    // Interface vers transmitter (identique à style2)
    // ----------------------------------------------------------
    reg        rst_transmitter;
    reg        txr_enable;
    reg  [7:0] txr_in;
    wire [7:0] txr_out;
    wire       txr_valid;
    reg        txr_busy;

    // ----------------------------------------------------------
    // Instance transmitter (inchangée)
    // ----------------------------------------------------------
    transmitter_easy u_transmitter (
        .rst        (rst_transmitter),
        .clk        (clk),
        .enable     (txr_enable),
        .stream_in  (txr_in),
        .stream_out (txr_out),
        .data_valid (txr_valid)
    );

    // ----------------------------------------------------------
    // FSM principale (structure identique à style2)
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            st              <= P_IDLE;
            done            <= 1'b0;
            tx_len          <= {ADDR_W{1'b0}};
            rx_raddr        <= {ADDR_W{1'b0}};
            tx_we           <= 1'b0;
            tx_waddr        <= {ADDR_W{1'b0}};
            tx_wdata        <= 8'h00;
            i               <= {ADDR_W{1'b0}};
            txr_enable      <= 1'b0;
            txr_in          <= 8'h00;
            txr_busy        <= 1'b0;
            rst_transmitter <= 1'b1;
            rst_cnt         <= 2'd0;
        end else begin
            done       <= 1'b0;
            tx_we      <= 1'b0;
            txr_enable <= 1'b0;

            case (st)

                // ------------------------------------------
                // Attente de start (identique à style2)
                // ------------------------------------------
                P_IDLE: begin
                    rst_transmitter <= 1'b0;
                    rst_cnt         <= 2'd0;
                    i               <= {ADDR_W{1'b0}};
                    rx_raddr        <= {ADDR_W{1'b0}};
                    txr_busy        <= 1'b0;

                    if (start) begin
                        rst_transmitter <= 1'b1;
                        rst_cnt         <= 2'd0;
                        st              <= P_RST_TXR;
                    end
                end

                // ------------------------------------------
                // Reset transmitter (identique à style2)
                // ------------------------------------------
                P_RST_TXR: begin
                    rst_transmitter <= 1'b1;
                    txr_enable      <= 1'b0;
                    txr_busy        <= 1'b0;

                    if (rst_cnt == 2'd1) begin
                        rst_transmitter <= 1'b0;
                        rx_raddr        <= RX_SRC_MAC_START;
                        tx_len          <= rx_len;
                        st              <= P_LOAD;
                    end else begin
                        rst_cnt <= rst_cnt + 1'b1;
                    end
                end

                // ------------------------------------------
                // Chargement RAM_RX
                // [CLEAN 1] offset calculé, plus de case à 53 lignes
                // ------------------------------------------
                P_LOAD: begin
                    rst_transmitter <= 1'b0;

                    // Src MAC : octets 6 à 11
                    if (rx_raddr >= RX_SRC_MAC_START && rx_raddr <= RX_SRC_MAC_START + 5)
                        r_src_mac[rx_raddr - RX_SRC_MAC_START] <= rx_rdata;

                    // EtherType : octets 12 et 13
                    if (rx_raddr == 12) r_etype[0] <= rx_rdata;
                    if (rx_raddr == 13) r_etype[1] <= rx_rdata;

                    // [CLEAN 3] Payload : octet 14+ stocké dynamiquement
                    if (rx_raddr >= RX_PAYLOAD_START)
                        r_payload[rx_raddr - RX_PAYLOAD_START] <= rx_rdata;

                    if (rx_raddr < (rx_len - 1'b1)) begin
                        rx_raddr <= rx_raddr + 1'b1;
                    end else begin
                        i        <= {ADDR_W{1'b0}};
                        txr_busy <= 1'b0;
                        st       <= P_BUILD;
                    end
                end

                // ------------------------------------------
                // Construction TX
                // ------------------------------------------
                P_BUILD: begin
                    rst_transmitter <= 1'b0;

                    if (i < PAYLOAD_START) begin
                        // Header : octets 0 à 14 inclus
                        tx_we    <= 1'b1;
                        tx_waddr <= i;

                        case (i)
                            // Dest MAC = src MAC reçue
                            0  : tx_wdata <= r_src_mac[0];
                            1  : tx_wdata <= r_src_mac[1];
                            2  : tx_wdata <= r_src_mac[2];
                            3  : tx_wdata <= r_src_mac[2];  // duplication octet 2 originale
                            4  : tx_wdata <= r_src_mac[3];
                            5  : tx_wdata <= r_src_mac[4];
                            6  : tx_wdata <= r_src_mac[5];
                            // Src MAC = FPGA
                            7  : tx_wdata <= FPGA_MAC[47:40];
                            8  : tx_wdata <= FPGA_MAC[39:32];
                            9  : tx_wdata <= FPGA_MAC[31:24];
                            10 : tx_wdata <= FPGA_MAC[23:16];
                            11 : tx_wdata <= FPGA_MAC[15:8];
                            12 : tx_wdata <= FPGA_MAC[7:0];
                            // EtherType
                            13 : tx_wdata <= r_etype[0];
                            14 : tx_wdata <= r_etype[1];  // [FIX 1] bien dans le header
                            default: tx_wdata <= 8'h00;
                        endcase

                        i <= i + 1'b1;

                    end else begin
                        // Payload : logique identique à style2
                        // [CLEAN 2] accès direct r_payload[i - PAYLOAD_START]
                        //           à la place de payload_byte(i)
                        if (!txr_busy) begin
                            txr_in     <= r_payload[i - PAYLOAD_START];
                            txr_enable <= 1'b1;
                            txr_busy   <= 1'b1;
                        end else begin
                            if (txr_valid) begin
                                tx_we    <= 1'b1;
                                tx_waddr <= i;
                                tx_wdata <= txr_out;
                                txr_busy <= 1'b0;

                                if (i == (tx_len - 1'b1)) begin
                                    st <= P_DONE;
                                end else begin
                                    i <= i + 1'b1;
                                end
                            end
                        end
                    end
                end

                // ------------------------------------------
                // Fin (identique à style2)
                // ------------------------------------------
                P_DONE: begin
                    rst_transmitter <= 1'b0;
                    done            <= 1'b1;
                    st              <= P_IDLE;
                end

                default: begin
                    rst_transmitter <= 1'b0;
                    st <= P_IDLE;
                end

            endcase
        end
    end

endmodule