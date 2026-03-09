// ============================================================
// frame_processing_style2.v - SANS FILTRE (debug)
//
// Renvoie toutes les trames recues :
//   [0..5]   Dest MAC  = RX[6..11]
//   [6..11]  Src MAC   = FPGA_MAC
//   [12..13] EtherType = RX[12..13]
//   [14]     = RX[14]  (conserve tel quel)
//   [15..59] = RX[15..59] + 1
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

    localparam [ADDR_W-1:0] TX_FRAME_LEN = 60;

    localparam [1:0]
        P_IDLE  = 2'd0,
        P_LOAD  = 2'd1,
        P_BUILD = 2'd2,
        P_DONE  = 2'd3;

    reg [1:0]        st;
    reg [ADDR_W-1:0] i;

    reg [7:0] r_src_mac [0:5];
    reg [7:0] r_etype   [0:1];
    reg [7:0] r_payload [0:44];

    always @(posedge clk) begin
        if (rst) begin
            st       <= P_IDLE;
            done     <= 1'b0;
            tx_we    <= 1'b0;
            tx_len   <= 0;
            rx_raddr <= 0;
            i        <= 0;
        end else begin
            done  <= 1'b0;
            tx_we <= 1'b0;

            case (st)

                P_IDLE: begin
                    tx_len   <= TX_FRAME_LEN;
                    i        <= 0;
                    rx_raddr <= 0;
                    if (start) begin
                        rx_raddr <= 6;
                        st       <= P_LOAD;
                    end
                end

                P_LOAD: begin
                    case (rx_raddr)
                        6:  r_src_mac[0] <= rx_rdata;
                        7:  r_src_mac[1] <= rx_rdata;
                        8:  r_src_mac[2] <= rx_rdata;
                        9:  r_src_mac[3] <= rx_rdata;
                        10: r_src_mac[4] <= rx_rdata;
                        11: r_src_mac[5] <= rx_rdata;
                        12: r_etype[0]   <= rx_rdata;
                        13: r_etype[1]   <= rx_rdata;
                        14: r_payload[0] <= rx_rdata;
                        15: r_payload[1]  <= rx_rdata;
                        16: r_payload[2]  <= rx_rdata;
                        17: r_payload[3]  <= rx_rdata;
                        18: r_payload[4]  <= rx_rdata;
                        19: r_payload[5]  <= rx_rdata;
                        20: r_payload[6]  <= rx_rdata;
                        21: r_payload[7]  <= rx_rdata;
                        22: r_payload[8]  <= rx_rdata;
                        23: r_payload[9]  <= rx_rdata;
                        24: r_payload[10] <= rx_rdata;
                        25: r_payload[11] <= rx_rdata;
                        26: r_payload[12] <= rx_rdata;
                        27: r_payload[13] <= rx_rdata;
                        28: r_payload[14] <= rx_rdata;
                        29: r_payload[15] <= rx_rdata;
                        30: r_payload[16] <= rx_rdata;
                        31: r_payload[17] <= rx_rdata;
                        32: r_payload[18] <= rx_rdata;
                        33: r_payload[19] <= rx_rdata;
                        34: r_payload[20] <= rx_rdata;
                        35: r_payload[21] <= rx_rdata;
                        36: r_payload[22] <= rx_rdata;
                        37: r_payload[23] <= rx_rdata;
                        38: r_payload[24] <= rx_rdata;
                        39: r_payload[25] <= rx_rdata;
                        40: r_payload[26] <= rx_rdata;
                        41: r_payload[27] <= rx_rdata;
                        42: r_payload[28] <= rx_rdata;
                        43: r_payload[29] <= rx_rdata;
                        44: r_payload[30] <= rx_rdata;
                        45: r_payload[31] <= rx_rdata;
                        46: r_payload[32] <= rx_rdata;
                        47: r_payload[33] <= rx_rdata;
                        48: r_payload[34] <= rx_rdata;
                        49: r_payload[35] <= rx_rdata;
                        50: r_payload[36] <= rx_rdata;
                        51: r_payload[37] <= rx_rdata;
                        52: r_payload[38] <= rx_rdata;
                        53: r_payload[39] <= rx_rdata;
                        54: r_payload[40] <= rx_rdata;
                        55: r_payload[41] <= rx_rdata;
                        56: r_payload[42] <= rx_rdata;
                        57: r_payload[43] <= rx_rdata;
                        58: r_payload[44] <= rx_rdata;
                    endcase

                    if (rx_raddr < 58)
                        rx_raddr <= rx_raddr + 1;
                    else begin
                        i  <= 0;
                        st <= P_BUILD;
                    end
                end

                P_BUILD: begin
                    tx_we    <= 1'b1;
                    tx_waddr <= i;

                    case (i)
                        0:  tx_wdata <= r_src_mac[0];
                        1:  tx_wdata <= r_src_mac[1];
                        2:  tx_wdata <= r_src_mac[2];
                        3:  tx_wdata <= r_src_mac[3];
                        4:  tx_wdata <= r_src_mac[4];
                        5:  tx_wdata <= r_src_mac[5];
                        6:  tx_wdata <= FPGA_MAC[47:40];
                        7:  tx_wdata <= FPGA_MAC[39:32];
                        8:  tx_wdata <= FPGA_MAC[31:24];
                        9:  tx_wdata <= FPGA_MAC[23:16];
                        10: tx_wdata <= FPGA_MAC[15:8];
                        11: tx_wdata <= FPGA_MAC[7:0];
                        12: tx_wdata <= r_etype[0];
                        13: tx_wdata <= r_etype[1];
                        14: tx_wdata <= r_payload[0];        // conserve tel quel
                        15: tx_wdata <= r_payload[1]  + 1;
                        16: tx_wdata <= r_payload[2]  + 1;
                        17: tx_wdata <= r_payload[3]  + 1;
                        18: tx_wdata <= r_payload[4]  + 1;
                        19: tx_wdata <= r_payload[5]  + 1;
                        20: tx_wdata <= r_payload[6]  + 1;
                        21: tx_wdata <= r_payload[7]  + 1;
                        22: tx_wdata <= r_payload[8]  + 1;
                        23: tx_wdata <= r_payload[9]  + 1;
                        24: tx_wdata <= r_payload[10] + 1;
                        25: tx_wdata <= r_payload[11] + 1;
                        26: tx_wdata <= r_payload[12] + 1;
                        27: tx_wdata <= r_payload[13] + 1;
                        28: tx_wdata <= r_payload[14] + 1;
                        29: tx_wdata <= r_payload[15] + 1;
                        30: tx_wdata <= r_payload[16] + 1;
                        31: tx_wdata <= r_payload[17] + 1;
                        32: tx_wdata <= r_payload[18] + 1;
                        33: tx_wdata <= r_payload[19] + 1;
                        34: tx_wdata <= r_payload[20] + 1;
                        35: tx_wdata <= r_payload[21] + 1;
                        36: tx_wdata <= r_payload[22] + 1;
                        37: tx_wdata <= r_payload[23] + 1;
                        38: tx_wdata <= r_payload[24] + 1;
                        39: tx_wdata <= r_payload[25] + 1;
                        40: tx_wdata <= r_payload[26] + 1;
                        41: tx_wdata <= r_payload[27] + 1;
                        42: tx_wdata <= r_payload[28] + 1;
                        43: tx_wdata <= r_payload[29] + 1;
                        44: tx_wdata <= r_payload[30] + 1;
                        45: tx_wdata <= r_payload[31] + 1;
                        46: tx_wdata <= r_payload[32] + 1;
                        47: tx_wdata <= r_payload[33] + 1;
                        48: tx_wdata <= r_payload[34] + 1;
                        49: tx_wdata <= r_payload[35] + 1;
                        50: tx_wdata <= r_payload[36] + 1;
                        51: tx_wdata <= r_payload[37] + 1;
                        52: tx_wdata <= r_payload[38] + 1;
                        53: tx_wdata <= r_payload[39] + 1;
                        54: tx_wdata <= r_payload[40] + 1;
                        55: tx_wdata <= r_payload[41] + 1;
                        56: tx_wdata <= r_payload[42] + 1;
                        57: tx_wdata <= r_payload[43] + 1;
                        default: tx_wdata <= r_payload[44] + 1;
                    endcase

                    if (i == TX_FRAME_LEN - 1)
                        st <= P_DONE;
                    else
                        i <= i + 1;
                end

                P_DONE: begin
                    done <= 1'b1;
                    st   <= P_IDLE;
                end

            endcase
        end
    end

endmodule