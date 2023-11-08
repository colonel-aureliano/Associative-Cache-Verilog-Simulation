//=========================================================================
// Cache Base Design
//=========================================================================

`ifndef LAB3_CACHE_CACHE_BASE_V
`define LAB3_CACHE_CACHE_BASE_V

`include "vc/mem-msgs.v"
`include "CacheBaseDpath.v"
`include "CacheBaseCtrl.v"

module lab3_cache_CacheBase
(
  input  logic                    clk,
  input  logic                    reset,


  // imem
  // The imem / memreq signals correspond to processor-cache communication; 
  // the cache should handle requests from the processor, and should give responses back to the processor

  input  logic                    memreq_val,
  output logic                    memreq_rdy,
  input  mem_req_4B_t             memreq_msg,

  output logic                    memresp_val,
  input  logic                    memresp_rdy,
  output mem_resp_4B_t            memresp_msg,

  // cache
  // The cache / cachereq signals correspond to cache-memory communication; 
  // the cache should issue requests to the main memory, and receive responses back from it
  output  logic                    cache_req_val,
  input   logic                    cache_req_rdy,
  output  mem_req_4B_t             cache_req_msg,
 
  input  logic                     cache_resp_val,
  output logic                     cache_resp_rdy,
  input  mem_resp_4B_t             cache_resp_msg,


  // flush
  input logic                     flush,
  output logic                    flush_done
);

  // assign cache_req_val = memreq_val;
  // assign memreq_rdy = cache_req_rdy;
  // assign cache_req_msg = memreq_msg;

  // assign memresp_val = cache_resp_val;
  // assign cache_resp_rdy = memresp_rdy;
  // assign memresp_msg = cache_resp_msg;

  logic req_reg_en_0; 
  logic darray_wen_0; 
  logic tarray_wen_0; 
  logic tarray_match; 
  logic dirty_wen_0; 
  logic dirty_wdata_0; 
  logic is_dirty_0; 
  logic batch_send_istream_val; 
  logic batch_send_istream_rdy; 
  logic batch_send_ostream_val; 
  logic batch_send_ostream_rdy; 
  logic batch_send_rw; 
  logic batch_send_addr_sel;
  logic batch_receive_istream_val; 
  logic batch_receive_istream_rdy; 
  logic batch_receive_ostream_rdy; 
  logic batch_receive_ostream_val; 
  logic darray_write_mux_sel;

  logic req_reg_en_1; 
  logic parallel_read_mux_sel;

  logic darray_wen_1;  
  logic word_en_sel; 

  logic dirty_wdata_1; 
  logic dirty_wen_1; 
  logic is_dirty_1; 

  lab3_cache_CacheBaseDpath dpath 
  (
    .clk (clk),
    .reset (reset),
    //definition of inputs and outputs 
    
    // interface
    .memreq_msg (memreq_msg),

    // ------ M0 stage ----------
    .req_reg_en_0 (req_reg_en_0),
    .darray_wen_0 (darray_wen_0) , 
    .tarray_wen_0 (tarray_wen_0) , 
    .tarray_match (tarray_match) ,
    .dirty_wen_0 (dirty_wen_0) , 
    .dirty_wdata_0 (dirty_wdata_0),  
    .is_dirty_0 (is_dirty_0) ,
    .batch_send_istream_val (batch_send_istream_val), 
    .batch_send_istream_rdy (batch_send_istream_rdy), 
    .batch_send_ostream_val (batch_send_ostream_val), 
    .batch_send_ostream_rdy (batch_send_ostream_rdy), 
    .batch_send_rw (batch_send_rw) , 
    .send_mem_req ( cache_req_msg ), 
    .batch_receive_istream_val (batch_receive_istream_val), 
    .batch_receive_istream_rdy (batch_receive_istream_rdy), 
    .batch_receive_ostream_rdy (batch_receive_ostream_rdy), 
    .batch_receive_ostream_val (batch_receive_ostream_val), 
    .batch_send_addr_sel       (batch_send_addr_sel),
    .batch_receive_data ( cache_resp_msg ), 
    .darray_write_mux_sel (darray_write_mux_sel),
    .req_reg_en_1 (req_reg_en_1), 
    .parallel_read_mux_sel (parallel_read_mux_sel),
    .darray_wen_1 (darray_wen_1),  
    .word_en_sel (word_en_sel), 
    .dirty_wdata_1 (dirty_wdata_1), 
    .dirty_wen_1 (dirty_wen_1), 
    .is_dirty_1 (is_dirty_1), 
    .memresp_msg ( memresp_msg )
  );

  lab3_cache_CacheBaseCtrl ctrl 
  (
    .* 
  );

endmodule


`endif /* LAB3_CACHE_CACHE_BASE_V */
