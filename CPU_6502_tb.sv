module CPU_6502_tb ();

reg clk = 1'b0;
reg rst = 1'b1;

//inout [7:0] data_bus;
//wire [7:0] data_bus_read;
//reg [7:0] data_bus_write;

// If the CPU is reading (rw is high), data_bus takes the value of data_bus_write
//assign data_bus = rw ? data_bus_write : 8'bz;

wire [15:0] address_bus;
wire [7:0] data_bus;

wire rdy; // Ready
wire RW;  // Read/Write
wire sync;

reg res = 1'b1;  // Restart
reg irq = 1'b1;  // Interrupt Request
reg nmi = 1'b1;  // Non-maskable interrupt

reg [15:0] expct_ab;
reg [7:0] expct_db;
reg expct_sync;
reg expct_rw;
reg [7:0] expct_a;
reg [7:0] expct_x;
reg [7:0] expct_y;
reg [7:0] expct_s;
reg [7:0] expct_p;
//reg [(12*8)-1:0] expct_opcode;

wire [7:0] data_read;
reg [7:0] data_write;

integer num_cycles = 32'd0;

integer expected;
integer num_results;
`define NULL 0

assign data_bus = RW ? data_write : 8'bZ;
assign data_read = data_bus;

logic halt_cpu = 1'b0;

initial begin
	expected = $fopen("../expected.txt", "r");
	if (expected == `NULL) begin
		$display("expected.txt was not found.");
		$stop;
	end
end

always #5 clk <= !clk;

always @(posedge clk)
begin
	if ($feof(expected)) begin
		$display("%d cycles completed", num_cycles);
		$stop;
	end
	

	num_results = $fscanf(expected, 
								"AB:0x%X DB:0x%X SYNC:%d RW:%d A:0x%X X:0x%X Y:0x%X S:0x%X P:0x%X\n",
								expct_ab, expct_db, expct_sync, expct_rw, expct_a, expct_x, expct_y, expct_s, expct_p);
	
	//$display(num_results);
	
	data_write = expct_db;
	num_cycles = num_cycles + 1;
	

	
end

CPU_6502 UUT
(
	.clk(clk) ,	// input  clk_sig
	.rst(rst) ,	// input  rst_sig
	.D_BUS(data_bus) ,	// input [7:0] DB_sig
	.A_BUS(address_bus) ,	// output [15:0] AB_sig
	.RDY(rdy) ,	// input  RDY_sig
	.SYNC(sync) ,	// input  RES_sig
	.IRQ(irq) ,	// input  IRQ_sig
	.NMI(nmi) ,	// input  NMI_sig
	.RW(RW)	// output  RW_sig
);



endmodule
