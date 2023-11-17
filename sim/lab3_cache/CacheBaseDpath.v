//=========================================================================
// Cache: Direct Mapped Write Back Write Allocate
//=========================================================================

`ifndef LAB3_CACHE_CACHE_BASE_DPATH_V
`define LAB3_CACHE_CACHE_BASE_DPATH_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"
`include "vc/regfiles.v"
`include "DataArray.v"
`include "mem-msgs-wide.v"
`include "dma.v"


module lab3_cache_CacheBaseDpath

(
    input  logic        clk,
    input  logic        reset,

    // definition of inputs and outputs 
    
    // interface
    input  mem_req_4B_t memreq_msg,

    // receive req msg
    input  logic        req_reg_en,
    input  logic        req_mux_sel,

    // flushing logic 
    input  logic        index_mux_sel, 
    input  logic        index_incr_reg_en, 
    input  logic        idx_incr_mux_sel,

    // data array 
    input logic         darray_wen_0,

    // tag array logic
    input  logic        tarray_wen_0,
    output logic        tarray_match,
    
    // dirty bit array logic 
    input  logic        dirty_wen_0,
    output logic        is_dirty_0,

    // valid bit array
    input logic         valid_wen,

    // batch send request to memory: 
    input  logic        batch_send_istream_val,
    output logic        batch_send_istream_rdy,
    output logic        batch_send_ostream_val,
    input  logic        batch_send_ostream_rdy,
    
    input  logic        batch_send_rw,
    output mem_req_4B_t send_mem_req,               
    // this above line shows to be not fully toggled because we do not encounter any situations that would toggle all bits in a mem_req

    // batch receive request from memory: 
    input  logic        batch_receive_istream_val,
    output logic        batch_receive_istream_rdy,
    input  logic        batch_receive_ostream_rdy,
    output logic        batch_receive_ostream_val,

    input  logic        batch_send_addr_sel,
    
    input  mem_resp_4B_t batch_receive_data,

    // data array: 
    input  logic        darray_wen_1,

    // dirty array
    input  logic        dirty_wdata_1,
    input  logic        dirty_wen_1,
    output logic        is_dirty_1,

    // output 
    output mem_resp_4B_t memresp_msg
);
    logic [31:0] req_addr; 
    logic [31:0] req_data; 
    mem_req_4B_t req_msg; 
    mem_req_4B_t store_req; 

    vc_EnResetReg#(77) req_msg_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en),
        .d      (req_msg),
        .q      (store_req)
    );

    vc_Mux2#(77) req_mux 
    (
        .in0 (memreq_msg), 
        .in1 (store_req), 
        .sel (req_mux_sel), 
        .out (req_msg)
    ); 
    assign req_addr = req_msg.addr;
    assign req_data = req_msg.data; 

    logic [20:0] tag;       // 32 - 5 - 6 bit tag
    logic [ 4:0] req_idx;     // 2kB cache: 2^11 bytes, thus 2^5 lines, and therefore 5 bit index
    logic [ 3:0] offset;    // 64-byte cache blocks: 2^6 byte and needs 6 bits to represent, 4 bit offset, 2 bit 00
    // tag: 21 bit  index: 5 bit    offset: 4 bit   00: 2bit

    assign tag     = req_addr[31:11]; 
    assign req_idx = req_addr[10:6]; 
    assign offset  = req_addr[5:2];


    // ---------------------------- index incrementer for flushing ---------------------
    logic [ 4:0] index; 

    logic [ 4:0] incr_idx; 
    vc_Mux2#(5) index_mux 
    (
        .in0 ( req_idx ), 
        .in1 ( incr_idx ), 
        .sel ( index_mux_sel ), 
        .out (index)
    );

    logic [ 4:0] next_idx_incr; 
    logic [ 4:0] idx; 
    vc_EnResetReg#(5) idx_incr_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (index_incr_reg_en),
        .d      (next_idx_incr),
        .q      (idx)
    );

    vc_Mux2#(5) idx_incr_mux
    (
        .in0 ( 5'd0 ), 
        .in1 ( idx ), 
        .sel ( idx_incr_mux_sel ), 
        .out ( incr_idx )
    );

    assign next_idx_incr = incr_idx + 1; 


    // -----------------------------------------------------
    //                      Data Array 
    // ----------------------------------------------------
    logic [511:0] darray_rdata_0; 

    logic [511:0] darray_rdata_1; 

    logic [511:0] darray_wdata_0; 

    logic [511:0] darray_wdata_1; 

    localparam write_word_en_all = 16'hFFFF;
    logic [ 15:0] darray_wdata_word_en_1; 

    lab3_cache_DataArray #(32) data_array
    (
        .clk          (clk),
        .reset        (reset),

        .read_addr0  (index),
        .read_data0  (darray_rdata_0),
 
        .read_addr1  (index),
        .read_data1  (darray_rdata_1),

        // refill entire cache line from mem
        .write_en0   (darray_wen_0),
        .write_addr0 (index),
        .write_data0 (darray_wdata_0),
        .write_word_en_0 (write_word_en_all),

        // request to write into cache line
        .write_en1   (darray_wen_1),
        .write_addr1 (index),
        .write_data1 (darray_wdata_1),
        .write_word_en_1 (darray_wdata_word_en_1)

    );


    // --------------------- tag check Dpath ---------------------------

    logic [20:0] tarray_rdata_0; 

    logic [20:0] tarray_rdata_1; 

    
    // Want to read the tag at index cache line, and compare its tag to current tag
    // if the cache stored tag is not same as the request tag, it's a miss
    // if miss, then evict and refill
    // only possible modification to tag is evict and refill, thus write address and write data is index and tag
    vc_Regfile_2r2w #(21, 32) tag_array
    (
        .clk         (clk),
        .reset       (reset),

        .read_addr0  (index),
        .read_data0  (tarray_rdata_0),

        .read_addr1  (index),
        .read_data1  (tarray_rdata_1),

        .write_en0   (tarray_wen_0),
        .write_addr0 (index),
        .write_data0 (tag),

        .write_en1   (), 
        .write_addr1 (),
        .write_data1 ()
    );

    logic eqtag;
    vc_EqComparator #(21) tag_eq 
    (
        .in0 (tarray_rdata_0),
        .in1 (tag),
        .out (eqtag)
    ); 

    logic is_valid;
    assign tarray_match = eqtag && is_valid;

    // ------------------ dirty bit array ----------------
    localparam dirty_wdata_0 = 1'b0; 
    
    vc_Regfile_2r2w #(1, 32) dirty_array
    (
        

        .clk         (clk),
        .reset       (reset),

        .read_addr0  (index),
        .read_data0  (is_dirty_0),

        .read_addr1  (index),
        .read_data1  (is_dirty_1),                // TODO: DOUBLE CHECK

        .write_en0   (dirty_wen_0),
        .write_addr0 (index),
        .write_data0 (dirty_wdata_0),

        .write_en1   (dirty_wen_1),
        .write_addr1 (index),
        .write_data1 (dirty_wdata_1)

    );

   // ------------------ valid bit array ----------------

    
    vc_Regfile_1r1w #(1, 32) valid_array // value initialized or not
    (
        

        .clk         (clk),
        .reset       (reset),

        .read_addr  (index),
        .read_data  (is_valid),

        .write_en   (valid_wen),
        .write_addr (index),
        .write_data (1'b1)

    );


    // ----------------------- Fetch Memory Dpath -------------
    logic [31:0] tag_addr; 
    logic [31:0] batch_send_addr_res;
    
    assign tag_addr = {tarray_rdata_0, index, 6'd0};
    vc_Mux2#(32) batch_send_addr_mux
    (
        .in0 (req_addr), 
        .in1 (tag_addr), 
        .sel (batch_send_addr_sel), 
        .out (batch_send_addr_res)
    ); 
    logic [31:0] sender_inp_addr; 
    assign sender_inp_addr = batch_send_addr_res & 32'hFFFFFFC0;  //z6b

    mem_req_64B_t req_msg_64B;
    assign req_msg_64B.addr = sender_inp_addr;
    assign req_msg_64B.data = darray_rdata_0;
    assign req_msg_64B.type_ = {2'b0, batch_send_rw};

    lab3_cache_Dma dma 
    (
        .clk (clk), 
        .reset (reset),

        .cache_req_msg(req_msg_64B),
        .cache_req_val(batch_send_istream_val),
        .cache_req_rdy(batch_send_istream_rdy),

        .cache_resp_msg(resp_msg_64B),
        .cache_resp_val(batch_receive_ostream_val),
        .cache_resp_rdy(batch_receive_ostream_rdy),

        .mem_req_msg(send_mem_req),
        .mem_req_val(batch_send_ostream_val),
        .mem_req_rdy(batch_send_ostream_rdy),

        .mem_resp_msg(batch_receive_data),
        .mem_resp_val(batch_receive_istream_val),
        .mem_resp_rdy(batch_receive_istream_rdy)
    );

    mem_resp_64B_t resp_msg_64B;
    logic [511:0] from_mem_data; 
    assign from_mem_data = resp_msg_64B.data;

    assign darray_wdata_0 = from_mem_data;

    logic [511:0] repl_unit_out; 
    assign repl_unit_out = {16{req_data}}; 

    assign darray_wdata_1 = repl_unit_out;

    logic [15:0] word_en_one_hot; 
    assign word_en_one_hot = 1 << offset; 

    assign darray_wdata_word_en_1 = word_en_one_hot;

    // ==========================================================================
    //                           Send Response
    // ==========================================================================
       
    // resulting muxes 
    logic [31:0] cache_resp_data; 
    logic [31:0] cache_line_lower;
    vc_Mux8#(32) cache_result_mux_lower 
    (
        .in0 (darray_rdata_1[31 :  0]),
        .in1 (darray_rdata_1[63 :  32]),
        .in2 (darray_rdata_1[95 :  64]),
        .in3 (darray_rdata_1[127 :  96]),
        .in4 (darray_rdata_1[159 :  128]),
        .in5 (darray_rdata_1[191 :  160]),
        .in6 (darray_rdata_1[223 :  192]),
        .in7 (darray_rdata_1[255 :  224]),
        .sel (offset[2:0]),
        .out (cache_line_lower)
    );

    logic [31:0] cache_line_upper;
    vc_Mux8#(32) cache_result_mux_upper
    (
        .in0 (darray_rdata_1[287 :  256]),
        .in1 (darray_rdata_1[319 :  288]),
        .in2 (darray_rdata_1[351 :  320]),
        .in3 (darray_rdata_1[383 :  352]),
        .in4 (darray_rdata_1[415 :  384]),
        .in5 (darray_rdata_1[447 :  416]),
        .in6 (darray_rdata_1[479 :  448]),
        .in7 (darray_rdata_1[511 :  480]),
        .sel (offset[2:0]), 
        .out (cache_line_upper)
    );

    vc_Mux2#(32) cache_result_mux 
    (
        .in0 (cache_line_lower), 
        .in1 (cache_line_upper), 
        .sel (offset[3]), 
        .out (cache_resp_data)
    ); 


    assign memresp_msg = {req_msg.type_, 8'b0, 2'b0, 2'b0, cache_resp_data};
endmodule


`endif /* LAB3_CACHE_CACHE_BASE_DPATH_V */
