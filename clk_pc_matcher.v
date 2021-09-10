module clk_int_matcher (
	input clk_in,
	input active,
	
	input [15:0] int,
	input [15:0] match,
	
	output clk_out,
	output stopped
);

assign clk_out = (!active || ((int == match) && active)) ? clk_in : 1'b0;

endmodule
