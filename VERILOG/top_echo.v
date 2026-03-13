`timescale 1 ns / 1 ps

module top_echo
(
    input             clk_100,
    input             cpu_rst_n,
    
    // Interface Ethernet Physique
    output            eth_mdc,
    inout             eth_mdio,
    output            eth_rstn,
    inout             eth_crsdv,
    inout             eth_rxerr,
    inout  [1:0]      eth_rxd,
    output            eth_txen,
    output [1:0]      eth_txd,
    output            eth_clkin,
    inout             eth_intn,
    
    // Interface Utilisateur
    input      [15:0] sw,
    output reg [15:0] led,
    input             btnu
);

    // --- G�n�ration d'horloge ( inchang� ) ---
    wire clk_mac; // Horloge Logique
    wire clk_phy; // Horloge 50MHz RMII
    wire clk_fb;
    wire pll_locked;
    
    PLLE2_BASE#
    (
        .CLKFBOUT_MULT (10),
        .CLKOUT0_DIVIDE(20),
        .CLKOUT1_DIVIDE(20),
        .CLKOUT1_PHASE (45.0),
        .CLKIN1_PERIOD (10.0)
    )
    clk_gen 
    (
        .CLKOUT0 (clk_mac),
        .CLKOUT1 (clk_phy),
        .CLKFBOUT(clk_fb),
        .LOCKED  (pll_locked),
        .CLKIN1  (clk_100),
        .RST     (1'b0),
        .CLKFBIN (clk_fb)
    );
    
    // --- Gestion du Reset ( inchang� ) ---
    reg        rst_n         = 0;
    reg [15:0] rst_n_counter = 0;
    always @(posedge clk_mac) begin
        rst_n         <= (rst_n || &rst_n_counter) && pll_locked && cpu_rst_n;
        rst_n_counter <= rst_n ? 0 : rst_n_counter + 1;
    end
    
    // --- Signaux AXI Stream (RX) ---
    wire [7:0] rx_axis_mac_tdata;
    wire       rx_axis_mac_tvalid;
    wire       rx_axis_mac_tlast;
    wire       rx_axis_mac_tuser;
    
    // --- Signaux AXI Stream (TX) ---
    wire [7:0] tx_axis_mac_tdata;
    wire       tx_axis_mac_tvalid;
    wire       tx_axis_mac_tlast;
    wire       tx_axis_mac_tready;

    // --- Signaux de gestion Registres MDIO ( inchang� ) ---
    reg        reg_vld = 0;
    reg  [4:0] reg_addr;
    reg        reg_write;
    reg [15:0] reg_wval;
    wire [15:0] reg_rval;
    wire        reg_ack;

    // =========================================================================
    // 1. Instance du MAC (Avec les DEUX horloges)
    // =========================================================================
    eth_mac#(1) mac_inst
    (
        // Horloges & Reset
        .clk_mac    (clk_mac),  // Horloge logique
        .clk_phy    (clk_phy),  // Horloge RMII
        .rst_n      (rst_n),
        .mode_straps(3'b111),
    
        // Interface Physique (Pins FPGA)
        .eth_mdc  (eth_mdc),
        .eth_mdio (eth_mdio),
        .eth_rstn (eth_rstn),
        .eth_crsdv(eth_crsdv),
        .eth_rxerr(eth_rxerr),
        .eth_rxd  (eth_rxd),
        .eth_txen (eth_txen),
        .eth_txd  (eth_txd),
        .eth_clkin(eth_clkin),
        .eth_intn (eth_intn),
        
        // Interface AXI RX (Sorties du MAC -> Vers Echo)
        .rx_axis_mac_tdata (rx_axis_mac_tdata),
        .rx_axis_mac_tvalid(rx_axis_mac_tvalid),
        .rx_axis_mac_tlast (rx_axis_mac_tlast),
        .rx_axis_mac_tuser (rx_axis_mac_tuser),
        
        // Interface AXI TX (Entr�es du MAC <- Venant de Echo)
        .tx_axis_mac_tdata (tx_axis_mac_tdata),
        .tx_axis_mac_tvalid(tx_axis_mac_tvalid),
        .tx_axis_mac_tlast (tx_axis_mac_tlast),
        .tx_axis_mac_tready(tx_axis_mac_tready),
        
        // Interface Registres
        .reg_vld  (reg_vld),
        .reg_addr (reg_addr),
        .reg_write(reg_write),
        .reg_wval (reg_wval),
        .reg_rval (reg_rval),
        .reg_ack  (reg_ack)
    );

    // =========================================================================
    // 2. Instance de l'Echo (Remplace la logique du bouton)
    // =========================================================================
    
    ethernet_echo_axis echo_inst (
        .clk        (clk_mac),  // Utilise l'horloge logique du MAC
        .rst_n      (rst_n),
        
        // RX (On �coute ce que le MAC re�oit)
        .rx_tdata   (rx_axis_mac_tdata),
        .rx_tvalid  (rx_axis_mac_tvalid),
        .rx_tlast   (rx_axis_mac_tlast),
        .rx_tuser   (rx_axis_mac_tuser),
        
        // TX (On envoie des donn�es au MAC)
        .tx_tready  (tx_axis_mac_tready),
        .tx_tdata   (tx_axis_mac_tdata),
        .tx_tvalid  (tx_axis_mac_tvalid),
        .tx_tlast   (tx_axis_mac_tlast)
    );

    // =========================================================================
    // 3. Logique de contr�le des registres (LEDs/Switches) (inchang�)
    // =========================================================================
    
    localparam STATE_RST       = 0;
    localparam STATE_IDLE      = 1;
    localparam STATE_CHECK_REG = 2;
    
    reg [2:0]  state, next_state;
    reg [15:0] next_led;
    reg [20:0] count = 0;
    
    always @(posedge clk_mac) begin
        state <= rst_n ? next_state : STATE_RST;
        led   <= next_led;
        count <= count + 1;
    end
    
    always @* begin
        next_state = state;
        next_led   = led;
        reg_vld    = 0;
        reg_write  = 0;
        reg_addr   = 0;
        reg_wval   = 0;
        
        case(state)
            STATE_RST: begin
                next_state = STATE_IDLE;
            end STATE_IDLE: begin
                if(&count)
                    next_state = STATE_CHECK_REG;
            end STATE_CHECK_REG: begin
                reg_vld  = 1;
                reg_addr = sw[4:0]; // Petit fix: cast sw pour �viter warning
                if(reg_ack) begin
                    next_state = STATE_IDLE;
                    next_led   = reg_rval;
                end
            end
        endcase
    end

endmodule