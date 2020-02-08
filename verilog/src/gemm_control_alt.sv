// Single PE for the 1-D Systolic Matrix Multiplication Array
// Note that total delay must be less than C_DIM
module gemm_ctrl_alt
#(
  parameter C_DATA_WIDTH = 32,
  parameter C_DIM = 4,
  parameter C_LAST_PE = 0,
  parameter C_BRAM_DELAY = 1,
  parameter C_MAC_DELAY = 1
)
(
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
  output                      o_rd_output,
  // MAC
  output                      mac_in_valid,
  output [C_DATA_WIDTH-1: 0]  mac_Ain,
  output [C_DATA_WIDTH-1: 0]  mac_Bin,
  output [C_DATA_WIDTH-1: 0]  mac_Cin,
  input [C_DATA_WIDTH-1: 0]   mac_Cout,
  input                       mac_out_valid,

  // SDP RAM
  output [$clog2(C_DIM)-1:0]    ram_raddr,
  output                        ram_ren,
  input  [C_DATA_WIDTH-1: 0]    ram_rdata,
  input                         ram_rdata_vld,
  output [$clog2(C_DIM)-1:0]    ram_waddr,
  output                        ram_wen,
  output [C_DATA_WIDTH-1: 0]    ram_wdata
);

// I/O Buffers
reg [C_DATA_WIDTH-1: 0] r_Ain_data;
reg [C_DATA_WIDTH-1: 0] r_Bin_data;
reg                     r_Ain_valid;
reg                     r_Bin_valid;
reg                     r_reset;
reg                     r_rd_output;
reg                     r_first_valid;

// Registers to hold values of B to compute with 
reg                     B_sav_idx;      // B register to write to
reg [C_DATA_WIDTH-1: 0] B_saved [1:0];
// r_bvalid_cnt determins which register to be written to next
reg [$clog2(C_DIM): 0]  r_bvalid_cnt;

reg                     B_wrk_idx;      // B register to read from

reg [$clog2(2*C_DIM*C_DIM + C_DIM): 0] r_valid_cnt; // Number of valid inputs
reg [$clog2(C_DIM*C_DIM): 0] r_comp_cnt;  // Number of vlaid outputs produced

// Delay chains to match input data to BRAM delay
// A, B, valid and C (from BRAM) need to line up for the MAC
wire [C_DATA_WIDTH-1: 0]  dly_Ain_data;
wire [C_DATA_WIDTH-1: 0]  dly_Bin_data;
wire                      dly_in_valid;

// Output from MAC unit
wire [C_DATA_WIDTH-1: 0]  w_mac_out;
wire                      w_mac_out_vld;

// Write datapath states
localparam WR_RESET = 2'b00,
           WR_COMPUTE = 2'b01,
           WR_CLEAR = 2'b10;
reg [1: 0] c_wr_state;
reg [1: 0] r_wr_state;

reg                       c_wen;
reg [C_DATA_WIDTH-1: 0]   c_wdata;
reg [$clog2(C_DIM)-1: 0]  r_write_addr;

// Read datapath states
localparam RD_PRELOAD = 2'b00,
           RD_COMPUTE = 2'b01,
           RD_WAIT = 2'b10,
           RD_OUTPUT = 2'b11;
reg [1: 0] c_rd_state;
reg [1: 0] r_rd_state;

reg c_ren;
reg [$clog2(C_DIM)-1: 0]  r_read_addr;
reg [$clog2(C_DIM)-1: 0]  r_rdata_vld;
wire [C_DATA_WIDTH-1: 0]  w_rdata;

////////////////////////////////////////////////////////////
// Memory to hold output values
////////////////////////////////////////////////////////////

assign ram_raddr = r_read_addr;
assign ram_ren = c_ren;
assign w_rdata = ram_rdata;
assign w_rdata_vld = ram_rdata_vld;
assign ram_waddr = r_write_addr;
assign ram_wen = c_wen;
assign ram_wdata = c_wdata;

//////////////////////////////////////////////////////////////////////
// Write Datapath
//////////////////////////////////////////////////////////////////////

always @(posedge clock)
begin
  if (r_reset)
    r_write_addr <= 'd0;
  else if (c_wen)
  begin
    if (r_write_addr == C_DIM-1)
      r_write_addr <= 'd0;
    else
      r_write_addr <= r_write_addr + 'd1;
  end
end

// Write Control Signals
always @(*)
begin
  c_wen = 1'b0;
  c_wdata = 'd0;
  case (r_wr_state)
    WR_RESET:
    begin
      c_wen = 1'b1;
      c_wdata = 'd0;
    end
    WR_COMPUTE:
    begin
      c_wen = w_mac_out_vld;
      c_wdata = w_mac_out;
    end
    WR_CLEAR:
    begin
      c_wen = c_ren;
      c_wdata = 'd0;
    end
  endcase
end

// Write States
always @(posedge clock)
begin
  if (r_reset)  r_wr_state <= WR_RESET;
  else          r_wr_state <= c_wr_state;
end
always @(*)
begin
  c_wr_state = WR_COMPUTE;
  case (r_wr_state)
    WR_RESET:
      c_wr_state = (r_write_addr == C_DIM-1) ? WR_COMPUTE : WR_RESET;
    WR_COMPUTE:
      c_wr_state = (r_comp_cnt == C_DIM*C_DIM-1) ? WR_CLEAR : WR_COMPUTE;
    WR_CLEAR:
      c_wr_state = (r_read_addr == C_DIM-1) ? WR_COMPUTE : WR_CLEAR;
  endcase
end

// Track outputs as they are produced
always @(posedge clock)
begin
  if (r_reset | o_rd_output)
    r_comp_cnt <= 'd0;
  else if (w_mac_out_vld)
    r_comp_cnt <= r_comp_cnt + 'd1;
end

//////////////////////////////////////////////////////////////////////
// Read Datapath
//////////////////////////////////////////////////////////////////////

// Count total number of inputs
always @(posedge clock)
begin
  if (r_reset | o_rd_output)
    r_valid_cnt <= 'd0;
  else if ((r_rd_state != RD_WAIT && r_Ain_valid == 1'b1) || 
           (r_rd_state == RD_WAIT && r_comp_cnt == C_DIM*C_DIM))
    r_valid_cnt <= r_valid_cnt + 'd1;
end

// Count number of values read from BRAM
always @(posedge clock)
begin
  if (r_rd_state != RD_OUTPUT)
    r_rdata_vld <= 'd0;
  else if (w_rdata_vld)
    r_rdata_vld <= r_rdata_vld + 'd1;
end

always @(posedge clock)
begin
  if (r_reset | o_rd_output)
  begin
    r_read_addr <= 'd0;
    B_wrk_idx <= 1'b0;
  end
  else if (c_ren)
  begin
    if (r_read_addr == C_DIM-1)
    begin
      r_read_addr <= 'd0;
      B_wrk_idx <= ~B_wrk_idx;
    end
    else
      r_read_addr <= r_read_addr + 'd1;
  end
end

// Read Control Signals
always @(*)
begin
  c_ren = 1'b0;
  case (r_rd_state)
    RD_COMPUTE:
    begin
      c_ren = r_Ain_valid;
    end
    RD_OUTPUT:
      c_ren = 1'b1;
  endcase
end
// Read States
always @(posedge clock)
begin
  if (r_reset)  r_rd_state <= RD_PRELOAD;
  else          r_rd_state <= c_rd_state;
end
always @(*)
begin
  c_rd_state = RD_PRELOAD;
  case (r_rd_state)
    RD_PRELOAD:
      c_rd_state = (r_valid_cnt == C_DIM-1) ? RD_COMPUTE : RD_PRELOAD;
    RD_COMPUTE:
      c_rd_state = (r_valid_cnt == C_DIM*(C_DIM+1)-1) ? RD_WAIT : RD_COMPUTE;
    RD_WAIT:
      // Can incur extra cycles
      // Wait for compute to finish and for PE*N data to be sent from
      // previous PEs in the chain
      c_rd_state = (r_comp_cnt == C_DIM*C_DIM &&
                    r_rd_output == 1'b1)
                    ? RD_OUTPUT : RD_WAIT;
    RD_OUTPUT: // need to wait C_TOTAL_BRAM_DLY after this
      c_rd_state = (r_rdata_vld == C_DIM-1) ? RD_PRELOAD : RD_OUTPUT;
  endcase
end

delaychain
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_LENGTH(C_BRAM_DELAY)
) ain_dly (
  .clock(clock),
  .in(r_Ain_data),
  .out(dly_Ain_data)
);

delaychain
#(
  .C_DATA_WIDTH(C_DATA_WIDTH),
  .C_LENGTH(C_BRAM_DELAY)
) bin_dly (
  .clock(clock),
  .in(B_saved[B_wrk_idx]),
  .out(dly_Bin_data)
);

delaychain
#(
  .C_DATA_WIDTH(1),
  .C_LENGTH(C_BRAM_DELAY)
) in_valid_dly (
  .clock(clock),
  .in(r_Ain_valid == 1'b1 & r_rd_state == RD_COMPUTE),
  .out(dly_in_valid)
);

assign mac_in_valid = dly_in_valid;
assign mac_Ain = dly_Ain_data;
assign mac_Bin = dly_Bin_data;
assign mac_Cin = w_rdata;
assign w_mac_out = mac_Cout;
assign w_mac_out_vld = mac_out_valid;

////////////////////////////////////////////
// Inputs/Outputs
////////////////////////////////////////////

always @(posedge clock)
begin
  r_Ain_data <= Ain_data;
  r_Ain_valid <= Ain_valid;
  r_Bin_data <= Bin_data;
  r_Bin_valid <= Bin_valid;
  r_reset <= i_reset;
  r_rd_output <= i_rd_output;
end
assign o_reset = r_reset;
assign Bout_data = r_Bin_data;
assign o_rd_output = (r_rd_state == RD_OUTPUT &&
                      r_rdata_vld == C_DIM-1) ? 1'b1 : 1'b0;

generate
// Last PE writes back to user/memory using the 'A' channel
if (C_LAST_PE == 1)
  assign Aout_valid = (r_rd_state == RD_OUTPUT ? w_rdata_vld | r_Ain_valid
                      : (r_rd_state == RD_WAIT ? r_Ain_valid : 1'b0));
else
  assign Aout_valid = (r_rd_state == RD_OUTPUT ? w_rdata_vld | r_Ain_valid : r_Ain_valid);
endgenerate
assign Aout_data = (r_rd_state == RD_OUTPUT && w_rdata_vld ? 
                    w_rdata : r_Ain_data);

assign Bout_valid = r_Bin_valid & ~r_first_valid;

// Registers to hold B
always @(posedge clock)
begin
  if (r_reset | o_rd_output)
  begin
    r_bvalid_cnt <= 0;
    r_first_valid <= 1'b1;
    B_sav_idx  <= 0;
  end
  else
  begin
    if (r_Bin_valid)
    begin
      // The first item should not be passed on to the next PE
      // This makes each PE "see" the first valid item as the first
      // valid B value, correctly offseting the input.
      if (r_first_valid)
      begin
        r_first_valid <= 1'b0;
      end

      if (r_bvalid_cnt == 'd0)
      begin
        B_saved[B_sav_idx] <= r_Bin_data;
        B_sav_idx <= ~B_sav_idx;
        r_bvalid_cnt <= C_DIM-1;
      end
      else
        r_bvalid_cnt <= r_bvalid_cnt - 'd1;
    end
  end
end

endmodule
