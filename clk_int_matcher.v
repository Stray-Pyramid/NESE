module clk_int_matcher (
	input clk_in,
	input active,
	
	input [15:0] int_a,
	input [15:0] int_b,
	
	output clk_out,
	output reg match = 1'b0
);

assign clk_out = (!active || (!match && active)) ? clk_in : 1'b0;

always @(negedge clk_in) begin
	if(int_a == int_b)
		match <= 1'b1;
	else
		match <= 1'b0;
end

endmodule
