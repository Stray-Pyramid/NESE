module clk_count_stop_tb();

reg clk_in = 1'b0;
reg active = 1'b0;
reg reset = 1'b0;
reg [63:0] trg_count = 64'd0;

wire clk_out;
wire match;

always #20 clk_in <= !clk_in;

initial begin
	
	// Non-active operation, clk_in == clk_out
	#100;
		
	// Activate module, set to stop after 5 clock cycles
	trg_count <= 64'd5;
	active <= 1'b1;
	
	
	#(40*7);
	
	// Extend the trg_count by another 5 clock cycles
	trg_count <= 64'd10;
	
	#(40*7);
	
	$stop;


end



clk_count_stop UUT
(
	.clk_in(clk_in) ,	// input  clk_in_sig
	.active(active) ,	// input  active_sig
	.rst_n(rst_n) ,	// input  rst_n_sig
	.trg_count(trg_count) ,	// input [63:0] trg_count_sig
	.clk_out(clk_out) ,	// output  clk_out_sig
	.match(match) 	// output  stopped_sig
);

endmodule
