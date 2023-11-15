//=========================================================================
// Cache Alt Design
//=========================================================================

`ifndef LAB3_CACHE_CACHE_ALT_V
`define LAB3_CACHE_CACHE_ALT_V

`include "vc/mem-msgs.v"
`include "CacheAltDpath.v"
`include "CacheAltCtrl.v"

module lab3_cache_CacheAlt
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

  logic req_reg_en; 
  logic req_mux_sel;
  logic index_mux_sel;
  logic index_incr_reg_en;
  logic idx_incr_mux_sel;

  logic read_way;

  logic darray_wen_0; 
  logic darray_wdata_mux_sel;
  logic darray_write_word_en_mux_sel;

  logic tarray0_wen; 
  logic tarray0_match; 
  logic tarray1_wen; 
  logic tarray1_match; 

  logic dirty_wen; 
  logic dirty_wdata; 
  logic is_dirty; 

  logic mru_wen;
  logic mru_wdata;
  logic mru;

  logic batch_send_istream_val; 
  logic batch_send_istream_rdy; 
  logic batch_send_ostream_val; 
  logic batch_send_ostream_rdy; 
  logic to_mem_tag_mux_sel;
  logic batch_send_rw; 

  logic batch_receive_istream_val; 
  logic batch_receive_istream_rdy; 
  logic batch_receive_ostream_rdy; 
  logic batch_receive_ostream_val; 
  logic batch_send_addr_sel;

  mem_req_4B_t stored_req_msg;

  assign cache_req_val = batch_send_ostream_val; 
  assign batch_send_ostream_rdy = cache_req_rdy; 
  assign cache_resp_rdy = batch_receive_istream_rdy;
  assign batch_receive_istream_val = cache_resp_val; 

  lab3_cache_CacheAltDpath dpath
  (
    .send_mem_req (cache_req_msg),
    .batch_receive_data (cache_resp_msg),
    .*
  );

  lab3_cache_CacheAltCtrl ctrl 
  (
    .stored_memreq_msg(stored_req_msg),
    .inp_flush (flush),
    .* 
  );

endmodule


`endif /* LAB3_CACHE_CACHE_ALT_V */
