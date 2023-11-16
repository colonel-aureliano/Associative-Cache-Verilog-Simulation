//=========================================================================
// Cache: 2-Way Set Associative Write Back Write Allocate
//=========================================================================

`ifndef LAB3_CACHE_CACHE_ALT_DPATH_V
`define LAB3_CACHE_CACHE_ALT_DPATH_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"
`include "vc/regfiles.v"
`include "CacheMemSender.v" 
`include "CacheMemReceiver.v" 
`include "DataArray.v"


module lab3_cache_CacheAltDpath
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

    // read_way logic
    input logic         read_way,

    // data array logic
    input logic         darray_wen_0,
    input logic         darray_wdata_mux_sel,
    input logic         darray_write_word_en_mux_sel,

    // tag array logic
    input  logic        tarray0_wen,
    output logic        tarray0_match,
    input  logic        tarray1_wen,
    output logic        tarray1_match,
    
    // dirty bit array logic 
    input  logic        dirty_wen,
    input  logic        dirty_wdata,
    output logic        is_dirty,

    // mru bit array logic 
    input  logic        mru_wen,
    input  logic        mru_wdata,
    output logic        mru,

    // batch send request to memory
    input  logic        batch_send_istream_val,
    output logic        batch_send_istream_rdy,
    output logic        batch_send_ostream_val,
    input  logic        batch_send_ostream_rdy,
    
    input  logic        to_mem_tag_mux_sel,
    input  logic        batch_send_rw,
    output mem_req_4B_t send_mem_req,

    // batch receive request from memory
    input  logic        batch_receive_istream_val,
    output logic        batch_receive_istream_rdy,
    input  logic        batch_receive_ostream_rdy,
    output logic        batch_receive_ostream_val,
    input  logic        start_receive,

    input  logic        batch_send_addr_sel,
    
    input  mem_resp_4B_t batch_receive_data,

    // output 
    output mem_resp_4B_t memresp_msg,

    // to control unit
    output mem_req_4B_t stored_req_msg
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

    assign stored_req_msg = req_msg;

    logic [20:0] tag;       // 32 - 5 - 6 bit tag
    logic [ 4:0] req_idx;   // 4kB cache: 2^12 bytes, 2 way, thus 2^6 lines, 2^5 sets and therefore 5 bit index
    logic [ 3:0] offset;    // 64-byte cache blocks: 2^6 byte and needs 6 bits, 4 bit offset, 2 bit 00
    // tag: 21 bit; index: 5 bit; offset: 4 bit; 00: 2bit

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
    //  Way logic / Address for data and dirty array
    // ----------------------------------------------------

    logic [5:0] data_address;
    assign data_address = { read_way, index };
    // Most significant bit of address determines which way.

    // -----------------------------------------------------
    //                      Data Array 
    // ----------------------------------------------------
    logic [511:0] darray_rdata_0; 

    logic [511:0] darray_wdata_repl;
    logic [511:0] darray_wdata_mem;
    logic [511:0] darray_wdata_0; 

    vc_Mux2#(512) darray_wdata_mux
    (
      .in0 ( darray_wdata_repl ),
      .in1 ( darray_wdata_mem ),
      .sel ( darray_wdata_mux_sel ),
      .out ( darray_wdata_0 )
    );

    localparam write_word_en_all = 16'hFFFF;
    logic [ 15:0] darray_wdata_word_en_0; 
    logic [ 15:0] darray_word_en_one_hot; 

    vc_Mux2#(16) darray_write_word_en_mux
    (
      .in0 ( darray_word_en_one_hot ),
      .in1 ( write_word_en_all ),
      .sel ( darray_write_word_en_mux_sel ),
      .out ( darray_wdata_word_en_0 )
    );

    lab3_cache_DataArray #(64) data_array
    (
        .clk          (clk),
        .reset        (reset),

        .read_addr0  (data_address),
        .read_data0  (darray_rdata_0),
 
        .read_addr1  (),
        .read_data1  (),

        .write_en0   (darray_wen_0),
        .write_addr0 (data_address),
        .write_data0 (darray_wdata_0),
        .write_word_en_0 (darray_wdata_word_en_0),

        .write_en1   (),
        .write_addr1 (),
        .write_data1 (),
        .write_word_en_1 ()

    );

    // --------------------- tag check Dpath ---------------------------

    logic [20:0] tarray0_rdata; 
    
    vc_Regfile_1r1w #(21, 32) tag_array0
    (
        .clk        (clk),
        .reset      (reset),

        .read_addr  (index),
        .read_data  (tarray0_rdata),

        .write_en   (tarray0_wen),
        .write_addr (index),
        .write_data (tag)
    );

    vc_EqComparator #(21) tag_eq0 
    (
        .in0 (tarray0_rdata),
        .in1 (tag),
        .out (tarray0_match)
    ); 

    logic [20:0] tarray1_rdata; 
    
    vc_Regfile_1r1w #(21, 32) tag_array1
    (
        .clk        (clk),
        .reset      (reset),

        .read_addr  (index),
        .read_data  (tarray1_rdata),

        .write_en   (tarray1_wen),
        .write_addr (index),
        .write_data (tag)
    );

    vc_EqComparator #(21) tag_eq1 
    (
        .in0 (tarray1_rdata),
        .in1 (tag),
        .out (tarray1_match)
    ); 

    // ------------------ dirty bit array ----------------

    
    vc_Regfile_1r1w #(1, 64) dirty_array
    (
        

        .clk         (clk),
        .reset       (reset),

        .read_addr  (data_address),
        .read_data  (is_dirty),

        .write_en   (dirty_wen),
        .write_addr (data_address),
        .write_data (dirty_wdata)

    );

    // ------------------ MRU bit array ----------------

    
    vc_Regfile_1r1w #(1, 32) MRU_array
    (

        .clk         (clk),
        .reset       (reset),

        .read_addr  (index),
        .read_data  (mru),

        .write_en   (mru_wen),
        .write_addr (index),
        .write_data (mru_wdata)

    );


    // ----------------------- Fetch Memory Dpath -------------
    logic [31:0] tag_addr; 
    logic [31:0] batch_send_addr_res;

    logic [20:0] to_mem_tag;

    vc_Mux2#(21) to_mem_tag_mux
    (
      .in0 (tarray0_rdata),
      .in1 (tarray1_rdata),
      .sel (to_mem_tag_mux_sel),
      .out (to_mem_tag)
    );

    assign tag_addr = {to_mem_tag, index, 6'd0};
    vc_Mux2#(32) batch_send_addr_mux
    (
        .in0 (req_addr), 
        .in1 (tag_addr), 
        .sel (batch_send_addr_sel), 
        .out (batch_send_addr_res)
    ); 
    logic [31:0] sender_inp_addr; 
    assign sender_inp_addr = batch_send_addr_res & 32'hFFFFFFC0;  //z6b

    lab3_cache_CacheMemSender batch_sender 
    (
        .clk         (clk),
        .reset       (reset),
    
        .istream_val (batch_send_istream_val),
        .istream_rdy (batch_send_istream_rdy),
    
        .ostream_val (batch_send_ostream_val),
        .ostream_rdy (batch_send_ostream_rdy),

        .inp_addr    (sender_inp_addr),
        .inp_data    (darray_rdata_0),
        .rw          (batch_send_rw),

        .mem_req     (send_mem_req)
    ); 

    
    // batch receiver
    logic [511:0] from_mem_data; 

    lab3_cache_CacheMemReceiver batch_receiver 
    (
        .clk (clk), 
        .reset (reset), 

        .istream_val (batch_receive_istream_val), 
        .istream_rdy (batch_receive_istream_rdy), 
        .cache_resp_msg (batch_receive_data), 
        .start_receive (start_receive),
    
        .ostream_val (batch_receive_ostream_val), 
        .ostream_rdy (batch_receive_ostream_rdy), 

        .mem_data (from_mem_data)
    );

    assign darray_wdata_mem = from_mem_data;

    logic [511:0] repl_unit_out; 
    assign repl_unit_out = {16{req_data}}; 

    assign darray_wdata_repl = repl_unit_out;

    assign darray_word_en_one_hot = 1 << offset; 

    // ==========================================================================
    //                           Send Response
    // ==========================================================================
       
    // resulting muxes 
    logic [31:0] cache_resp_data; 
    logic [31:0] cache_line_lower;
    vc_Mux8#(32) cache_result_mux_lower 
    (
        .in0 (darray_rdata_0[31 :  0]),
        .in1 (darray_rdata_0[63 :  32]),
        .in2 (darray_rdata_0[95 :  64]),
        .in3 (darray_rdata_0[127 :  96]),
        .in4 (darray_rdata_0[159 :  128]),
        .in5 (darray_rdata_0[191 :  160]),
        .in6 (darray_rdata_0[223 :  192]),
        .in7 (darray_rdata_0[255 :  224]),
        .sel (offset[2:0]),
        .out (cache_line_lower)
    );

    logic [31:0] cache_line_upper;
    vc_Mux8#(32) cache_result_mux_upper
    (
        .in0 (darray_rdata_0[287 :  256]),
        .in1 (darray_rdata_0[319 :  288]),
        .in2 (darray_rdata_0[351 :  320]),
        .in3 (darray_rdata_0[383 :  352]),
        .in4 (darray_rdata_0[415 :  384]),
        .in5 (darray_rdata_0[447 :  416]),
        .in6 (darray_rdata_0[479 :  448]),
        .in7 (darray_rdata_0[511 :  480]),
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


`endif /* LAB3_CACHE_CACHE_ALT_DPATH_V */
