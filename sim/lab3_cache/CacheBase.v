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

  logic req_reg_en; 
  logic req_mux_sel;
  logic index_mux_sel;
  logic index_incr_reg_en;
  logic idx_incr_mux_sel;

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

  logic darray_wen_1;  

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

    // Make request to memory if miss
    // Stall when refilling
    // On read hit, combined with M1 stage
    .req_reg_en (req_reg_en),
    .req_mux_sel (req_mux_sel),
    .index_mux_sel (index_mux_sel),
    .index_incr_reg_en (index_incr_reg_en),
    .idx_incr_mux_sel (idx_incr_mux_sel),
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
    // Write to data array if write request
    // Make response to processor
    .darray_wen_1 (darray_wen_1),  
    .dirty_wdata_1 (dirty_wdata_1), 
    .dirty_wen_1 (dirty_wen_1), 
    .is_dirty_1 (is_dirty_1), 
    .memresp_msg ( memresp_msg )
  );

  lab3_cache_CacheBaseCtrl ctrl 
  (
    .inp_flush (flush),
    .* 
  );

endmodule


`endif /* LAB3_CACHE_CACHE_BASE_V */
