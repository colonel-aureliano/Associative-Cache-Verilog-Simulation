//=========================================================================
// Base Design Cache Controller
//=========================================================================

`ifndef LAB2_PROC_PROC_Alt_CTRL_V
`define LAB2_PROC_PROC_Alt_CTRL_V

`include "vc/trace.v"

`include "tinyrv2_encoding.v"

module lab3_cache_CacheBaseCtrl
(
    input  logic        clk,
    input  logic        reset,

    input  mem_req_4B_t cache_req_msg,

    // -------------------- M0 stage ----------------------
    output logic        req_reg_en_0; 

    // data array 
    output logic        darray_wen_0; 

    // tag array logic
    output logic        tarray_wen_0; 
    input  logic        tarray_match;
    
    // dirty bit array logic 
    output logic        dirty_wen_0; 
    output logic        dirty_wdata_0; 
    input  logic        is_dirty_0;


    // batch send request to memory: 
    output logic        batch_send_istream_val; 
    input  logic        batch_send_istream_rdy; 
    input  logic        batch_send_ostream_val; 
    output logic        batch_send_ostream_rdy; 
    
    // input  logic [31:0] send_mem_addr; 
    // input  logic [31:0] send_mem_data;

    output logic        memreq_val,
    input  logic        memreq_rdy,


    // batch receive request from memory: 
    output logic        batch_receive_istream_val; 
    input  logic        batch_receive_istream_rdy; 
    output logic        batch_receive_ostream_rdy; 
    input  logic        batch_receive_ostream_val; 

    // output logic [31:0] batch_receive_data; 
    input  logic        memresp_val,
    output logic        memresp_rdy,

    //darray write M0 
    output logic        darray_write_mux_sel;

    // -------------- M1 Stage --------------
    output logic        req_reg_en_1; 
    output logic        parallel_read_mux_sel;
    // data array: 
    output logic        darray_wen_1;  
    output logic        word_en_sel; 

    // dirty array
    output logic        dirty_wdata_1; 
    output logic        dirty_wen_1; 
    input  logic        is_dirty_1; 

);
    assign memreq_val = batch_send_ostream_rdy; 
    assign memresp_rdy = batch_receive_istream_rdy; 

    logic stall_1; 
    logic stall_0; 

    //----------------------------------------------------------------------
    // M0 stage
    //----------------------------------------------------------------------

    // Register enable logic

    assign req_reg_en_0 = !stall_0; 


    // Generic Parameters -- yes or no

    localparam n = 1'd0;
    localparam y = 1'd1;

    // M0 darray write sel

    localparam d0_repl = 0;       // writing duplicated bunch into data array (really should have wen to be 0)
    localparam d0_mem  = 1;       // writing data received from memory into data array


    localparam read_req = 0; 
    localparam write_req = 1; 
    // mem_req_4B_t cache_req_msg;
    
    logic        msg_type; 
    logic [31:0] msg_addr_0; 
    logic [31:0] msg_data_0; 
    assign msg_type = cache_req_msg.type_[0:0]; 
    assign msg_addr_0 = cache_req_msg.addr; 
    assign msg_data_0 = cache_req_msg.data;
    
    logic [1:0] waiting; // 0 if not waiting, 1 if waiting for evict, 2 if waiting for refill; 
    
    always_comb begin 
        if ( !tarray_match && is_dirty_0 ) begin 
            // only write to memory if tag does not match and dirty
            batch_send_istream_val = 1;
            batch_receive_istream_rdy = 1;
            darray_wen_0 = 1; 
            tarray_wen_0 = 1; 

            dirty_wdata_0 = 0; 
            dirty_wen_0 = 1; 

            darray_write_mux_sel = d0_mem;
            
        end 
        else begin
            batch_send_istream_val = 0; 
            batch_receive_ostream_rdy = 0;
            darray_wen_0 = 0; 
            taray_wen_0 = 0; 

            dirty_wen_0 = 1; 

            darray_write_mux_sel = d0_repl;

        end
    end



    //----------------------------------------------------------------------
    // M1 stage
    //----------------------------------------------------------------------

    // Register enable logic

    assign req_reg_en_1 = !stall_1;


endmodule

`endif /* LAB2_PROC_PROC_BASE_CTRL_V */
