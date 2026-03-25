module FIFO_TOP #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 8
)(
    input                       W_CLK,
    input                       R_CLK,
    input                       W_rst_n,
    input                       R_rst_n,
    input                       W_inc,
    input                       R_inc,
    input  [DATA_WIDTH - 1 : 0] W_Data,
    output                      Full,
    output                      Empty,
    output [DATA_WIDTH - 1 : 0] R_Data
);
 
    wire [ADDR_WIDTH - 1 : 0] W_Addr, R_Addr;
    wire [ADDR_WIDTH     : 0] W_ptr, R_ptr, Wq2_rptr, Rq2_wptr;
 
    FIFO_Write_Pointer #(.ADDR_WIDTH(ADDR_WIDTH)) FIFO_Write_Pointer_F1 (
        .W_CLK     (W_CLK),
        .W_rst_n   (W_rst_n),
        .W_inc     (W_inc),
        .Wq2_rptr  (Wq2_rptr),
        .W_Full    (Full),
        .W_ptr     (W_ptr),
        .W_Addr    (W_Addr)
    );
 
    FIFO_R_Pointer #(.ADDR_WIDTH(ADDR_WIDTH)) FIFO_R_Pointer_F2 (
        .R_CLK     (R_CLK),
        .R_rst_n   (R_rst_n),
        .R_inc     (R_inc),
        .Rq2_wptr  (Rq2_wptr),
        .R_empty   (Empty),
        .R_ptr     (R_ptr),
        .R_Addr    (R_Addr)
    );
 
    ASYNC_FIFO_RAM #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) ASYNC_FIFO_RAM_F3 (
        .W_CLK     (W_CLK),
        .W_CLK_en  (W_inc & ~Full),
        .W_Data    (W_Data),
        .W_Addr    (W_Addr),
        .R_Addr    (R_Addr),
        .R_Data    (R_Data)
    );
 
    Sync_R2W #(.ADDR_WIDTH(ADDR_WIDTH)) Sync_R2W_F4 (
        .W_CLK     (W_CLK),
        .W_rst_n   (W_rst_n),
        .R_ptr     (R_ptr),
        .Wq2_rptr  (Wq2_rptr)
    );
 
    Sync_W2R #(.ADDR_WIDTH(ADDR_WIDTH)) Sync_W2R_F5 (
        .R_CLK     (R_CLK),
        .R_rst_n   (R_rst_n),
        .W_ptr     (W_ptr),
        .Rq2_wptr  (Rq2_wptr)
    );
 
endmodule
