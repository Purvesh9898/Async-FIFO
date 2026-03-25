module Sync_W2R #(
    parameter ADDR_WIDTH = 4
)(
    input                       R_CLK,
    input                       R_rst_n,
    input  [ADDR_WIDTH : 0]     W_ptr,
    output reg [ADDR_WIDTH : 0] Rq2_wptr
);
 
    reg [ADDR_WIDTH : 0] Rq1_wptr;
 
    always @(posedge R_CLK or negedge R_rst_n) begin
        if (~R_rst_n) begin
            // FIX 3: parametric reset width (was hardcoded 5'b0)
            Rq1_wptr <= {(ADDR_WIDTH+1){1'b0}};
            Rq2_wptr <= {(ADDR_WIDTH+1){1'b0}};
        end
        else begin
            Rq1_wptr <= W_ptr;
            Rq2_wptr <= Rq1_wptr;
        end
    end
 
endmodule