//=========================================================================
// Staged Pipeline Cache: Direct Mapped Write Back Write Allocate
//=========================================================================

`ifndef LAB3_CACHE_CACHE_BASE_DPATH_V
`define LAB3_CACHE_CACHE_BASE_DPATH_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"
`include "vc/regfiles.v"

module lab3_cache_CacheBaseDpath

(
    input  logic        clk,
    input  logic        reset,
    //definition of inputs and outputs 
    
    input  mem_req_4B_t cache_req_msg,

    // ------ M0 stage ----------
    input  logic        req_reg_en; 

    // tag array logic
    input  logic        tarray_wen; 
    input  logic [ 4:0] tarray_waddr;
    output logic        tarray_match;
    
    // dirty bit array logic 
    input  logic        dirty_wen; 
    input  logic        dirty_wdata; 
    output logic        dirty_rdata;

    // memory logic 
    input  logic        z4b_sel; 
    output logic [31:0] memreq_addr;
    output logic [127:0]

);

    logic [31:0] next_req_addr; 
    logic [31:0] next_req_data; 
    
    assign next_req_addr = cache_req_msg.addr; 
    assign next_req_data = cache_req_msg.data; 

    //-----------------------------------------------------------------------
    // M0 Stage
    //-----------------------------------------------------------------------
    logic [31:0] req_addr0; 
    logic [31:0] req_data0; 
    vc_EnResetReg#(32) reg_addr0_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en),
        .d      (next_req_addr),
        .q      (req_addr0)
    );

    vc_EnResetReg#(32) req_data0_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en),
        .d      (next_req_data),
        .q      (req_data0)
    );

    
    // --------------------- tag check Dpath ---------------------------

    logic [20:0] tag;       // 32 - 5 - 6 bit tag
    logic [ 4:0] index;     // 2kB cache: 2^11 bytes, thus 2^5 lines, and therefore 5 bit index
    logic [ 5:0] offset;    // 64-byte cache blocks: 2^6 byte and needs 6 bits to represent, 4 bit offset, 2 bit 00
    // tag: 21 bit  index: 5 bit    offset: 4 bit   00: 2bit

    assign tag     = req_addr0[31:11]; 
    assign index   = req_addr0[10:6]; 
    assign offset  = req_addr0[5:2]; 

    
    logic [20:0] cache_tag; // denotes the current tag in cache at specific index 

    // Want to read the tag at index cache line, and compare its tag to current tag
    // if the cache stored tag is not same as the request tag, it's a miss
    // if miss, then evict and refill
    // only possible modification to tag is evict and refill, thus write address and write data is index and tag
    vc_ResetRegfile_1r1w #(21, 32) tag_array
    (
        .clk(clk),
        .reset(reset),
        .read_addr(index),
        .read_data(cache_tag),
        .write_en(tarray_wen),
        .write_addr(index),         // only possible rewrite tag is to refill a cache line from a miss
        .write_data(tag)            // if we are writing tag in, then it has to be the refill thus current tag from input
    );


    vc_EqComparator #(21) tag_eq 
    (
        .in0 (cache_tag),
        .in1 (tag),
        .out (tarray_match)
    ); 
    
    vc_ResetRegfile_1r1w #(1, 32) tag_array
    (
        .clk(clk),
        .reset(reset),
        .read_addr(index),
        .read_data(dirty_rdata),
        .write_en(dirty_wen),
        .write_addr(index),                 // only possible rewrite tag is to refill a cache line from a miss
        .write_data(dirty_wdata)            // if we are writing tag in, then it has to be the refill thus current tag from input
    );

    // ----------------------- Fetch Memory Dpath -------------
    logic [31:0] z4b; 
    assign z4b = req_addr0 & 32'hFFFFFFF0; 
    
    vc_Mux2#(32) memreq_addr_mux
    (
        .in0  (req_addr0),
        .in1  (z4b),
        .sel  (z4b_sel),
        .out  (memreq_addr)
    );

    
    

endmodule

module lab3_cache_r6b
(
    input logic [31:0] inp,
    output logic [31:0] out
);
    
    assign out = inp & 32'hFFFFFFC0;
    
endmodule

module lab3_cache_zext
(
    
);

endmodule

`endif /* LAB2_PROC_PROC_BASE_DPATH_V */
