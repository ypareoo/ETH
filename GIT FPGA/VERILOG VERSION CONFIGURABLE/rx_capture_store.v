// ============================================================
// File: rx_capture_store.v  (Verilog-2001)
// Captures a single RX frame into RAM (byte-wide) when allow=1.
// If allow=0 (busy), it drops the whole frame by waiting for tlast.
// Also drops on overflow (wr_ptr >= DEPTH).
// ============================================================

module rx_capture_store #(
    parameter integer DEPTH  = 2048,
    parameter integer ADDR_W = 11
)(
    input  wire              clk,
    input  wire              rst,

    input  wire              allow,   // 1=capture, 0=drop frame

    input  wire [7:0]        rx_tdata,
    input  wire              rx_tvalid,
    input  wire              rx_tlast,
    input  wire              rx_tuser,

    // RAM RX write port
    output reg               rx_we,
    output reg  [ADDR_W-1:0] rx_waddr,
    output reg  [7:0]        rx_wdata,

    output reg  [ADDR_W-1:0] rx_len,
    output reg               rx_done, // 1-cycle pulse if frame stored and valid
    output reg               rx_err,
    output reg               busy
);

    localparam [1:0]
        S_IDLE   = 2'd0,
        S_ACTIVE = 2'd1,
        S_DROP   = 2'd2;

    reg [1:0] st;
    reg [ADDR_W-1:0] wr_ptr;

    // DEPTH-1 constant for overflow check
    localparam [ADDR_W-1:0] DEPTH_M1 = (DEPTH-1);

    always @(posedge clk) begin
        if (rst) begin
            st      <= S_IDLE;
            wr_ptr  <= {ADDR_W{1'b0}};
            rx_len  <= {ADDR_W{1'b0}};
            rx_done <= 1'b0;
            rx_err  <= 1'b0;
            rx_we   <= 1'b0;
            busy    <= 1'b0;
        end else begin
            rx_done <= 1'b0;
            rx_we   <= 1'b0;

            case (st)
                S_IDLE: begin
                    busy   <= 1'b0;
                    wr_ptr <= {ADDR_W{1'b0}};
                    rx_err <= 1'b0;

                    if (rx_tvalid) begin
                        if (!allow) begin
                            // drop complete frame
                            busy <= 1'b1;
                            st   <= S_DROP;
                            if (rx_tlast) st <= S_IDLE;
                        end else begin
                            // capture first byte
                            busy     <= 1'b1;
                            rx_we    <= 1'b1;
                            rx_waddr <= {ADDR_W{1'b0}};
                            rx_wdata <= rx_tdata;

                            wr_ptr <= {{(ADDR_W-1){1'b0}},1'b1}; // 1

                            if (rx_tlast) begin
                                rx_err  <= rx_tuser;
                                rx_len  <= {{(ADDR_W-1){1'b0}},1'b1}; // 1
                                rx_done <= ~rx_tuser;
                                st      <= S_IDLE;
                            end else begin
                                st <= S_ACTIVE;
                            end
                        end
                    end
                end

                S_ACTIVE: begin
                    busy <= 1'b1;

                    if (rx_tvalid) begin
                        // overflow -> drop remaining
                        if (wr_ptr > DEPTH_M1) begin
                            rx_err <= 1'b1;
                            st     <= S_DROP;
                        end else begin
                            rx_we    <= 1'b1;
                            rx_waddr <= wr_ptr;
                            rx_wdata <= rx_tdata;

                            wr_ptr <= wr_ptr + 1'b1;

                            if (rx_tlast) begin
                                rx_err  <= rx_tuser;
                                rx_len  <= wr_ptr + 1'b1;
                                rx_done <= ~rx_tuser;
                                st      <= S_IDLE;
                            end
                        end
                    end
                end

                S_DROP: begin
                    busy <= 1'b1;
                    // ignore bytes until end-of-frame
                    if (rx_tvalid && rx_tlast) begin
                        st <= S_IDLE;
                    end
                end

                default: begin
                    st <= S_IDLE;
                end
            endcase
        end
    end

endmodule
