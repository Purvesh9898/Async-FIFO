module Sync_R2W #(
    parameter ADDR_WIDTH = 4
)(
    input                       W_CLK,
    input                       W_rst_n,
    input  [ADDR_WIDTH : 0]     R_ptr,
    output reg [ADDR_WIDTH : 0] Wq2_rptr
);
 
    reg [ADDR_WIDTH : 0] Wq1_rptr;
 
    always @(posedge W_CLK or negedge W_rst_n) begin
        if (~W_rst_n) begin
            // FIX 3: parametric reset width (was hardcoded 5'b0)
            Wq1_rptr <= {(ADDR_WIDTH+1){1'b0}};
            Wq2_rptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            Wq1_rptr <= R_ptr;
            Wq2_rptr <= Wq1_rptr;
        end
    end
 
endmodule
