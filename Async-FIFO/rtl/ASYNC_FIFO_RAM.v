module ASYNC_FIFO_RAM #(

	parameter ADDR_WIDTH = 4,						
	parameter DATA_WIDTH = 8					

)(

	input W_CLK,
	input W_CLK_en,
	input [DATA_WIDTH - 1 : 0] W_Data,				
	input [ADDR_WIDTH - 1 : 0] W_Addr,				// Write Pointer Address
	input [ADDR_WIDTH - 1 : 0] R_Addr,				// Read Pointer Address

	output[DATA_WIDTH - 1 : 0] R_Data				// Data to be read form the Memory

);

	localparam FIFO_DEPTH = 1 << ADDR_WIDTH;
  
	reg [DATA_WIDTH - 1 : 0] MEM [ 0 : FIFO_DEPTH - 1];			// 2-D Memory Width * Depth = 16 x 8 => 128 bits
	//            8 Columns  MEM    16 Rows
	
	always @(posedge W_CLK)
	begin
	
		if(W_CLK_en)
			begin
				MEM[W_Addr] <= W_Data;
			end
	end
	
// Asynchronous Read
	assign R_Data = MEM[R_Addr]; 


endmodule 