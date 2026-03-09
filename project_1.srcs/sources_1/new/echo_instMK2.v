// ============================================================
// File: ethernet_echo.v  (Verilog-2001)
// Top that instantiates:
//  - rx_capture_store  -> writes RAM_RX (or drops frame if busy)
//  - simple_ram        -> RAM_RX
//  - frame_processing_style2 -> reads RAM_RX, builds NEW frame into RAM_TX
//  - simple_ram        -> RAM_TX
//  - tx_send_read      -> reads RAM_TX, streams to MAC
// Controller FSM is inside this module.
// ============================================================

module ethernet_echo #(
    parameter integer DEPTH  = 2048,
    parameter integer ADDR_W = 11,
    parameter [47:0]  FPGA_MAC = 48'hAA_AA_AA_AA_AA_AA
)(
    input  wire              clk,
    input  wire              rst,

    // RX stream (from MAC)
    input  wire [7:0]        rx_tdata,
    input  wire              rx_tvalid,
    input  wire              rx_tlast,
    input  wire              rx_tuser,

    // TX stream (to MAC)
    output wire [7:0]        tx_tdata,
    output wire              tx_tvalid,
    output wire              tx_tlast,
    input  wire              tx_tready
);

    // -----------------------
    // Controller FSM (Verilog-2001)
    // -----------------------
    localparam [1:0]
        C_IDLE = 2'd0,
        C_PROC = 2'd1,
        C_TX   = 2'd2;

    reg [1:0] cst;

    reg        allow_rx;
    reg        proc_start;
    reg        tx_start;

    wire [ADDR_W-1:0] rx_len_w;
    wire              rx_done_w;
    wire              rx_err_w;
    wire              rx_busy_w;

    reg  [ADDR_W-1:0] rx_len_reg;

    wire              proc_done_w;
    wire [ADDR_W-1:0] proc_tx_len_w;
    reg  [ADDR_W-1:0] tx_len_reg;

    wire              tx_done_w;

    // -----------------------
    // RAM_RX signals
    // -----------------------
    wire              ram_rx_we;
    wire [ADDR_W-1:0] ram_rx_waddr;
    wire [7:0]        ram_rx_wdata;

    wire [ADDR_W-1:0] ram_rx_raddr;
    wire [7:0]        ram_rx_rdata;

    // -----------------------
    // RAM_TX signals
    // -----------------------
    wire              ram_tx_we;
    wire [ADDR_W-1:0] ram_tx_waddr;
    wire [7:0]        ram_tx_wdata;

    wire [ADDR_W-1:0] ram_tx_raddr;
    wire [7:0]        ram_tx_rdata;

    // FSM
    always @(posedge clk) begin
        if (rst) begin
            cst        <= C_IDLE;
            allow_rx   <= 1'b1;
            proc_start <= 1'b0;
            tx_start   <= 1'b0;
            rx_len_reg <= {ADDR_W{1'b0}};
            tx_len_reg <= {ADDR_W{1'b0}};
        end else begin
            // default pulses low
            proc_start <= 1'b0;
            tx_start   <= 1'b0;

            case (cst)
                C_IDLE: begin
                    allow_rx <= 1'b1;

                    // rx_done_w is 1 when a complete valid frame was stored
                    if (rx_done_w) begin
                        allow_rx   <= 1'b0;      // start dropping new frames while processing/tx
                        rx_len_reg <= rx_len_w;  // latch RX length
                        proc_start <= 1'b1;      // 1-cycle pulse
                        cst        <= C_PROC;
                    end
                end

                C_PROC: begin
                    allow_rx <= 1'b0;

                    if (proc_done_w) begin
                        tx_len_reg <= proc_tx_len_w; // latch TX length produced
                        tx_start   <= 1'b1;          // 1-cycle pulse
                        cst        <= C_TX;
                    end
                end

                C_TX: begin
                    allow_rx <= 1'b0;

                    if (tx_done_w) begin
                        cst <= C_IDLE;
                    end
                end

                default: begin
                    cst <= C_IDLE;
                end
            endcase
        end
    end

    // -----------------------
    // RX capture -> RAM_RX
    // -----------------------
    rx_capture_store #(
        .DEPTH(DEPTH),
        .ADDR_W(ADDR_W)
    ) u_rx_capture_store (
        .clk(clk),
        .rst(rst),

        .allow(allow_rx),

        .rx_tdata(rx_tdata),
        .rx_tvalid(rx_tvalid),
        .rx_tlast(rx_tlast),
        .rx_tuser(rx_tuser),

        .rx_we(ram_rx_we),
        .rx_waddr(ram_rx_waddr),
        .rx_wdata(ram_rx_wdata),

        .rx_len(rx_len_w),
        .rx_done(rx_done_w),
        .rx_err(rx_err_w),
        .busy(rx_busy_w)
    );

    // -----------------------
    // RAM_RX
    // -----------------------
    simple_ram #(
        .DEPTH(DEPTH),
        .ADDR_W(ADDR_W)
    ) u_ram_rx (
        .clk(clk),

        .we(ram_rx_we),
        .waddr(ram_rx_waddr),
        .wdata(ram_rx_wdata),

        .raddr(ram_rx_raddr),
        .rdata(ram_rx_rdata)
    );

    // -----------------------
    // Processing Style 2 -> RAM_TX
    // -----------------------
    frame_processing_style2 #(
        .ADDR_W(ADDR_W),
        .FPGA_MAC(FPGA_MAC)
    ) u_processing (
        .clk(clk),
        .rst(rst),

        .start(proc_start),
        .rx_len(rx_len_reg),
        .done(proc_done_w),

        .tx_len(proc_tx_len_w),

        .rx_raddr(ram_rx_raddr),
        .rx_rdata(ram_rx_rdata),

        .tx_we(ram_tx_we),
        .tx_waddr(ram_tx_waddr),
        .tx_wdata(ram_tx_wdata)
    );

    // -----------------------
    // RAM_TX
    // -----------------------
    simple_ram #(
        .DEPTH(DEPTH),
        .ADDR_W(ADDR_W)
    ) u_ram_tx (
        .clk(clk),

        .we(ram_tx_we),
        .waddr(ram_tx_waddr),
        .wdata(ram_tx_wdata),

        .raddr(ram_tx_raddr),
        .rdata(ram_tx_rdata)
    );

    // -----------------------
    // TX sender from RAM_TX
    // -----------------------
    tx_send_read #(
        .ADDR_W(ADDR_W)
    ) u_tx_send (
        .clk(clk),
        .rst(rst),

        .start(tx_start),
        .tx_len(tx_len_reg),
        .done(tx_done_w),

        .tx_raddr(ram_tx_raddr),
        .tx_rdata(ram_tx_rdata),

        .tx_tdata(tx_tdata),
        .tx_tvalid(tx_tvalid),
        .tx_tlast(tx_tlast),
        .tx_tready(tx_tready)
    );

endmodule
