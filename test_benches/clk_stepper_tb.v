module clk_stepper_tb();

reg clk_in = 1'b0;
reg active = 1'b0;
reg step = 1'b0;

wire clk_out;

always #10 clk_in <= !clk_in;

initial begin
	
	// Non-active operation, clk_in == clk_out
	#50;
		
	// Activate module
	active <= 1'b1;
	
	// Step
	#20 step <= 1'b1;
	#20 step <= 1'b0;
	
	#20
	
	// Step again
	#20 step <= 1'b1;
	#20 step <= 1'b0;
	
	#20
	
	$stop;


end


clk_stepper UUT(

	.clk_in(clk_in),
	.active(active),
	.step(step),
	
	.clk_out(clk_out)

);


endmodule
