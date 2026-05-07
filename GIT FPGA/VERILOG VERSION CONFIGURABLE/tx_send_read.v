// ============================================================
// tx_send_read.v - VERSION ULTRA SIMPLE
//
// Lit la RAM TX octet par octet et envoie sur AXI-Stream.
// RAM async : tx_rdata = mem[tx_raddr] immediatement.
//
// Timeline :
//   T_IDLE   : tx_raddr=0, tx_tvalid=0
//   T_SEND   : chaque cycle, si tready=1 :
//                - envoie tx_rdata sur tx_tdata
//                - incremente tx_raddr
//              quand rd_ptr == tx_len-1 : done=1
// ============================================================

module tx_send_read #(
    parameter integer ADDR_W = 11
)(
    input  wire              clk,
    input  wire              rst,

    input  wire              start,
    input  wire [ADDR_W-1:0] tx_len,
    output reg               done,

    // RAM_TX read port (async)
    output reg  [ADDR_W-1:0] tx_raddr,
    input  wire [7:0]        tx_rdata,

    // TX AXI-Stream
    output reg  [7:0]        tx_tdata,
    output reg               tx_tvalid,
    output reg               tx_tlast,
    input  wire              tx_tready
);

    localparam T_IDLE = 1'b0;
    localparam T_SEND = 1'b1;

    reg               st;
    reg [ADDR_W-1:0]  rd_ptr;

    always @(posedge clk) begin
        if (rst) begin
            st        <= T_IDLE;
            done      <= 1'b0;
            tx_raddr  <= {ADDR_W{1'b0}};
            rd_ptr    <= {ADDR_W{1'b0}};
            tx_tdata  <= 8'h00;
            tx_tvalid <= 1'b0;
            tx_tlast  <= 1'b0;
        end else begin
            done <= 1'b0;

            case (st)

                T_IDLE: begin
                    tx_tvalid <= 1'b0;
                    tx_tlast  <= 1'b0;
                    rd_ptr    <= {ADDR_W{1'b0}};
                    tx_raddr  <= {ADDR_W{1'b0}};

                    if (start)
                        st <= T_SEND;
                end

                T_SEND: begin
                    // RAM async : tx_rdata = mem[tx_raddr] est deja stable
                    tx_tdata  <= tx_rdata;
                    tx_tvalid <= 1'b1;
                    tx_tlast  <= (rd_ptr == tx_len - 1'b1);

                    if (tx_tready) begin
                        if (rd_ptr == tx_len - 1'b1) begin
                            // dernier octet
                            tx_tvalid <= 1'b0;
                            tx_tlast  <= 1'b0;
                            done      <= 1'b1;
                            st        <= T_IDLE;
                        end else begin
                            rd_ptr   <= rd_ptr + 1'b1;
                            tx_raddr <= rd_ptr + 1'b1;
                        end
                    end
                end

            endcase
        end
    end

endmodule