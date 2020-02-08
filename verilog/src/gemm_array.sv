module gemm_array
#(
  parameter C_DATA_WIDTH = 32,
  parameter C_DIM = 4,
  parameter C_NUM_PE = 4,
  parameter C_RAM_IN_DELAY = 1,
  parameter C_RAM_OUT_DELAY = 1,
  parameter C_MAC_DELAY = 1,
  parameter C_RAM_STYLE = 1
)
(
  // PE Interface
  input                       clock,
  input                       i_reset,

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
////////////////////////////////////////////////////////////////////////////////

genvar i;

wire [C_DATA_WIDTH-1: 0] reset [C_NUM_PE: 0];
wire [C_DATA_WIDTH-1: 0] A_data [C_NUM_PE: 0];
wire [C_DATA_WIDTH-1: 0] B_data [C_NUM_PE: 0];
wire [C_DATA_WIDTH-1: 0] A_valid [C_NUM_PE: 0];
wire [C_DATA_WIDTH-1: 0] B_valid [C_NUM_PE: 0];
wire [C_DATA_WIDTH-1: 0] rd_output [C_NUM_PE: 0];

////////////////////////////////////////////////////////////////////////////////
// Inputs/Outputs
////////////////////////////////////////////////////////////////////////////////

assign reset[0] = i_reset;
assign A_data[0] = Ain_data; 
assign B_data[0] = Bin_data; 
assign A_valid[0] = Ain_valid; 
assign B_valid[0] = Bin_valid; 
assign rd_output[0] = i_rd_output;

assign Aout_data = A_data[C_NUM_PE];
assign Bout_data = B_data[C_NUM_PE];
assign Aout_valid = A_valid[C_NUM_PE];
assign Bout_valid = B_valid[C_NUM_PE];
assign o_rd_output = rd_output[C_NUM_PE];

////////////////////////////////////////////////////////////////////////////////
// GEMM Array Instantiation
////////////////////////////////////////////////////////////////////////////////

generate
for (i = 0; i < C_NUM_PE; i = i + 1)
begin : n_1_gemm_pes
  gemm_pe #(
    .C_DATA_WIDTH(C_DATA_WIDTH),
    .C_DIM(C_DIM),
    .C_LAST_PE(i == C_NUM_PE-1 ? 1 : 0),
    .C_RAM_IN_DELAY(C_RAM_IN_DELAY),
    .C_RAM_OUT_DELAY(C_RAM_IN_DELAY),
    .C_MAC_DELAY(C_RAM_IN_DELAY),
    .C_RAM_STYLE(C_RAM_IN_DELAY)
  ) n1pe (
    .clock(clock),
    .i_reset(reset[i]),
    .o_reset(reset[i+1]),

    .Ain_data(A_data[i]),
    .Bin_data(B_data[i]),
    .Ain_valid(A_valid[i]),
    .Bin_valid(B_valid[i]),
    .Aout_data(A_data[i+1]),
    .Bout_data(B_data[i+1]),
    .Aout_valid(A_valid[i+1]),
    .Bout_valid(B_valid[i+1]),

    .i_rd_output(rd_output[i]),
    .o_rd_output(rd_output[i+1])
  );
end
endgenerate

endmodule
