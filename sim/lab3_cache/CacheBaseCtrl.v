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

    input  mem_req_4B_t memreq_msg,

    // processor-cache interface
    input  logic        memreq_val,
    output logic        memreq_rdy,

    output logic        memresp_val,
    input  logic        memresp_rdy,

    // cache_mem_interface
    output logic        cache_req_val,
    input  logic        cache_req_rdy,
    
    input  logic        cache_resp_val,
    output logic        cache_resp_rdy,


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
    output logic        batch_send_rw; 

    // batch receive request from memory: 
    output logic        batch_receive_istream_val; 
    input  logic        batch_receive_istream_rdy; 
    output logic        batch_receive_ostream_rdy; 
    input  logic        batch_receive_ostream_val; 

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
    assign cache_req_val = batch_send_ostream_val; 
    assign batch_send_ostream_rdy = cache_req_rdy; 
    assign cache_resp_rdy = batch_receive_istream_rdy;
    assign batch_receive_istream_val = cache_resp_val; 


    logic stall_1; 
    logic stall_0; 

    logic val_0; 
    logic val_1; 


    logic next_val_0; 
    assign next_val_0 = memreq_val; 
    //----------------------------------------------------------------------
    // M0 stage
    //----------------------------------------------------------------------

    // Register enable logic

    assign req_reg_en_0 = !stall_0; 
    
    logic mem_req_4B_t request_0;
    always_ff ( @posedge clk ) begin 
        if ( reset ) begin 
            val_0 <= 1'b0; 
        end 
        else if ( reg_req_en_0 ) begin 
            val_0 <= next_val_0; 
            request_0 <= memreq_msg; 

        end 
    end

    assign memreq_rdy = !stall_0;  

    // Generic Parameters -- yes or no

    localparam n = 1'd0;
    localparam y = 1'd1;

    // M0 darray write sel

    localparam d0_repl = 0;       // writing duplicated bunch into data array (really should have wen to be 0)
    localparam d0_mem  = 1;       // writing data received from memory into data array


    localparam read_req = 0; 
    localparam write_req = 1; 
    // mem_req_4B_t memreq_msg;
    
    logic        msg_type; 
    logic [31:0] msg_addr_0; 
    logic [31:0] msg_data_0; 
    assign msg_type = request_0.type_[0:0]; 
    assign msg_addr_0 = request_0.addr; 
    assign msg_data_0 = request_0.data;
    

    // ----------------------- a FSM for eviction and refilling ------------
    localparam no_request = 2'd0; 
    localparam evict_req = 2'd1; 
    localparam refill_req = 2'd2; 
    localparam refill_req_done = 2'd3; 
    logic [1:0] memreq_state; 
    logic [1:0] memreq_state_next; 

    logic       wait_refill; 
    assign wait_refill = !tarray_match; 

    always_ff @(posedge clk) begin 
        if ( reset ) begin 
            memreq_state <= no_request; 
        end else begin 
            memreq_state <= memreq_state-next; 
        end
    end 
    always_comb begin 
        if ( !tarray_match && is_dirty_0 )  begin 
            // need to evict
            if ( mem_req_state == no_request ) begin 
                batch_send_istream_val = y; 
                batch_send_rw = write_req; 

                batch_receive_ostream_rdy = n;
                
                memreq_state_next = evict_req; 

                darray_wen_0 = 0; 
                tarray_wen_0 = 0; 
                dirty_wen_0 = 0; 
            end 
            else if ( mem_req_state == evict_req) begin 
                if ( batch_send_istream_rdy ) begin 
                    memreq_state_next = refill_req; 

                    dirty_wdata_0 = 0; 
                    dirty_wen_0 = 1;
                end 
                else begin 
                    memreq_state_next = evict_req; 
                    dirty_wen_0 = 0; 
                end

            end else $stop(); 

        end else if ( !tarray_match ) begin 
            // need to refill 
            if ( mem_req_state == no_request ) begin 
                // before starting refill
                batch_send_istream_send_istream_val = y; 
                batch_send_rw = read_req; 

                batch_receive_ostream_rdy = y; 
                memreq_state_next = refill_req; 
            end 
            else if ( mem_req_state == refill_req ) begin 
                // waiting to send refill requests, wait until batch send is ready
                if ( batch_send_istream_rdy ) begin 
                    memreq_state_next = refill_req_done;
                end 
                else begin 
                    memreq_state_next = refill_req; 
                end 
            end else if (mem_req_state == refill_req_done ) begin 
                // waiting until batch_receive is done; 
                batch_receive_ostream_rdy = 1;
                darray_wen_0 = 1; 
                tarray_wen_0 = 1; 

                if ( batch_receive_ostream_val ) memreq_state_next = no_request; 
                else memreq_state_next = refill_req_done; 
            end 
        end else begin 
            // no need to do anything
            memreq_state = no_request; 
            batch_send_istream_val = n; 
            batch_receive_ostream_rdy = n; 
            darray_wen_0 = 0;  
            tarray_wen_0 = 0; 
            dirty_wen_0 = 0; 
        end
    end    
        
    assign stall_0 = wait_refill; 

    logic next_val_1; 
    assign next_val_1 = val_0 && !stall_0; 
    //----------------------------------------------------------------------
    // M1 stage
    //----------------------------------------------------------------------

    // Register enable logic

    logic mem_req_4B_t request_1; 

    assign req_reg_en_1 = !stall_1;

    always_ff ( @posedge clk ) begin 
        if ( reset ) begin 
            val_1 <= 1'b0; 
            parallel_read_mux_sel <= 0; 
            word_en_sel <= 0; 
            data_wen_1 <= 0; 
            dirty_wen_1 <= 0; 
        end
        else begin 
            val_1 <= next_val_1; 
            parallel_read_mux_sel <= 1; 
            word_en_sel <= 1; 

            request_1 <= request_0; 
        end
    end


    logic        msg_type_1; 
    logic [31:0] msg_addr_0; 
    logic [31:0] msg_data_0; 
    assign msg_type_1 = request_0.type_[0:0]; 
    assign msg_addr_0 = request_0.addr; 
    assign msg_data_0 = request_0.data;

    assign data_wen_1 = msg_type_1; 
    assign word_en_sel = msg_type_1; 

    assign dirty_wen_0 = msg_type_1; 
    assign dirty_wdata_1 = msg_type_1; 

    
    assign memresp_val = val_1;


endmodule

`endif /* LAB2_PROC_PROC_BASE_CTRL_V */
