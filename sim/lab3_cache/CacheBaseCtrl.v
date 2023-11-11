//=========================================================================
// Base Design Cache Control Unit
//=========================================================================

`ifndef LAB3_CACHE_CACHE_BASE_CTRL_V
`define LAB3_CACHE_CACHE_BASE_CTRL_V

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

    // receive req msg
    output logic        req_reg_en,
    output logic        req_mux_sel, 

    output logic        index_mux_sel, 
    output logic        index_incr_reg_en, 
    output logic        idx_incr_mux_sel,

    // data array 
    output logic        darray_wen_0,

    // tag array logic
    output logic        tarray_wen_0,
    input  logic        tarray_match,
    
    // dirty bit array logic 
    output logic        dirty_wen_0,
    output logic        dirty_wdata_0,
    input  logic        is_dirty_0,


    // batch send request to memory: 
    output logic        batch_send_istream_val,
    input  logic        batch_send_istream_rdy,
    input  logic        batch_send_ostream_val,
    output logic        batch_send_ostream_rdy,
    output logic        batch_send_rw,

    // batch receive request from memory: 
    output logic        batch_receive_istream_val,
    input  logic        batch_receive_istream_rdy,
    output logic        batch_receive_ostream_rdy,
    input  logic        batch_receive_ostream_val,

    output logic        batch_send_addr_sel, 

    // data array: 
    output logic        darray_wen_1,

    // dirty array
    output logic        dirty_wdata_1,
    output logic        dirty_wen_1,
    input  logic        is_dirty_1,

    input  logic        inp_flush, 
    output logic        flush_done
);
    assign cache_req_val = batch_send_ostream_val; 
    assign batch_send_ostream_rdy = cache_req_rdy; 
    assign cache_resp_rdy = batch_receive_istream_rdy;
    assign batch_receive_istream_val = cache_resp_val; 


    logic stall; 
    logic flush; 
    // logic next_val; 
    // assign next_val = memreq_val; 

    // Register enable logic

    assign req_reg_en = !stall; 
    assign req_mux_sel = (req_state != no_request); 

    logic        val; 
    logic        store_val; 
    mem_req_4B_t store_request;
    mem_req_4B_t request;
    always_ff @( posedge clk ) begin 
        if ( reset ) begin 
            // val <= 1'b0; 
        end 
        else if ( req_reg_en ) begin 
            // val <= next_val; 
            store_request <= memreq_msg; 
            store_val <= memreq_val; 
        end 

        if ( req_state == no_request || req_state == flush_fin ) flush <= inp_flush; 
    end
    
    always_comb begin 
        if ( req_state != no_request ) begin 
            request = store_request; 
            val = store_val; 
        end
        else begin 
            request = memreq_msg; 
            val = memreq_val; 
        end
    end

    assign memreq_rdy = !stall;  

    logic        msg_type; 
    logic [31:0] msg_addr; 
    logic [31:0] msg_data; 
    assign msg_type = request.type_[0:0]; 
    assign msg_addr = request.addr; 
    assign msg_data = request.data;
    

    // ----------------------- FSM for eviction and refilling ------------
    localparam no_request = 3'd0; 
    localparam evict_req = 3'd1; 
    localparam refill_req = 3'd2; 
    localparam refill_req_done = 3'd3;
    localparam refill_resp_done = 3'd4; 
    localparam flushing   = 3'd5; 
    localparam flush_fin  = 3'd6; 

    logic [2:0] req_state; 
    logic [2:0] req_state_next; 

    logic [4:0] flush_counter; 
    logic [4:0] flush_counter_next; 
    assign      flush_counter_next  = flush_counter + 1; 


    logic       wait_refill; 
    assign wait_refill = !tarray_match; 


    assign tarray_wen_0 = req_state == refill_req_done && req_state_next == refill_resp_done;
    assign darray_wen_0 = req_state == refill_req_done && req_state_next == refill_resp_done;
    assign dirty_wen_0 = (req_state == evict_req || (req_state == flushing && is_dirty_0)); 


    always_ff @(posedge clk) begin 
        if ( reset ) begin 
            req_state <= no_request; 
            flush_counter <= 0; 
            store_val <= 0; 
        end else if (!flush) begin 
            if (req_state_next == evict_req) dirty_wdata_0 <= 0; 
            req_state <= req_state_next; 
        end else begin 
            if ( req_state == flushing && batch_send_istream_rdy ) flush_counter <= flush_counter_next; 
            else if ( req_state == no_request ) flush_counter <= 0; 
            req_state <= req_state_next;
            req_state <= req_state_next; 
            
            store_val <= 0; 
        end
    end 

    always_comb begin 
        if ( val && req_state == no_request ) begin 
            // enter states 
            if ( flush ) begin 
                req_state_next = flushing; 
            end else if ( !tarray_match && is_dirty_0 ) begin 
                req_state_next = evict_req; 
            end else if ( !tarray_match ) begin 
                req_state_next = refill_req; 
            end else if ( !memresp_rdy) begin 
                // if valid and no request and response is not valid, then we want to stall it but also want to have it immediately available
                req_state_next = refill_resp_done; 
            end else begin 
                req_state_next = no_request; 
            end
        end else if ( req_state == flushing ) begin 
            // if currently flushing 
            if ( flush_counter < 31) req_state_next = flushing; 
            else req_state_next = flush_fin; 
        end else if ( req_state == flush_fin ) begin 
            // $display(" possible no flush 1"); 
            if ( memresp_rdy ) req_state_next = no_request; 
            else req_state_next = flush_fin;
        end
        else if ( req_state == evict_req ) begin 
            if ( batch_send_istream_rdy ) begin 
                req_state_next = refill_req; 
            end 
            else begin 
                req_state_next = evict_req; 
            end
        end else if (req_state == refill_req) begin 
            if ( batch_send_istream_rdy ) begin 
                req_state_next = refill_req_done;
            end 
            else begin 
                req_state_next = refill_req; 
            end 
        end else if (req_state == refill_req_done ) begin 
            // waiting until batch_receive is done; 
            if ( batch_receive_ostream_val ) req_state_next = refill_resp_done; 
            else req_state_next = refill_req_done; 
        end else if (req_state == refill_resp_done) begin 
            if ( memresp_rdy ) req_state_next = no_request;
            else req_state_next = refill_resp_done; 
        end
        else begin 
            req_state_next = no_request; 
        end
    end    

    
    task cs
    (
        // input cs_darray_wen_1;
        input cs_dirty_wen_0,
        input cs_dirty_wdata_0,
        input cs_batch_send_rw, 
        input cs_batch_send_istream_val,
        input cs_batch_receive_ostream_rdy,
        input cs_batch_send_addr_sel, 

        input cs_flush_done,
        input cs_index_mux_sel,
        input cs_index_incr_reg_en,
        input cs_idx_incr_mux_sel
    );
        begin
            // dirty_wen_0               = cs_dirty_wen_0;
            // dirty_wdata_0             = cs_dirty_wdata_0;
            // darray_wen_1              = cs_darray_wen_1; 
            batch_send_rw             = cs_batch_send_rw;
            batch_send_istream_val    = cs_batch_send_istream_val;
            batch_receive_ostream_rdy = cs_batch_receive_ostream_rdy;
            batch_send_addr_sel       = cs_batch_send_addr_sel; 
            flush_done                = cs_flush_done;
            index_mux_sel             = cs_index_mux_sel;
            index_incr_reg_en         = cs_index_incr_reg_en;
            idx_incr_mux_sel          = cs_idx_incr_mux_sel;
        end
    endtask

    localparam tag_addr_sel = 1'd1; 
    localparam req_addr_sel = 1'd0; 

    logic flush_incr_sel; 
    assign flush_incr_sel = flush_counter != 0; 
    always @(*) begin
        case ( req_state )
            //                                                           send      send     receive  send         idx   idx          idx
            //                                            dirty   dirty istream   istream   ostream  addr  flush  mux   incr         incr
            //                                            wen0   wdata0   rw       val      rdy       sel   done  sel  reg en       mux sel
            no_request:                                cs( 0,       0,    0,       0,         0,      0,     0,    0,    0,           0);
            evict_req:                                 cs( 1,       0,    1,       1,         0,      1,     0,    0,    0,           0);
            refill_req:                                cs( 0,       0,    0,       1,         1,      0,     0,    0,    0,           0);
            refill_req_done:                           cs( 0,       0,    0,       0,         1,      0,     0,    0,    0,           0);
            refill_resp_done:                          cs( 0,       0,    0,       0,         0,      0,     0,    0,    0,           0);
            flushing:  if ( batch_send_istream_rdy )   cs( 1,       0,    1,   is_dirty_0,    0,      1,     0,    1,    1,     flush_incr_sel);
                       else                            cs( 0,       0,    1,   is_dirty_0,    0,      1,     0,    1,    0,     flush_incr_sel);
            flush_fin:                                 cs( 0,       0,    1,       0,         0,      1,     1,    0,    0,           0);
            default:                                   cs('x,      'x,   'x,       0,         0,      0,     0,    0,    0,           0);
        endcase

    end

    assign stall = req_state != no_request || (val && ( memreq_val && !memresp_rdy )); 

    //----------------------------------------------------------------------
    // Write to data array / Send response
    //----------------------------------------------------------------------

    // Register enable logic


    assign darray_wen_1 = val && msg_type && (req_state == no_request || req_state == refill_resp_done)  && tarray_match; 

    assign dirty_wen_1 = val && msg_type && (req_state == no_request || req_state == refill_resp_done)  && tarray_match; 
    assign dirty_wdata_1 = msg_type; 

    assign memresp_val = (req_state == no_request || req_state == refill_resp_done) && tarray_match || req_state == flush_fin;

endmodule

`endif /* LAB3_CACHE_CACHE_BASE_CTRL_V */
