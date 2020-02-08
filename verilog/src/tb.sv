`timescale 1ns/1ps
module tb
#(
  parameter N = 4,
  parameter C_BRAM_IN_DLY = 1,
  parameter C_BRAM_OUT_DLY = 1,
  parameter C_MAC_DELAY = 1
) ();

localparam DATA_WIDTH = 32;

reg clock;
reg reset;
reg [DATA_WIDTH-1: 0]  Ain_data;
reg [DATA_WIDTH-1: 0]  Bin_data;
reg                    in_valid;
reg                    rd_output;
wire [DATA_WIDTH-1: 0] Cout_data;
wire                   Cout_valid;

reg [DATA_WIDTH-1: 0] B_const [0: N*N-1];
reg [DATA_WIDTH-1: 0] A_const [0: N*N-1];
reg [DATA_WIDTH-1: 0] C_const [0: N*N-1];

// Assign drivers
integer i;

// DUT
gemm_array
#(
  .C_DATA_WIDTH(DATA_WIDTH),
  .C_DIM(N),
  .C_NUM_PE(N),
  .C_RAM_IN_DELAY(C_BRAM_IN_DLY),
  .C_RAM_OUT_DELAY(C_BRAM_OUT_DLY),
  .C_MAC_DELAY(C_MAC_DELAY),
  .C_RAM_STYLE(1)
) dut
(
.clock(clock),
.i_reset(reset),
.Ain_data(Ain_data),
.Bin_data(Bin_data),
.Aout_data(Cout_data),
.Ain_valid(in_valid),
.Bin_valid(in_valid),
.Aout_valid(Cout_valid),
.Bout_valid(),
.i_rd_output(rd_output),
.o_rd_output()
);
always #5 clock = ~clock;

initial
begin
  $timeformat(-9, 2, " ns", 20);
  $readmemh("Adata", A_const);
  $readmemh("Bdata", B_const);
  $readmemh("Cdata", C_const);
  clock = 0;
  rd_output = 1'b0;
  Ain_data = 1;
  in_valid = 1'b0;
  Bin_data = 0;
  reset = 1; 
  repeat(N) @(posedge clock);
  reset = 0;

  repeat (N) @(posedge clock);

  for (i = 0; i < N*(N+1); i = i + 1)
  begin
    if (i < N)    Ain_data = 0;
    else          Ain_data = A_const[i-N];
    if (i < N*N)  Bin_data = B_const[i];
    else          Bin_data = 0;

    in_valid = 1'b1;
    @(posedge clock);
  end
  in_valid = 1'b0;

  repeat (N*N) @(posedge clock);
  rd_output = 1'b1;

  for (i = 0; i < N*N; i = i + 1)
  begin
    while (Cout_valid == 1'b0)
      @(posedge clock);
    $display("%0t Received Value %d =  %d, expected %d", $time, i, Cout_data, C_const[i]);
    assert (C_const[i] == Cout_data) else $error("DOES NOT MATCH");
    @(posedge clock);
  end
  $finish;
end

endmodule


