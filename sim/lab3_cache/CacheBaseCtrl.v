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

    // -------------- M1 Stage --------------
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

    logic val; 

    logic flush; 
    // logic next_val; 
    // assign next_val = memreq_val; 
    //----------------------------------------------------------------------
    // M0 stage
    //----------------------------------------------------------------------

    // Register enable logic

    assign req_reg_en = !stall; 
    assign req_mux_sel = stall; 

    mem_req_4B_t store_request;
    mem_req_4B_t request;
    always_ff @( posedge clk ) begin 
        if ( reset ) begin 
            // val <= 1'b0; 
        end 
        else if ( req_reg_en ) begin 
            // val <= next_val; 
            store_request <= memreq_msg; 
            flush <= inp_flush;
        end 
    end
    
    always_comb begin 
        if (stall) request = store_request; 
        else request = memreq_msg; 
    end

    assign memreq_rdy = !stall;  

    logic        msg_type; 
    logic [31:0] msg_addr; 
    logic [31:0] msg_data; 
    assign msg_type = request.type_[0:0]; 
    assign msg_addr = request.addr; 
    assign msg_data = request.data;
    

    // ----------------------- FSM for eviction and refilling ------------
    localparam no_request = 2'd0; 
    localparam evict_req = 2'd1; 
    localparam refill_req = 2'd2; 
    localparam refill_req_done = 2'd3; 
    logic [1:0] memreq_state; 
    logic [1:0] memreq_state_next; 

    logic       wait_refill; 
    assign wait_refill = !tarray_match; 


    assign tarray_wen_0 = memreq_state == refill_req_done && memreq_state_next == no_request;
    assign darray_wen_0 = memreq_state == refill_req_done && memreq_state_next == no_request;
    assign dirty_wen_0 = (memreq_state == evict_req || (flush_state == flushing && is_dirty_0)); 


    localparam no_flush   = 2'd0; 
    localparam flushing   = 2'd1; 
    localparam flush_fin  = 2'd2; 
    logic [1:0] flush_state; 
    logic [1:0] flush_next; 
    logic [4:0] flush_counter; 
    logic [4:0] flush_counter_next; 
    assign      flush_counter_next  = flush_counter + 1; 

    always_ff @(posedge clk) begin 
        if ( reset ) begin 
            memreq_state <= no_request; 
            flush_state <= no_flush; 
            flush_counter <= 0; 
        end else if (!flush) begin 
            if (memreq_state_next == evict_req) dirty_wdata_0 <= 0; 
            memreq_state <= memreq_state_next; 
        end else begin 
            if ( flush_state == flushing && batch_send_istream_rdy ) flush_counter <= flush_counter_next; 
            else if ( flush_state == no_flush ) flush_counter <= 0; 
            memreq_state <= memreq_state_next;
            flush_state <= flush_next; 
        end
    end 

    always_comb begin 
        if ( memreq_val && memreq_state == no_request && flush_state == no_flush) begin 
            // enter states 
            if ( flush ) begin 
                flush_next = flushing; 
                memreq_state_next = no_request; 
            end else if ( !tarray_match && is_dirty_0 ) begin 
                memreq_state_next = evict_req; 
                flush_next = no_flush; 
            end else if ( !tarray_match ) begin 
                memreq_state_next = refill_req; 
                flush_next = no_flush;
            end else begin 
                flush_next = no_flush; 
                memreq_state_next = no_request; 
            end
        end else if ( flush_state == flushing ) begin 
            // if currently flushing 
            memreq_state_next = no_request;

            if (flush_state == no_flush ) begin 
                flush_next = flushing; 
            end
            else if ( flush_state == flushing && flush_counter < 31) flush_next = flushing; 
            else if ( flush_state == flushing ) flush_next = flush_fin; 
            else if ( flush_state == flush_fin ) begin 
                // $display(" possible no flush 1"); 
                if ( memresp_rdy ) flush_next = no_flush; 
                else flush_next = flush_fin;
            end
            else begin 
                // $display("possible no flush 2");
                flush_next = no_flush;  
            end
        end else if ( memreq_state == evict_req ) begin 
            flush_next = no_flush; 
            if ( batch_send_istream_rdy ) begin 
                memreq_state_next = refill_req; 
            end 
            else begin 
                memreq_state_next = evict_req; 
            end

        end else if (memreq_state == refill_req) begin 
            flush_next = no_flush; 
            if ( batch_send_istream_rdy ) begin 
                memreq_state_next = refill_req_done;
            end 
            else begin 
                memreq_state_next = refill_req; 
            end 
        end else if (memreq_state == refill_req_done ) begin 
            // waiting until batch_receive is done; 
            flush_next = no_flush; 
            if ( batch_receive_ostream_val ) memreq_state_next = no_request; 
            else memreq_state_next = refill_req_done; 
        end  else begin 
            flush_next = no_flush; 
            memreq_state_next = no_request; 
        end
    end    

    
    task cs
    (
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
        if ( !flush ) begin 
            case ( memreq_state )
                //                                            send      send     receive  send         idx   idx    idx
                //                             dirty   dirty istream   istream   ostream  addr  flush  mux   incr   incr
                //                             wen0   wdata0   rw       val      rdy       sel   done  sel  reg en mux sel
                no_request:                 cs( 0,       0,    0,       0,         0,      0,     0,    0,    0,     0);
                evict_req:                  cs( 1,       0,    1,       1,         0,      1,     0,    0,    0,     0);
                refill_req:                 cs( 0,       0,    0,       1,         1,      0,     0,    0,    0,     0);
                refill_req_done:            cs( 0,       0,    0,       0,         1,      0,     0,    0,    0,     0);
                default:                    cs('x,      'x,   'x,       0,         0,      0,     0,    0,    0,     0);
            endcase
        end
        else begin 
            case ( flush_state )
                //                                                           send      send     receive  send         idx   idx        idx
                //                                            dirty   dirty istream   istream   ostream  addr  flush  mux   incr       incr
                //                                            wen0   wdata0   rw       val      rdy       sel   done  sel  reg en     mux sel
                no_flush:                                  cs( 0,       0,    1,       0,         0,      0,     0,    0,    0,         0);
                flushing:  if ( batch_send_istream_rdy )   cs( 1,       0,    1,   is_dirty_0,    0,      1,     0,    1,    1,     flush_incr_sel);
                           else                            cs( 0,       0,    1,   is_dirty_0,    0,      1,     0,    1,    0,     flush_incr_sel);
                flush_fin:                                 cs( 0,       0,    1,       0,         0,      1,     1,    0,    0,         0);
                default:                                   cs('x,      'x,   'x,       0,         0,      0,     0,    0,    0,         0);
            endcase

        end

    end

    assign stall = memreq_state != no_request || flush_state != no_flush || !memresp_rdy; 

    //----------------------------------------------------------------------
    // M1 stage
    //----------------------------------------------------------------------

    // Register enable logic


    assign darray_wen_1 = msg_type && memreq_state == no_request && flush_state == no_flush && tarray_match; 

    assign dirty_wen_1 = msg_type && flush_state == no_flush && memreq_state == no_request && tarray_match; 
    assign dirty_wdata_1 = msg_type; 

    assign memresp_val = memreq_state == no_request && flush_state == no_flush && tarray_match;

endmodule

`endif /* LAB2_PROC_PROC_BASE_CTRL_V */
