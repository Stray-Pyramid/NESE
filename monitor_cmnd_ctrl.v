module monitor_cmnd_ctrl (

	input clk,
	
	// Clock Count Matcher
	output reg clk_match_active,
	output reg clk_match_reset,
	output reg [63:0] clk_match_trgt,
	input [63:0] clk_count,
	input clk_matched,
	
	// Clock Stepper
	output reg clk_stepper_active,
	output reg clk_step,
	
	// PC Matcher
	output reg pc_match_active,
	output reg [15:0] pc_match_trgt,
	input pc_matched,
	
	// CPU Status
	input cpu_reset,
	input [15:0] a_bus,
	input [7:0] d_bus,
	input rw,
	input sync,
	
	// CPU Internal Registers
	input [15:0] pc,
	input [7:0] x,
	input [7:0] y,
	input [7:0] acc,
	input [7:0] sp,
	input [7:0] stat,
	input [7:0] op_code,
	input [2:0] I_C,
	
	// Memory
	output reg [15:0] mem_addr,
	inout [7:0] mem_data,
	output reg mem_rw,
	
	// Input FIFO
	input [31:0] cmd_read,
	input cmd_read_waiting,
	output reg cmd_read_trigger,
	
	// Output FIFO
	output reg [31:0] cmd_write,
	input cmd_write_full,
	output reg cmd_write_trigger
	
);

wire [7:0] mem_read;
reg  [7:0] mem_write;

assign mem_read = mem_data;
assign mem_data = !mem_rw ? mem_write : 8'bZ;

//always @(posedge clk) begin
//
//
//end

endmodule
