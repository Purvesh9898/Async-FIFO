module FIFO_R_Pointer #(
    parameter ADDR_WIDTH = 4
)(
    input                       R_CLK,
    input                       R_rst_n,
    input                       R_inc,
    input  [ADDR_WIDTH : 0]     Rq2_wptr,
 
    output reg                  R_empty,
    output reg [ADDR_WIDTH : 0] R_ptr,
    output     [ADDR_WIDTH-1:0] R_Addr
);
 
    reg  [ADDR_WIDTH : 0] Binary_R_ptr;
    wire [ADDR_WIDTH : 0] Gray_R_ptr, Binary_R_ptr_next;
    wire                  Empty_Value;
 
    // Empty when Gray read pointer equals synchronized write pointer
    assign Empty_Value = (Gray_R_ptr == Rq2_wptr);
 
    // Binary memory read address
    assign R_Addr = Binary_R_ptr[ADDR_WIDTH - 1 : 0];
 
    // Binary-to-Gray conversion
    assign Gray_R_ptr = (Binary_R_ptr_next >> 1) ^ Binary_R_ptr_next;
 
    // FIX 3: use ~ consistently (was ! in original)
    assign Binary_R_ptr_next = Binary_R_ptr + (R_inc & ~R_empty);
 
    always @(posedge R_CLK or negedge R_rst_n) begin
        if (~R_rst_n) begin
            // FIX 1: parametric reset width
            R_empty      <= 1'b1;
            R_ptr        <= {(ADDR_WIDTH+1){1'b0}};
            Binary_R_ptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            R_empty      <= Empty_Value;
            R_ptr        <= Gray_R_ptr;
            Binary_R_ptr <= Binary_R_ptr_next;
        end
    end
 
endmodule
