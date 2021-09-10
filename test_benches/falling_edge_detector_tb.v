module falling_edge_detector_tb();

reg trigger = 1'b1;
reg clear = 1'b0;

wire out;

initial begin
	#10

	// Out should go high
	#10 trigger <= 1'b1;
	#10 trigger <= 1'b0;
	
	// Out should go low
	#10 clear <= 1'b1;
	#10 trigger <= 1'b1;
	#10 clear <= 1'b0;
	
	
	// Trigger, clear, and trigger again while clear is still high
	#10 trigger <= 1'b0;
	#10 trigger <= 1'b1;
	#10 clear <= 1'b1;
	//#10 clear <= 1'b0;
	
	// Trigger and clear at the same time, while out = 0
	#10
	trigger <= 1'b0;
	clear <= 1'b1;
	
	// Trigger and clear at the same time, while out = 1
	#10
	trigger <= 1'b1;
	
	#10 clear <= 1'b1;
	#10 clear <= 1'b0;
	#10 trigger <= 1'b0;
	#10 trigger <= 1'b1;
	
	#10
	trigger <= 1'b0;
	clear <= 1'b1;
	
	#10;


end



falling_edge_detector UUT (
	.trigger(trigger),
	.clear(clear),
	
	.out(out)
);

endmodule
