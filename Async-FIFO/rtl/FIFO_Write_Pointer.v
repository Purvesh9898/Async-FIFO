module FIFO_Write_Pointer #(
    parameter ADDR_WIDTH = 4
)(
    input                       W_CLK,
    input                       W_rst_n,
    input                       W_inc,
    input  [ADDR_WIDTH : 0]     Wq2_rptr,
 
    output reg                  W_Full,
    output reg [ADDR_WIDTH : 0] W_ptr,
    output     [ADDR_WIDTH-1:0] W_Addr
);
 
    reg  [ADDR_WIDTH : 0] Binary_W_ptr;
    wire [ADDR_WIDTH : 0] Gray_W_ptr, Binary_W_ptr_next;
    wire                  FULL_VALUE;
 
    // Binary memory address - lower ADDR_WIDTH bits of binary pointer
    assign W_Addr = Binary_W_ptr[ADDR_WIDTH - 1 : 0];
 
    // FIX 2: Next binary pointer increments on W_inc only.
    // The write-enable guard (W_inc & ~Full) at the RAM in the top level
    // prevents actual writes when full. The pointer itself only advances
    // when W_inc is asserted - user must obey the Full flag.
    assign Binary_W_ptr_next = Binary_W_ptr + W_inc;
 
    // Binary-to-Gray conversion
    assign Gray_W_ptr = (Binary_W_ptr_next >> 1) ^ Binary_W_ptr_next;
 
    // Full condition (Cummings): top two bits differ, remaining bits equal
    assign FULL_VALUE = (Gray_W_ptr[ADDR_WIDTH]     != Wq2_rptr[ADDR_WIDTH])   &&
                        (Gray_W_ptr[ADDR_WIDTH - 1] != Wq2_rptr[ADDR_WIDTH-1]) &&
                        (Gray_W_ptr[ADDR_WIDTH - 2 : 0] == Wq2_rptr[ADDR_WIDTH-2:0]);
 
    always @(posedge W_CLK or negedge W_rst_n) begin
        if (~W_rst_n) begin
            W_Full       <= 1'b0;
            W_ptr        <= {(ADDR_WIDTH+1){1'b0}};
            Binary_W_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            W_Full       <= FULL_VALUE;
            W_ptr        <= Gray_W_ptr;
            Binary_W_ptr <= Binary_W_ptr_next;
        end
    end
 
endmodule
