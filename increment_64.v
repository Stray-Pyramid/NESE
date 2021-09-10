module increment_64(

	input clk,
	input reset,
	
	output reg [63:0] count
);

always @(posedge clk) begin

	if(reset)
		count <= 64'd0;
	else
		count <= count + 1;
end

endmodule
