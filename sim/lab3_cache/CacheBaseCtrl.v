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
    output logic        req_reg_en_0,

    output logic        idx0_mux_sel, 
    output logic        idx0_incr_reg_en, 
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
    output logic        req_reg_en_1,
    output logic        parallel_read_mux_sel,
    // data array: 
    output logic        darray_wen_1,
    output logic        word_en_sel,

    // dirty array
    output logic        dirty_wdata_1,
    output logic        dirty_wen_1,
    input  logic        is_dirty_1,

    input  logic        flush, 
    output logic        flush_done
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
    
    mem_req_4B_t request_0;
    always_ff @( posedge clk ) begin 
        if ( reset ) begin 
            val_0 <= 1'b0; 
        end 
        else if ( req_reg_en_0 ) begin 
            val_0 <= next_val_0; 
            request_0 <= memreq_msg; 

        end 
    end

    assign memreq_rdy = val_0 && !stall_0;  

    logic        msg_type; 
    logic [31:0] msg_addr_0; 
    logic [31:0] msg_data_0; 
    assign msg_type = request_0.type_[0:0]; 
    assign msg_addr_0 = request_0.addr; 
    assign msg_data_0 = request_0.data;
    

    // ----------------------- FSM for eviction and refilling ------------
    localparam no_request = 2'd0; 
    localparam evict_req = 2'd1; 
    localparam refill_req = 2'd2; 
    localparam refill_req_done = 2'd3; 
    logic [1:0] memreq_state; 
    logic [1:0] memreq_state_next; 

    logic       wait_refill; 
    assign wait_refill = val_0 && !tarray_match; 


    assign tarray_wen_0 = val_0 && memreq_state == refill_req_done && memreq_state_next == no_request;
    assign darray_wen_0 = val_0 && memreq_state == refill_req_done && memreq_state_next == no_request;
    assign dirty_wen_0 = val_0 && (memreq_state == evict_req || (flush_state == flushing && is_dirty_0)); 


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
            
            flush_state <= flush_next; 
        end
    end 

    always_comb begin 
        if ( val_0 && !tarray_match && is_dirty_0 && !flush )  begin 
            // need to evict
            flush_next = no_flush; 
            if ( memreq_state == no_request ) begin 
                memreq_state_next = evict_req; 
            end 
            else if ( memreq_state == evict_req) begin 
                if ( batch_send_istream_rdy ) begin 
                    memreq_state_next = refill_req; 
                end 
                else begin 
                    memreq_state_next = evict_req; 
                end
            end else begin 
                memreq_state_next = no_request;
                flush_next = no_flush;
                $stop(); 
            end

        end 
        else if ( val_0 && !tarray_match  && !flush ) begin 
            flush_next = no_flush;
            // need to refill 
            if ( memreq_state == no_request ) begin 
                // before starting refill
                memreq_state_next = refill_req; 
            end 
            else if ( memreq_state == refill_req ) begin 
                // waiting to send refill requests, wait until batch send is ready
                if ( batch_send_istream_rdy ) begin 
                    memreq_state_next = refill_req_done;
                end 
                else begin 
                    memreq_state_next = refill_req; 
                end 
            end else if (memreq_state == refill_req_done ) begin 
                // waiting until batch_receive is done; 
                if ( batch_receive_ostream_val ) memreq_state_next = no_request; 
                else memreq_state_next = refill_req_done; 
            end else begin 
                memreq_state_next = no_request; 
                flush_next = no_flush;
                $stop() ;
            end
        end 
        else if ( val_0 && flush ) begin 
            // $display("get in flushing"); 
            // flushing we want to stay in evict, increment index
            memreq_state_next = no_request;
            if (flush_state == no_flush ) begin 
                if ( stall_1 ) flush_next = no_flush; 
                else flush_next = flushing; 
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
        end
        else begin 
            memreq_state_next = no_request; 
            flush_next       = no_flush; 
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
        input cs_idx0_mux_sel,
        input cs_idx0_incr_reg_en,
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
            idx0_mux_sel              = cs_idx0_mux_sel;
            idx0_incr_reg_en          = cs_idx0_incr_reg_en;
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

    assign stall_0 = val_0 && (wait_refill || flush_state != no_flush || stall_1); 

    logic next_val_1; 
    assign next_val_1 = val_0 && !stall_0; 
    //----------------------------------------------------------------------
    // M1 stage
    //----------------------------------------------------------------------

    // Register enable logic

    mem_req_4B_t request_1; 

    assign req_reg_en_1 = !stall_1;

    logic result_sent; 

    always_ff @( posedge clk ) begin 
        if ( reset ) begin 
            val_1 <= 1'b0; 
            parallel_read_mux_sel <= 0; 
            result_sent <= 0; 
        end
        else if ( req_reg_en_1 ) begin 
            val_1 <= next_val_1; 
            parallel_read_mux_sel <= 1; 
            request_1 <= request_0; 
            result_sent <= 0; 
        end

        if ( memresp_rdy ) result_sent <= 1; 
    end


    logic        msg_type_1; 
    logic [31:0] msg_addr_1; 
    logic [31:0] msg_data_1; 

    assign msg_type_1 = request_0.type_[0:0]; 
    assign msg_addr_1 = request_0.addr; 
    assign msg_data_1 = request_0.data;

    assign darray_wen_1 = val_1 && msg_type_1; 
    assign word_en_sel = msg_type_1; 

    assign dirty_wen_1 = val_1 && msg_type_1 && ( flush_state != flushing); 
    assign dirty_wdata_1 = msg_type_1; 

    
    assign memresp_val = val_1;


    
    assign stall_1 = val_1 && ((msg_type_1 && !is_dirty_1) || !memresp_rdy); 

endmodule

`endif /* LAB2_PROC_PROC_BASE_CTRL_V */
