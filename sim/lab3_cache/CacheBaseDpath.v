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
`include "CacheMemSender.v" 
`include "CacheMemReceiver.v" 
`include "DataArray.v"


module lab3_cache_CacheBaseDpath

(
    input  logic        clk,
    input  logic        reset,
    //definition of inputs and outputs 
    
    // interface
    input  mem_req_4B_t memreq_msg,

    // ------ M0 stage ----------
    input  logic        req_reg_en_0,

    // data array 
    input logic         darray_wen_0,

    // tag array logic
    input  logic        tarray_wen_0,
    output logic        tarray_match,
    
    // dirty bit array logic 
    input  logic        dirty_wen_0,
    input  logic        dirty_wdata_0,
    output logic        is_dirty_0,


    // batch send request to memory: 
    input  logic        batch_send_istream_val,
    output logic        batch_send_istream_rdy,
    output logic        batch_send_ostream_val,
    input  logic        batch_send_ostream_rdy,
    
    input  logic        batch_send_rw,
    output mem_req_4B_t send_mem_req,

    // batch receive request from memory: 
    input  logic        batch_receive_istream_val,
    output logic        batch_receive_istream_rdy,
    input  logic        batch_receive_ostream_rdy,
    output logic        batch_receive_ostream_val,

    input  logic        batch_send_addr_sel,
    
    input  mem_resp_4B_t batch_receive_data,

    // -------------- M1 Stage --------------
    input  logic        req_reg_en_1,
    input  logic        parallel_read_mux_sel,
    // data array: 
    input  logic        darray_wen_1,
    input  logic        word_en_sel,

    // dirty array
    input  logic        dirty_wdata_1,
    input  logic        dirty_wen_1,
    output logic        is_dirty_1,

    // output 
    output mem_resp_4B_t memresp_msg

);

    logic [31:0] next_req_addr; 
    logic [31:0] next_req_data; 
    
    assign next_req_addr = memreq_msg.addr; 
    assign next_req_data = memreq_msg.data; 

    //-----------------------------------------------------------------------
    // M0 Stage
    //-----------------------------------------------------------------------
    logic [31:0] req_addr0; 
    logic [31:0] req_data0; 
    mem_req_4B_t req_msg0; 
    vc_EnResetReg#(32) req_addr0_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en_0),
        .d      (next_req_addr),
        .q      (req_addr0)
    );

    vc_EnResetReg#(32) req_data0_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en_0),
        .d      (next_req_data),
        .q      (req_data0)
    );

    vc_EnResetReg#(77) req_msg0_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en_0),
        .d      (memreq_msg),
        .q      (req_msg0)
    );

    logic [20:0] tag0;       // 32 - 5 - 6 bit tag
    logic [ 4:0] index0;     // 2kB cache: 2^11 bytes, thus 2^5 lines, and therefore 5 bit index
    logic [ 3:0] offset0;    // 64-byte cache blocks: 2^6 byte and needs 6 bits to represent, 4 bit offset, 2 bit 00
    // tag: 21 bit  index: 5 bit    offset: 4 bit   00: 2bit

    assign tag0     = req_addr0[31:11]; 
    assign index0   = req_addr0[10:6]; 
    assign offset0  = req_addr0[5:2]; // un-used

    // -----------------------------------------------------
    //                      Data Array 
    // ----------------------------------------------------
    logic [511:0] darray_rdata_0; 

    logic [511:0] darray_rdata_1; 

    // logic         darray_wen_0; 
    logic [511:0] darray_wdata_0; 

    // logic         darray_wen_0; 
    logic [511:0] darray_wdata_1; 

    localparam write_word_en_all = 16'hFFFF;
    logic [ 15:0] darray_wdata_word_en_1; 

    lab3_cache_DataArray data_array
    (
        .clk          (clk),
        .reset        (reset),

        .read_addr0  (index0),
        .read_data0  (darray_rdata_0),
 
        .read_addr1  (index1),
        .read_data1  (darray_rdata_1),

        // refill entire cache line from mem
        .write_en0   (darray_wen_0),
        .write_addr0 (index0),
        .write_data0 (darray_wdata_0),
        .write_word_en_0 (write_word_en_all),

        // request to write into cache line
        .write_en1   (darray_wen_1),
        .write_addr1 (index1),
        .write_data1 (darray_wdata_1),
        .write_word_en_1 (darray_wdata_word_en_1)

    );


    // --------------------- tag check Dpath ---------------------------

    logic [20:0] tarray_rdata_0; 

    logic [20:0] tarray_rdata_1; 

    logic [20:0] tarray_wdata_0; 

    
    // Want to read the tag at index0 cache line, and compare its tag to current tag
    // if the cache stored tag is not same as the request tag, it's a miss
    // if miss, then evict and refill
    // only possible modification to tag is evict and refill, thus write address and write data is index and tag
    vc_Regfile_2r2w #(21, 32) tag_array
    (
        .clk         (clk),
        .reset       (reset),

        .read_addr0  (index0),
        .read_data0  (tarray_rdata_0),

        .read_addr1  (index1),
        .read_data1  (tarray_rdata_1),

        .write_en0   (tarray_wen_0),
        .write_addr0 (index0),
        .write_data0 (tag0),

        .write_en1   (), // TODO: DOUBLE CHECK
        .write_addr1 (),
        .write_data1 ()
    );


    vc_EqComparator #(21) tag_eq 
    (
        .in0 (tarray_rdata_0),
        .in1 (tag0),
        .out (tarray_match)
    ); 

    // ------------------ dirty bit array ----------------

    
    vc_Regfile_2r2w #(1, 32) dirty_array
    (
        

        .clk         (clk),
        .reset       (reset),

        .read_addr0  (index0),
        .read_data0  (is_dirty_0),

        .read_addr1  (index1),
        .read_data1  (is_dirty_1),                // TODO: DOUBLE CHECK

        .write_en0   (dirty_wen_0),
        .write_addr0 (index0),
        .write_data0 (dirty_wdata_0),

        .write_en1   (dirty_wen_1),
        .write_addr1 (index1),
        .write_data1 (dirty_wdata_1)

    );


    // ----------------------- Fetch Memory Dpath -------------
    logic [31:0] tag_addr; 
    logic [31:0] batch_send_addr_res;
    
    assign tag_addr = {tarray_rdata_0, index0, 6'd0};
    vc_Mux2#(32) batch_send_addr_mux
    (
        .in0 (req_addr0), 
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
    
        .ostream_val (batch_receive_ostream_val), 
        .ostream_rdy (batch_receive_ostream_rdy), 

        .mem_data (from_mem_data)
    );

    assign darray_wdata_0 = from_mem_data;

    logic [511:0] repl_unit_out; 
    assign repl_unit_out = {16{req_data0}}; 

    // ==========================================================================
    //                           M1 stage 
    // ==========================================================================

    logic [ 31:0] req_addr_reg1_out;
    logic [ 31:0] req_addr1; 
    
    mem_req_4B_t req_msg1; 
    vc_EnResetReg#(77) req_msg1_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en_1),
        .d      (req_msg0),
        .q      (req_msg1)
    );

    vc_EnResetReg#(32) req_addr1_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en_1),
        .d      (req_addr0),
        .q      (req_addr_reg1_out)
    );
    
    vc_Mux2#(32) parallel_read_mux 
    (
        .in0 (req_addr0), 
        .in1 (req_addr_reg1_out), 
        .sel (parallel_read_mux_sel), 
        .out (req_addr1)
    );

    logic [511:0] req_data1; 
    vc_EnResetReg#(512) req_data1_reg
    (
        .clk    (clk),
        .reset  (reset),
        .en     (req_reg_en_1),
        .d      (repl_unit_out),
        .q      (req_data1)
    );


    assign darray_wdata_1 = req_data1;


    // request information 
    logic [20:0] tag1;       // 32 - 5 - 6 bit tag
    logic [ 4:0] index1;     // 2kB cache: 2^11 bytes, thus 2^5 lines, and therefore 5 bit index
    logic [ 3:0] offset1;    // 64-byte cache blocks: 2^6 byte and needs 6 bits to represent, 4 bit offset, 2 bit 00

    assign tag1     = req_addr1[31:11]; // un-used
    assign index1   = req_addr1[10:6]; 
    assign offset1  = req_addr1[5:2]; 
    
    logic [15:0] word_en_one_hot; 
    assign word_en_one_hot = 1 << offset1; 
    vc_Mux2#(16) write_word_en_mux 
    (
        .in0  (write_word_en_all),
        .in1  (word_en_one_hot),
        .sel  (word_en_sel),
        .out  (darray_wdata_word_en_1)
    ); 

    
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
        .sel (offset1[2:0]),
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
        .sel (offset1[2:0]), 
        .out (cache_line_upper)
    );

    vc_Mux2#(32) cache_result_mux 
    (
        .in0 (cache_line_lower), 
        .in1 (cache_line_upper), 
        .sel (offset1[3]), 
        .out (cache_resp_data)
    ); 


    assign memresp_msg = {req_msg1.type_, 8'b0, 2'b0, 2'b0, cache_resp_data};
endmodule


`endif /* LAB2_PROC_PROC_BASE_DPATH_V */
