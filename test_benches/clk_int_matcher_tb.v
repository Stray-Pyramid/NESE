module clk_int_matcher_tb();

reg clk_in = 1'b0;
reg active = 1'b0;

reg [15:0] int_a = 16'd0;
reg [15:0] int_b = 16'd0; 

wire clk_out;
wire match;

always #10 clk_in <= !clk_in;
always #10 int_a <= (!match && !clk_in) ? int_a + 1'b1 : int_a;

initial begin
	
	// Non-active operation, clk_in == clk_out
	#50
		
	// Activate module
	// Set stop at 10
	
	active <= 1'b1;
	int_b <= 16'd10;
	
	#240
	
	$stop;


end



clk_int_matcher UUT (
	.clk_in(clk_in),
	.active(active),
	
	.int_a(int_a),
	.int_b(int_b),
	
	.clk_out(clk_out),
	.match(match)
);

endmodule
