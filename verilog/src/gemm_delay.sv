//clog2 

module delaychain
#(
  parameter C_DATA_WIDTH = 32,
  parameter C_LENGTH = 1
)
(
  input                      clock,
  input  [C_DATA_WIDTH-1: 0] in,
  output [C_DATA_WIDTH-1: 0] out
);
integer i;
reg [C_DATA_WIDTH-1: 0] r_delay [C_LENGTH-1: 0];

generate
if (C_LENGTH == 0)
  assign out = in;
else if (C_LENGTH == 1)
begin
  always @(posedge clock)
    r_delay[0] <= in;
  assign out = r_delay[0];
end
else
begin
  always @(posedge clock)
  begin
    for (i = C_LENGTH-1; i >0; i = i - 1)
      r_delay[i] <= r_delay[i-1];
    r_delay[0] <= in;
  end
  assign out = r_delay[C_LENGTH-1];
end
endgenerate

endmodule
