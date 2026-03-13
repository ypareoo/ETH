// ============================================================
// File: simple_ram.v  (Verilog-2001)
// Single write port (sync) + read port (async).
// Good to start; can be replaced with true dual-port BRAM later.
// ============================================================

module simple_ram #(
    parameter integer DEPTH  = 2048,
    parameter integer ADDR_W = 11
)(
    input  wire              clk,

    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [7:0]        wdata,

    input  wire [ADDR_W-1:0] raddr,
    output wire [7:0]        rdata
);
    reg [7:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we) mem[waddr] <= wdata;
    end

    assign rdata = mem[raddr];
endmodule
