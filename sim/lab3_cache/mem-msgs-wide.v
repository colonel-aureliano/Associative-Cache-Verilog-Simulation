`ifndef VC_MEM_MSGS_WIDE_V
`define VC_MEM_MSGS_WIDE_V
// requests

// 64 Bytes
typedef struct packed {
  logic [2:0]  type_;
  logic [7:0]  opaque;
  logic [31:0] addr;
  logic [6:0]  len;
  logic [511:0] data;
} mem_req_64B_t;

// response

// 64 Bytes
typedef struct packed {
  logic [2:0]  type_;
  logic [7:0]  opaque;
  logic [1:0]  test;
  logic [6:0]  len;
  logic [511:0] data;
} mem_resp_64B_t;

`define VC_MEM_RESP_MSG_TYPE_READ     3'd0
`define VC_MEM_RESP_MSG_TYPE_WRITE    3'd1

`endif /* VC_MEM_MSGS_WIDE_V */
