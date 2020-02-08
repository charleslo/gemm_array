module gemm_mac
#(
  parameter C_DATA_WIDTH = 32,
  parameter C_DELAY = 0
)
(
  input clock,
  input [C_DATA_WIDTH-1: 0] A,
  input [C_DATA_WIDTH-1: 0] B,
  input [C_DATA_WIDTH-1: 0] Cin,
  input in_valid,
  output [C_DATA_WIDTH-1: 0] Cout,
  output out_valid
);

reg [C_DATA_WIDTH-1: 0] r_AB;
reg [C_DATA_WIDTH-1: 0] r_Cin;
reg [C_DATA_WIDTH-1: 0] r_Cout;

delaychain
#(
  .C_DATA_WIDTH(1),
  .C_LENGTH(C_DELAY)
) vld_dly (
  .clock(clock),
  .in(in_valid),
  .out(out_valid)
);

generate
if (C_DELAY == 0)
begin
  assign Cout = A*B + Cin;
end
else if (C_DELAY == 1)
begin
  always @(posedge clock)
  begin
    r_AB <= A*B;
    r_Cin <= Cin;
  end
  assign Cout = r_AB + r_Cin;
end
else if (C_DELAY == 2)
begin
  always @(posedge clock)
  begin
    r_AB <= A*B;
    r_Cin <= Cin;
    r_Cout <= r_AB + r_Cin;
  end
  assign Cout = r_Cout;
end
endgenerate

endmodule
