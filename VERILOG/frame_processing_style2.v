// ============================================================
// frame_processing_style2.v - version avec bloc VHDL transmitter
//
// - Header ecrit directement en RAM_TX
// - Payload envoye octet par octet au bloc VHDL transmitter
// - Attente sur data_valid
//
// Interface VHDL attendue :
//   entity transmitter is
//     Port (
//       rst        : in  STD_LOGIC;
//       clk        : in  STD_LOGIC;
//       enable     : in  STD_LOGIC;
//       stream_in  : in  STD_LOGIC_VECTOR(7 downto 0);
//       stream_out : out STD_LOGIC_VECTOR(7 downto 0);
//       data_valid : out std_logic
//     );
// ============================================================

module frame_processing_style2 #(
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
    localparam [ADDR_W-1:0] PAYLOAD_START = 15;

    // ----------------------------------------------------------
    // FSM
    // ----------------------------------------------------------
    localparam [1:0]
        P_IDLE  = 2'd0,
        P_LOAD  = 2'd1,
        P_BUILD = 2'd2,
        P_DONE  = 2'd3;

    reg [1:0] st;
    reg [ADDR_W-1:0] i;

    // ----------------------------------------------------------
    // Stockage des champs RX
    // ----------------------------------------------------------
    reg [7:0] r_src_mac [0:5];
    reg [7:0] r_etype   [0:1];
    reg [7:0] r_payload [0:44];

    // ----------------------------------------------------------
    // Interface vers transmitter
    // ----------------------------------------------------------
    reg        txr_enable;
    reg  [7:0] txr_in;
    wire [7:0] txr_out;
    wire       txr_valid;

    reg        txr_busy;

    // ----------------------------------------------------------
    // Instance du bloc VHDL transmitter
    // ----------------------------------------------------------
    transmitter u_transmitter (
        .rst        (rst),
        .clk        (clk),
        .enable     (txr_enable),
        .stream_in  (txr_in),
        .stream_out (txr_out),
        .data_valid (txr_valid)
    );

    // ----------------------------------------------------------
    // FSM principale
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            st         <= P_IDLE;
            done       <= 1'b0;
            tx_len     <= {ADDR_W{1'b0}};
            rx_raddr   <= {ADDR_W{1'b0}};
            tx_we      <= 1'b0;
            tx_waddr   <= {ADDR_W{1'b0}};
            tx_wdata   <= 8'h00;
            i          <= {ADDR_W{1'b0}};
            txr_enable <= 1'b0;
            txr_in     <= 8'h00;
            txr_busy   <= 1'b0;
        end else begin
            done       <= 1'b0;
            tx_we      <= 1'b0;
            txr_enable <= 1'b0; // pulse 1 cycle

            case (st)

                // ----------------------------------------------
                // Attente de start
                // ----------------------------------------------
                P_IDLE: begin
                    i        <= {ADDR_W{1'b0}};
                    rx_raddr <= {ADDR_W{1'b0}};
                    txr_busy <= 1'b0;

                    if (start) begin
                        rx_raddr <= 6;
                        st       <= P_LOAD;
                    end
                end

                // ----------------------------------------------
                // Chargement depuis RAM_RX
                // ----------------------------------------------
                P_LOAD: begin
                    tx_len <= rx_len + 1'b1;

                    case (rx_raddr)
                        6  : r_src_mac[0] <= rx_rdata;
                        7  : r_src_mac[1] <= rx_rdata;
                        8  : r_src_mac[2] <= rx_rdata;
                        9  : r_src_mac[3] <= rx_rdata;
                        10 : r_src_mac[4] <= rx_rdata;
                        11 : r_src_mac[5] <= rx_rdata;
                        12 : r_etype[0]   <= rx_rdata;
                        13 : r_etype[1]   <= rx_rdata;
                        14 : r_payload[0] <= rx_rdata;
                        15 : r_payload[1] <= rx_rdata;
                        16 : r_payload[2] <= rx_rdata;
                        17 : r_payload[3] <= rx_rdata;
                        18 : r_payload[4] <= rx_rdata;
                        19 : r_payload[5] <= rx_rdata;
                        20 : r_payload[6] <= rx_rdata;
                        21 : r_payload[7] <= rx_rdata;
                        22 : r_payload[8] <= rx_rdata;
                        23 : r_payload[9] <= rx_rdata;
                        24 : r_payload[10] <= rx_rdata;
                        25 : r_payload[11] <= rx_rdata;
                        26 : r_payload[12] <= rx_rdata;
                        27 : r_payload[13] <= rx_rdata;
                        28 : r_payload[14] <= rx_rdata;
                        29 : r_payload[15] <= rx_rdata;
                        30 : r_payload[16] <= rx_rdata;
                        31 : r_payload[17] <= rx_rdata;
                        32 : r_payload[18] <= rx_rdata;
                        33 : r_payload[19] <= rx_rdata;
                        34 : r_payload[20] <= rx_rdata;
                        35 : r_payload[21] <= rx_rdata;
                        36 : r_payload[22] <= rx_rdata;
                        37 : r_payload[23] <= rx_rdata;
                        38 : r_payload[24] <= rx_rdata;
                        39 : r_payload[25] <= rx_rdata;
                        40 : r_payload[26] <= rx_rdata;
                        41 : r_payload[27] <= rx_rdata;
                        42 : r_payload[28] <= rx_rdata;
                        43 : r_payload[29] <= rx_rdata;
                        44 : r_payload[30] <= rx_rdata;
                        45 : r_payload[31] <= rx_rdata;
                        46 : r_payload[32] <= rx_rdata;
                        47 : r_payload[33] <= rx_rdata;
                        48 : r_payload[34] <= rx_rdata;
                        49 : r_payload[35] <= rx_rdata;
                        50 : r_payload[36] <= rx_rdata;
                        51 : r_payload[37] <= rx_rdata;
                        52 : r_payload[38] <= rx_rdata;
                        53 : r_payload[39] <= rx_rdata;
                        54 : r_payload[40] <= rx_rdata;
                        55 : r_payload[41] <= rx_rdata;
                        56 : r_payload[42] <= rx_rdata;
                        57 : r_payload[43] <= rx_rdata;
                        58 : r_payload[44] <= rx_rdata;
                        default: begin end
                    endcase

                    if (rx_raddr < (rx_len - 1'b1)) begin
                        rx_raddr <= rx_raddr + 1'b1;
                    end else begin
                        i        <= { {(ADDR_W-4){1'b0}}, 4'd0 };
                        txr_busy <= 1'b0;
                        st       <= P_BUILD;
                    end
                end

                // ----------------------------------------------
                // Construction TX
                // ----------------------------------------------
                P_BUILD: begin
                    if (i < PAYLOAD_START) begin
                        tx_we    <= 1'b1;
                        tx_waddr <= i;

                        case (i)
                            // Dest MAC (duplication volontaire octet 2)
                            0  : tx_wdata <= r_src_mac[0];
                            1  : tx_wdata <= r_src_mac[1];
                            2  : tx_wdata <= r_src_mac[2];
                            3  : tx_wdata <= r_src_mac[2];
                            4  : tx_wdata <= r_src_mac[3];
                            5  : tx_wdata <= r_src_mac[4];
                            6  : tx_wdata <= r_src_mac[5];

                            // Src MAC FPGA
                            7  : tx_wdata <= FPGA_MAC[47:40];
                            8  : tx_wdata <= FPGA_MAC[39:32];
                            9  : tx_wdata <= FPGA_MAC[31:24];
                            10 : tx_wdata <= FPGA_MAC[23:16];
                            11 : tx_wdata <= FPGA_MAC[15:8];
                            12 : tx_wdata <= FPGA_MAC[7:0];

                            // EtherType
                            13 : tx_wdata <= r_etype[0];
                            14 : tx_wdata <= r_etype[1];

                            default: tx_wdata <= 8'h00;
                        endcase

                        i <= i + 1'b1;
                    end else begin
                        // Payload : passage dans transmitter
                        if (!txr_busy) begin
                            txr_in     <= payload_byte(i);
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

                // ----------------------------------------------
                // Fin
                // ----------------------------------------------
                P_DONE: begin
                    done <= 1'b1;
                    st   <= P_IDLE;
                end

                default: begin
                    st <= P_IDLE;
                end
            endcase
        end
    end

    // ----------------------------------------------------------
    // Fonction : idx 15 -> r_payload[0], etc.
    // ----------------------------------------------------------
    function [7:0] payload_byte;
        input [ADDR_W-1:0] idx;
        reg [ADDR_W-1:0] p;
        begin
            p = idx - PAYLOAD_START;
            case (p)
                0  : payload_byte = r_payload[0];
                1  : payload_byte = r_payload[1];
                2  : payload_byte = r_payload[2];
                3  : payload_byte = r_payload[3];
                4  : payload_byte = r_payload[4];
                5  : payload_byte = r_payload[5];
                6  : payload_byte = r_payload[6];
                7  : payload_byte = r_payload[7];
                8  : payload_byte = r_payload[8];
                9  : payload_byte = r_payload[9];
                10 : payload_byte = r_payload[10];
                11 : payload_byte = r_payload[11];
                12 : payload_byte = r_payload[12];
                13 : payload_byte = r_payload[13];
                14 : payload_byte = r_payload[14];
                15 : payload_byte = r_payload[15];
                16 : payload_byte = r_payload[16];
                17 : payload_byte = r_payload[17];
                18 : payload_byte = r_payload[18];
                19 : payload_byte = r_payload[19];
                20 : payload_byte = r_payload[20];
                21 : payload_byte = r_payload[21];
                22 : payload_byte = r_payload[22];
                23 : payload_byte = r_payload[23];
                24 : payload_byte = r_payload[24];
                25 : payload_byte = r_payload[25];
                26 : payload_byte = r_payload[26];
                27 : payload_byte = r_payload[27];
                28 : payload_byte = r_payload[28];
                29 : payload_byte = r_payload[29];
                30 : payload_byte = r_payload[30];
                31 : payload_byte = r_payload[31];
                32 : payload_byte = r_payload[32];
                33 : payload_byte = r_payload[33];
                34 : payload_byte = r_payload[34];
                35 : payload_byte = r_payload[35];
                36 : payload_byte = r_payload[36];
                37 : payload_byte = r_payload[37];
                38 : payload_byte = r_payload[38];
                39 : payload_byte = r_payload[39];
                40 : payload_byte = r_payload[40];
                41 : payload_byte = r_payload[41];
                42 : payload_byte = r_payload[42];
                43 : payload_byte = r_payload[43];
                default: payload_byte = r_payload[44];
            endcase
        end
    endfunction

endmodule