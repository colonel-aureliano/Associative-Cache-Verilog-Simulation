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

  
  lab3_cache_CacheBaseDpath dpath 
  (
      .send_mem_addr () ,
      .send_mem_data,
      .batch_receive_data,

      .cache_req_msg
      .cache_resp_data
  );

  lab3_cache_CacheBaseCtrl ctrl 
  (
    .memreq_val,
    .memreq_rdy,
    .memresp_val,
    .memresp_rdy,


  )
endmodule


`endif /* LAB3_CACHE_CACHE_BASE_V */
