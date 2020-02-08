module gemm_pe
#(
  parameter C_DATA_WIDTH = 32,
  parameter C_DIM = 4,
  parameter C_LAST_PE = 0,
  parameter C_RAM_IN_DELAY = 1,
  parameter C_RAM_OUT_DELAY = 1,
  parameter C_MAC_DELAY = 1,
  parameter C_RAM_STYLE = 1
)
(
  // PE Interface
  input                       clock,
  input                       i_reset,
  output                      o_reset,

  input [C_DATA_WIDTH-1: 0]   Ain_data,
  input [C_DATA_WIDTH-1: 0]   Bin_data,
  input                       Ain_valid,
  input                       Bin_valid,
  output [C_DATA_WIDTH-1: 0]  Aout_data,
  output [C_DATA_WIDTH-1: 0]  Bout_data,
  output                      Aout_valid,
  output                      Bout_valid,

  input                       i_rd_output,
  output                      o_rd_output
);

////////////////////////////////////////////////////////////////////////////////
// Wires
////////////////////////////////////////////////////////////////////////////////

// Multiply-Accumulate Connections
wire                        mac_in_valid;
wire [C_DATA_WIDTH-1: 0]    mac_Ain;
wire [C_DATA_WIDTH-1: 0]    mac_Bin;
wire [C_DATA_WIDTH-1: 0]    mac_Cin;
wire [C_DATA_WIDTH-1: 0]    mac_Cout;
wire                        mac_out_valid;

// SDP RAM
wire [$clog2(C_DIM)-1:0]    ram_raddr;
wire                        ram_ren;
wire [C_DATA_WIDTH-1: 0]    ram_rdata;
wire                        ram_rdata_vld;
wire [$clog2(C_DIM)-1:0]    ram_waddr;
wire                        ram_wen;
wire [C_DATA_WIDTH-1: 0]    ram_wdata;

////////////////////////////////////////////////////////////////////////////////
// Module Instances
////////////////////////////////////////////////////////////////////////////////

// All control logic is handled in gemm_ctrl_alt
// This structure was necessary to work in our Python generator structure
gemm_ctrl_alt
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_DIM(C_DIM),
  .C_LAST_PE(C_LAST_PE),
  .C_BRAM_DELAY(C_RAM_IN_DELAY+C_RAM_OUT_DELAY),
  .C_MAC_DELAY(C_MAC_DELAY)
) ctrl_i (
  
  .clock(clock),
  .i_reset(i_reset),
  .o_reset(o_reset),

  .Ain_data(Ain_data),
  .Bin_data(Bin_data),
  .Ain_valid(Ain_valid),
  .Bin_valid(Bin_valid),
  .Aout_data(Aout_data),
  .Bout_data(Bout_data),
  .Aout_valid(Aout_valid),
  .Bout_valid(Bout_valid),

  .i_rd_output(i_rd_output),
  .o_rd_output(o_rd_output),
 
  // MAC Connections
  .mac_in_valid(mac_in_valid),
  .mac_Ain(mac_Ain),
  .mac_Bin(mac_Bin),
  .mac_Cin(mac_Cin),
  .mac_Cout(mac_Cout),
  .mac_out_valid(mac_out_valid),

  // RAM Connections
  .ram_raddr(ram_raddr),
  .ram_ren(ram_ren),
  .ram_rdata(ram_rdata),
  .ram_rdata_vld(ram_rdata_vld),
  .ram_waddr(ram_waddr),
  .ram_wen(ram_wen),
  .ram_wdata(ram_wdata)
);

// Multiply Accumulate Engine
gemm_mac
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_DELAY(C_MAC_DELAY)
) mac_i
(
  .clock(clock),
  .A(mac_Ain),
  .B(mac_Bin),
  .Cin(mac_Cin),
  .Cout(mac_Cout),
  .in_valid(mac_in_valid),
  .out_valid(mac_out_valid)
);

// RAM to hold output values
sdp_ram
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_DEPTH(C_DIM),
  .C_IN_DELAY(C_RAM_IN_DELAY),
  .C_OUT_DELAY(C_RAM_OUT_DELAY),
  .C_RAM_STYLE(C_RAM_STYLE)
) ram_i
(
  .clock(clock),
  .raddr(ram_raddr),
  .ren(ram_ren),
  .rdata(ram_rdata),
  .rdata_vld(ram_rdata_vld),
  .waddr(ram_waddr),
  .wen(ram_wen),
  .wdata(ram_wdata)
);

endmodule
