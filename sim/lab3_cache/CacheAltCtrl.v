//=========================================================================
// Alternative Design Cache Control Unit
//=========================================================================

`ifndef LAB3_CACHE_CACHE_ALT_CTRL_V
`define LAB3_CACHE_CACHE_ALT_CTRL_V

`include "vc/trace.v"
`include "vc/mem-msgs.v"

module lab3_cache_CacheAltCtrl
(
    input  logic        clk,
    input  logic        reset,

    input  mem_req_4B_t stored_memreq_msg,

    // processor-cache interface
    input  logic        memreq_val,
    output logic        memreq_rdy,

    output logic        memresp_val,
    input  logic        memresp_rdy,

    // cache-mem interface
    input  logic        cache_req_rdy,
    
    input  logic        cache_resp_val,

    // receive req msg
    output logic        req_reg_en,
    output logic        req_mux_sel, 

    // flushing logic 
    output logic        index_mux_sel, 
    output logic        index_incr_reg_en, 
    output logic        idx_incr_mux_sel,

    // read_way logic
    output logic        read_way,

    // data array 
    output logic        darray_wen_0,
    output logic        darray_wdata_mux_sel,
    output logic        darray_write_word_en_mux_sel,

    // tag array logic
    output logic        tarray0_wen,
    input  logic        tarray0_match,
    output logic        tarray1_wen,
    input  logic        tarray1_match,
    
    // dirty bit array logic 
    output logic        dirty_wen,
    output logic        dirty_wdata,
    input  logic        is_dirty,

    // mru bit array logic 
    output logic        mru_wen,
    output logic        mru_wdata,
    input  logic        mru,

    // batch send request to memory: 
    output logic        batch_send_istream_val,
    input  logic        batch_send_istream_rdy,

    output logic        to_mem_tag_mux_sel,
    output logic        batch_send_rw,

    // batch receive request from memory: 
    output logic        batch_receive_ostream_rdy,
    input  logic        batch_receive_ostream_val,
    output logic        start_receive,

    output logic        batch_send_addr_sel, 

    // do flush
    input  logic        inp_flush, 
    output logic        flush_done

);

    logic [2:0] state;
    logic       stored_write_val;

    assign req_reg_en = (state == IDLE); 
    assign req_mux_sel = (state != IDLE); 

    assign index_mux_sel = (state == FLUSH);
    assign index_incr_reg_en = (state == FLUSH);
    assign idx_incr_mux_sel = (state == FLUSH);

    // logic       mru; // most recently used
    logic       mru_next;
    logic       way_victim;
    assign way_victim = !mru;
    assign mru_wdata = mru_next;

    // ------------ FSM for eviction and refilling ------------

    logic [2:0] state_next;

    logic [5:0] flush_counter; 
    logic [5:0] flush_counter_next; 
    assign      flush_counter_next  = flush_counter + 1; 

    always_ff @(posedge clk) begin 
        if ( reset ) begin 
            state <= IDLE;
            stored_write_val <= 0;
            flush_counter <= 0;
        end
        else begin
            if (state == FLUSH && batch_send_istream_rdy) flush_counter <= flush_counter_next;
            if (memreq_val && state == IDLE && state_next == REFILL && do_write ) begin
                stored_write_val <= 1;
            end
            if (state == WRITE && stored_write_val) begin
                stored_write_val <= 0;
            end
            if (state == IDLE) flush_counter <= 0;
            state <= state_next;
        end
    end

    localparam IDLE = 3'd0; 
    localparam REFILL = 3'd1; 
    localparam WRITEBACK = 3'd2; 
    localparam FLUSH = 3'd3;
    localparam WAIT_MEM = 3'd4; 
    localparam WRITE = 3'd5;
    localparam GIVE = 3'd6;
    
    // State Transitions
    always_comb begin
        state_next = IDLE; 
        read_way = way_victim;
        mru_next = mru;
        mru_wen = 0;

        if (state == IDLE) begin 
            if (memreq_val) begin
                if (!(tarray0_match || tarray1_match)) begin
                    if (is_dirty) begin
                        state_next = WRITEBACK;
                    end else begin
                        state_next = REFILL;
                    end
                end
                else if (tarray0_match) begin
                    read_way = 1'b0;
                    mru_next = 1'b0;
                    mru_wen = 1;
                    state_next = IDLE;
                end
                else if (tarray1_match) begin
                    read_way = 1'b1;
                    mru_next = 1'b1;
                    mru_wen = 1;
                    state_next = IDLE;
                end
                if ((tarray0_match || tarray1_match) && !memresp_rdy) begin
                    state_next = GIVE;
                end
            end
            if (inp_flush) begin
                state_next = FLUSH;
            end
        end
        else if (state == REFILL) begin
            if ( batch_send_istream_rdy ) begin 
                state_next = WAIT_MEM; 
            end 
            else begin 
                state_next = REFILL; 
            end
        end
        else if (state == WAIT_MEM) begin
            if ( batch_receive_ostream_val ) begin 
                state_next = WRITE; 
            end 
            else begin 
                state_next = WAIT_MEM;
            end
        end
        else if (state == WRITE) begin
            state_next = GIVE;
        end
        else if (state == GIVE) begin
            if (memresp_rdy) begin
                state_next = IDLE;
            end
            else begin
                state_next = GIVE;
            end
        end
        else if (state == WRITEBACK) begin
            if ( batch_send_istream_rdy ) begin 
                state_next = REFILL; 
            end 
            else begin 
                state_next = WRITEBACK; 
            end
        end
        else if (state == FLUSH) begin
            read_way = w;
            if ( flush_counter < 63) state_next = FLUSH; 
            else state_next = IDLE;
        end
    end

    assign flush_done = state == FLUSH && state_next == IDLE;

    // ------------ State Output ------------

    logic          t; 
    logic          t2;
    logic   do_write;
    assign do_write = memreq_val && stored_memreq_msg.type_[0:0];
    // stored_write_val is whether write miss occurred and after refilling
    // we need to write into line
    assign t = (state == IDLE && (state_next == IDLE || state_next == GIVE) && do_write); 
    assign t2 = stored_write_val;

    assign memreq_rdy = (state == IDLE);

    logic send_rdy;
    assign send_rdy = batch_send_istream_rdy;

    logic w;
    assign w = flush_counter[5:5];

    logic fis; // flush_incr_sel
    assign fis = flush_counter != 0; 

    task cs
    (
        input cs_darray_wen_0,
        input cs_dirty_wen,
        input cs_dirty_wdata,
        input cs_batch_send_rw, 
        input cs_batch_send_istream_val,
        input cs_batch_receive_ostream_rdy,
        input cs_batch_send_addr_sel, 
        input cs_to_mem_tag_mux_sel,
        input cs_darray_wdata_mux_sel,
        input cs_darray_write_word_en_mux_sel,
        input cs_index_mux_sel,
        input cs_index_incr_reg_en,
        input cs_idx_incr_mux_sel
    );
        begin
            darray_wen_0                = cs_darray_wen_0; 
            dirty_wen                   = cs_dirty_wen;
            dirty_wdata                 = cs_dirty_wdata;
            batch_send_rw               = cs_batch_send_rw;
            batch_send_istream_val      = cs_batch_send_istream_val;
            batch_receive_ostream_rdy   = cs_batch_receive_ostream_rdy;
            batch_send_addr_sel         = cs_batch_send_addr_sel; 
            to_mem_tag_mux_sel          = cs_to_mem_tag_mux_sel;
            darray_wdata_mux_sel        = cs_darray_wdata_mux_sel;
            darray_write_word_en_mux_sel= cs_darray_write_word_en_mux_sel;
            index_mux_sel               = cs_index_mux_sel;
            index_incr_reg_en           = cs_index_incr_reg_en;
            idx_incr_mux_sel            = cs_idx_incr_mux_sel;
        end
    endtask

    always_comb begin
        case ( state )
            //                                         send      send     receive  send  mem          darray darray   idx   idx     idx
            //                      data   dirty dirty istream   istream  ostream  addr  tag          write  word en  mux   incr    incr
            //                      wen    wen   wdata rw        val      rdy      sel   sel          sel    sel      sel   reg en  sel
            IDLE:               cs( t,    t,    t,     0,        0,       0,       0,    0,           0,     0,       0,    0,      0   );
            WRITEBACK:          cs( 0,    1,    0,     1,        1,       0,       1,    way_victim,  0,     0,       0,    0,      0   );
            REFILL:             cs( 0,    0,    0,     0,        1,       0,       0,    0,           0,     0,       0,    0,      0   );
            WAIT_MEM:           cs( 1,    0,    0,     0,        0,       1,       0,    0,           1,     1,       0,    0,      0   );
            WRITE:              cs( t2,   t2,   t2,    0,        0,       0,       0,    0,           0,     0,       0,    0,      0   );
            FLUSH: if(send_rdy) cs( 0,    1,    0,     1,        is_dirty,0,       1,    w,           0,     0,       1,    1,      fis   );
                   else         cs( 0,    0,    0,     1,        is_dirty,0,       1,    w,           0,     0,       1,    0,      fis   );
            default:            cs( 0,    0,    0,     0,        0,       0,       0,    0,           0,     0,       0,    0,      0   );
        endcase
    end

    assign start_receive = (state == WAIT_MEM);

    assign tarray0_wen = (state == WAIT_MEM) && (read_way == 0);
    assign tarray1_wen = (state == WAIT_MEM) && (read_way == 1);
    
    assign memresp_val = (state == IDLE || state == GIVE) && (tarray0_match || tarray1_match);

endmodule

`endif /* LAB3_CACHE_CACHE_ALT_CTRL_V */
