//=========================================================================
// Cache Memory Sender 512B module
//=========================================================================

`ifndef LAB3_CACHE_CACHE_EVICT_REFILL_V
`define LAB3_CACHE_CACHE_EVICT_REFILL_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"
`include "vc/regfiles.v"
`include "CacheMemSender.v" 
`include "CacheMemReceiver.v"

module lab3_cache_CacheEvictRefill

(
    input  logic         clk,
    input  logic         reset,
 
    input  logic         istream_val,
    output logic         istream_rdy,
 
    output logic         ostream_val,
    input  logic         ostream_rdy,

    // memory signals 
    input  logic         memreq_rdy, 
    output logic         memreq_val, 
    input  logic         memresp_val, 
    output logic         memresp_rdy, 

    // batch sender 
    input  logic [ 31:0] inp_addr,
    input  logic [511:0] inp_data,
    input  logic         rw,            // 0 if read, 1 if write 

    output mem_req_4B_t  mem_req

    // batch receiver 
    input  logic [ 31:0] mem_resp_data; 
    output logic [511:0] mem_data; 
);

    lab3_cache_CacheEvictRefill dpath
    (
        .clk, 
        .reset,

        .inp_addr,
        .inp_data,            // 64B
        .rw,

        .mem_req, 

        .mem_resp_data, 
        .mem_data,

        .batch_send_istream_val,  
        .batch_send_istream_rdy, 
        .batch_send_ostream_rdy, 
        .batch_send_ostream_val, 

        .batch_receive_istream_val,  
        .batch_receive_istream_rdy, 
        .batch_receive_ostream_rdy, 
        .batch_receive_ostream_val, 

    ); 
endmodule

module lab3_cache_CacheEvictRefill_Dpath
(
    input  logic         clk, 
    input  logic         reset,

    // sender 
    input  logic [ 31:0] inp_addr,
    input  logic [511:0] inp_data,            // 64B
    input  logic         rw,

    output mem_req_4B_t  mem_req, 

    // receiver 
    input  logic [ 31:0] mem_resp_data, 
    output logic [511:0] mem_data,

    //---------------------- control inputs ------------
    input  logic         batch_send_istream_val,  
    output logic         batch_send_istream_rdy, 
    input  logic         batch_send_ostream_rdy, 
    output logic         batch_send_ostream_val, 

    input  logic         batch_receive_istream_val,  
    output logic         batch_receive_istream_rdy, 
    input  logic         batch_receive_ostream_rdy, 
    output logic         batch_receive_ostream_val, 

);
    
    lab3_cache_CacheMemSender batch_sender 
    (
        .clk         (clk),
        .reset       (reset),
        .istream_val (batch_send_istream_val),
        .istream_rdy (batch_send_istream_rdy),
        .ostream_val (batch_send_ostream_val),
        .ostream_rdy (batch_send_ostream_rdy),
        .inp_addr    (inp_addr),
        .inp_data    (inp_data),
        .rw          (rw),            // 0 if read, 1 if write 
        .mem_req     (mem-req)
    );

    lab3_cache_CacheMemReceiver batch_receiver 
    (
        .clk            (clk),
        .reset          (reset),
        .istream_val    (batch_receive_istream_val),
        .istream_rdy    (batch_receive_istream_rdy),
        .cache_resp_msg (cache_resp_msg),
        .ostream_val    (batch_receive_ostream_val),
        .ostream_rdy    (batch_receive_ostream_rdy),
        .mem_data       (mem_data)
    );
    
endmodule

module lab3_cache_CacheEvictRefill_Ctrl
(
    input  logic clk, 
    input  logic reset, 

    // Dataflow signals
    output logic         batch_send_istream_val,  //
    input  logic         batch_send_istream_rdy, 
    output logic         batch_send_ostream_rdy, //
    input  logic         batch_send_ostream_val, 

    output logic         batch_receive_istream_val, //
    input  logic         batch_receive_istream_rdy, 
    output logic         batch_receive_ostream_rdy, //
    input  logic         batch_receive_ostream_val, 

    input                evict,
    
    input  logic         memreq_rdy, 
    output logic         memreq_val, //
    input  logic         memresp_val, 
    output logic         memresp_rdy, // 

    // interface signals 
    input  logic         istream_val,
    output logic         istream_rdy,

    output logic         ostream_val,
    input  logic         ostream_rdy
);
    assign batch_send_istream_val = istream_val; 
    assign batch_send_ostream_rdy = memreq_rdy; 
    assign memreq_val = batch_send_ostream_val; 


    assign batch_receive_ostream_rdy = ostream_rdy; 
    assign batch_receive_istream_val = memresp_val; 
    assign memresp_rdy = batch_receive_istream_rdy; 

    //----------------------------------------------------------------------
    // States
    //----------------------------------------------------------------------


    localparam SEND_IDLE = 2'd0; 
    localparam SEND_EVICT = 2'd1; 
    localparam SEND_REFILL = 2'd2; 
    localparam SEND_DONE = 2'd3; 

    
    logic [2:0] send_reg;
    logic [2:0] send_next;

    localparam RECEIVE_IDLE = 2'd0; 
    localparam RECEIVE_EVICT = 2'd1; 
    localparam RECEIVE_REFILL = 2'd2; 
    localparam RECEIVE_DONE = 2'd3; 

    
    logic [2:0] receive_reg;
    logic [2:0] receive_next;

    always_ff @(posedge clk)
    if ( reset ) begin 
        send_reg    <= SEND_IDLE;
        receive_reg <= RECEIVE_IDLE;
    end else begin
        state_reg   <= send_next;
        receive_reg <= receive_next;
    end


    //===================================================================
    //                      SEND State Transitions 
    //===================================================================

    always_comb begin 
        case ( send_reg ) 
            SEND_IDLE: begin 
                if ( istream_val && istream_rdy  ) begin 
                    if ( evict ) send_next = SEND_EVICT; 
                    else send_next = SEND_REFILL; 
                end
                else begin 
                    send_next = SEND_IDLE;
                end
            end
            SEND_EVICT: begin 
                if ( batch_send_istream_rdy ) send_next = SEND_REFILL; 
                else send_next = SEND_EVICT; 
            end 
            SEND_REFILL: begin 
                if (batch_send_istream_rdy ) send_next = SEND_DONE; 
                else send_next = SEND_REFILL; 
            end 
            SEND_DONE: begin 
                if ( batch_send_istream_rdy ) send_next = SEND_IDLE; 
                else begin 
                    send_next = SEND_DONE;
                end
            end 
            default: state_next = SEND_IDLE;
        endcase
    end


    always_comb begin 
        case ( receive_reg ) 
            RECEIVE_IDLE: begin 
                if ( istream_val && istream_rdy  ) begin 
                    if ( evict ) receive_next = RECEIVE_EVICT; 
                    else receive_next = RECEIVE_REFILL; 
                end
                else begin 
                    receive_next = RECEIVE_IDLE;
                end
            end
            RECEIVE_EVICT: begin 
                if ( batch_receive_ostream_val ) receive_next = RECEIVE_REFILL; 
                else receive_next = SEND_EVICT; 
            end 
            RECEIVE_REFILL: begin 
                if (batch_receive_ostream_val ) receive_next = RECEIVE_DONE; 
                else receive_next = SEND_REFILL; 
            end 
            RECEIVE_DONE: begin 
                if ( ostream_rdy ) receive_next = RECEIVE_IDLE;  
                else receive_next = RECEIVE_DONE; 
            end 
            default: receive_next = RECEIVE_IDLE;
        endcase
    end


    //===================================================================
    //                      State Transitions 
    //===================================================================
    // task cs_send
    // (
    //     input cs_istream_rdy,
    //     input cs_ostream_val,
    //     input cs_batch_send_istream_val,
    //     input cs_batch_send_ostream_rdy
    // );
    //     begin
    //         istream_rdy            = cs_istream_rdy;
    //         ostream_val            = cs_ostream_val;
    //         batch_send_istream_val = cs_batch_send_istream_val;
    //         batch_send_ostream_rdy = cs_batch_send_ostream_rdy;
    //     end
    // endtask

    always @(*) begin

        case ( send_reg )
            SEND_IDLE:   begin 
                istream_rdy = 1; 
            end
            SEND_EVICT:  begin 
                istream_rdy = 0; 
            end
            SEND_REFILL: begin 
                istream_rdy = 0; 
            end
            SEND_DONE:   begin 
                istream_rdy = 0; 
            end
            default:     begin 
                istream_rdy = 0; 
            end
        endcase


        case ( receive_reg )
            SEND_IDLE:   begin 
                ostream_val = 0; 
            end
            SEND_EVICT:  begin 
                ostream_val = 0; 
            end
            SEND_REFILL: begin 
                ostream_val = 0; 
            end
            SEND_DONE:   begin 
                ostream_val = 1; 
            end
            default:     begin 

            end
        endcase

    end



endmodule

`endif /* LAB3_CACHE_CACHE_MEM_SENDER_V */
