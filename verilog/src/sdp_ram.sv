module sdp_ram
// C_DEPTH is the number of elements the memory holds
#(
  parameter C_DATA_WIDTH = 32,
  parameter C_DEPTH = 4,
  parameter C_IN_DELAY = 0,
  parameter C_OUT_DELAY = 1,
  parameter C_RAM_STYLE = 0
)
(
  input                       clock,
  input [$clog2(C_DEPTH)-1:0] raddr,
  input                       ren,
  output [C_DATA_WIDTH-1: 0]  rdata,
  output                      rdata_vld,
  input [$clog2(C_DEPTH)-1:0] waddr,
  input                       wen,
  input [C_DATA_WIDTH-1: 0]   wdata
);

reg [$clog2(C_DEPTH)-1: 0] r_idx;

wire [C_DATA_WIDTH-1: 0] w_wdata;
wire                     w_wen;
wire [$clog2(C_DEPTH)-1: 0] w_raddr;
wire [$clog2(C_DEPTH)-1: 0] w_waddr;
wire [C_DATA_WIDTH-1: 0] w_rdata;

delaychain
#(
  .C_DATA_WIDTH($clog2(C_DEPTH)),
  .C_LENGTH(C_IN_DELAY)
) waddr_dly (
  .clock(clock),
  .in(waddr),
  .out(w_waddr)
);

delaychain
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_LENGTH(C_IN_DELAY)
) wdata_dly (
  .clock(clock),
  .in(wdata),
  .out(w_wdata)
);

delaychain
#(
  .C_DATA_WIDTH(1),
  .C_LENGTH(C_IN_DELAY)
) wen_dly (
  .clock(clock),
  .in(wen),
  .out(w_wen)
);

// TODO: More clean way to do local parameterization of ram style
generate
if (C_RAM_STYLE == 1)
begin : bram_mem
  (* ram_style = "block" *) reg [C_DATA_WIDTH-1: 0] m_ram [C_DEPTH-1:0];
  // Write Logic
  always @(posedge clock)
  begin
    if (w_wen)
      m_ram[w_waddr] <= w_wdata;
  end
  // Read Logic
  assign w_rdata = m_ram[w_raddr];
end
else if (C_RAM_STYLE == 2)
begin : dist_mem
  (* ram_style = "distributed" *) reg [C_DATA_WIDTH-1: 0] m_ram [C_DEPTH-1:0];
  // Write Logic
  always @(posedge clock)
  begin
    if (w_wen)
      m_ram[w_waddr] <= w_wdata;
  end
  // Read Logic
  assign w_rdata = m_ram[w_raddr];
end
else
begin : auto_mem
  reg [C_DATA_WIDTH-1: 0] m_ram [C_DEPTH-1:0];
  // Write Logic
  always @(posedge clock)
  begin
    if (w_wen)
      m_ram[w_waddr] <= w_wdata;
  end
  // Read Logic
  assign w_rdata = m_ram[w_raddr];
end
endgenerate

delaychain
#(
  .C_DATA_WIDTH($clog2(C_DEPTH)),
  .C_LENGTH(C_IN_DELAY)
) raddr_dly (
  .clock(clock),
  .in(raddr),
  .out(w_raddr)
);

delaychain
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_LENGTH(C_OUT_DELAY)
) rdata_dly (
  .clock(clock),
  .in(w_rdata),
  .out(rdata)
);

delaychain
#(
  .C_DATA_WIDTH(1),
  .C_LENGTH(C_IN_DELAY+C_OUT_DELAY)
) ren_dly (
  .clock(clock),
  .in(ren),
  .out(rdata_vld)
);
endmodule

