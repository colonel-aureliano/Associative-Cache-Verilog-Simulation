//=========================================================================
// Cache Memory Receiver 512B module
//=========================================================================

`ifndef LAB3_CACHE_CACHE_MEM_RECEIVER_V
`define LAB3_CACHE_CACHE_MEM_RECEIVER_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"

module lab3_cache_CacheMemReceiver

(
    input  logic         clk,
    input  logic         reset,
 
    input  logic         istream_val,
    output logic         istream_rdy,
    input  mem_resp_4B_t cache_resp_msg,
 
    output logic         ostream_val,
    input  logic         ostream_rdy,

    output logic [511:0] mem_data
);

    // Control signals

    logic incr_reg_en;
    logic incr_mux_sel;
    logic data_reg_en;
    logic data_mux_sel;

    logic [511:0] data; 
    // Instantiate and connect datapath

    lab3_cache_CacheMemReceiver_Dpath dpath
    (
        .clk                  (clk),
        .reset                (reset), 
        .cache_resp_data      (cache_resp_msg.data),
        .output_data          (data),
        .*
    );

    // Instantiate and connect control unit

    lab3_cache_CacheMemReceiver_Control ctrl
    (
        .cache_resp_type       (cache_resp_msg.type_),
        .*
    );

    assign mem_data = data;

endmodule

module lab3_cache_CacheMemReceiver_Dpath
(
    input  logic         clk, 
    input  logic         reset,

    input  logic [ 31:0] cache_resp_data,
    output logic [511:0] output_data,            // 64B

    //---------------------- control inputs ------------
    input  logic         incr_reg_en, 
    input  logic         incr_mux_sel,
    input  logic         data_reg_en, 
    input  logic         data_mux_sel

);

    logic [511:0] resp_msg_extended;
    assign resp_msg_extended = {480'b0,cache_resp_data};

    logic [ 9:0] incr_mux_out;
    logic [ 9:0] incr_reg_out;
    vc_EnReg#(10) incr_reg
    (
        .clk   (clk),
        .reset (reset),
        .en    (incr_reg_en),
        .d     (incr_mux_out),
        .q     (incr_reg_out)
    );

    logic [ 9:0] incr_added;
    assign incr_added = incr_reg_out+10'd32;

    vc_Mux2#(10) incr_mux
    (
        .in0  (10'b0),
        .in1  (incr_added),
        .sel  (incr_mux_sel),
        .out  (incr_mux_out)
    );


    logic [511:0] resp_shifted;
    assign resp_shifted = (resp_msg_extended << incr_reg_out);

    logic [511:0] data_mux_out;
    logic [511:0] data_reg_out;
    vc_EnReg#(512) data_reg
    (
        .clk   (clk),
        .reset (reset),
        .en    (data_reg_en),
        .d     (data_mux_out),
        .q     (data_reg_out)
    );

    logic [511:0] data_added;
    assign data_added = data_reg_out + resp_shifted;

    vc_Mux2#(512) data_mux
    (
        .in0  (512'b0),
        .in1  (data_added),
        .sel  (data_mux_sel),
        .out  (data_mux_out)
    );

    assign output_data = data_reg_out;

endmodule

module lab3_cache_CacheMemReceiver_Control 
(
    input  logic        clk, 
    input  logic        reset,

    // Dataflow signals
    input  logic        istream_val,
    output logic        istream_rdy,

    output logic        ostream_val,
    input  logic        ostream_rdy,
    input  logic [2:0]  cache_resp_type,

   // Ctrl signals 
    output logic        incr_reg_en, 
    output logic        incr_mux_sel,
    output logic        data_reg_en, 
    output logic        data_mux_sel
);

    //===================================================================
    // States
    //===================================================================

    localparam STATE_IDLE = 3'd0;
    localparam STATE_WAIT = 3'd1;
    localparam STATE_RECEIVE = 3'd2;
    localparam STATE_DONE = 3'd3; 

    logic [2:0] state_reg;
    logic [2:0] state_next;

    always_ff @(posedge clk)
    if ( reset || (cache_resp_type != `VC_MEM_RESP_MSG_TYPE_READ)) begin 
        state_reg <= STATE_IDLE;
        counter <= 0; 
    end
    else begin
        if ( state_reg == STATE_IDLE) counter <= 5'd0; 
        if ( state_reg == STATE_RECEIVE && state_next == STATE_RECEIVE ) counter <= next_counter; 
        state_reg <= state_next;
    end

    //===================================================================
    //                      State Transitions 
    //===================================================================

    logic [4:0] counter; 
    logic [4:0] next_counter; 
    assign next_counter = counter + 1; 

    always_comb begin 
        case ( state_reg ) 
            STATE_IDLE: begin 
                if ( istream_val && istream_rdy ) begin 
                    state_next = STATE_RECEIVE;
                end
                else state_next = STATE_IDLE;
            end
            STATE_RECEIVE: begin 
                if ( istream_rdy && istream_val && counter < 16) begin 
                    state_next = STATE_RECEIVE;
                end
                else if ( counter >= 16 ) state_next = STATE_DONE; 
                else state_next = STATE_WAIT;
            end
            STATE_WAIT: begin 
                if ( istream_val && istream_rdy ) state_next = STATE_RECEIVE; 
                else state_next = STATE_WAIT;
            end 
            STATE_DONE:
                if ( ostream_rdy && ostream_val ) state_next = STATE_IDLE;   
                else state_next = STATE_DONE;
            default: state_next = STATE_IDLE;
        endcase
    end

    //===================================================================
    //                      State Outputs
    //===================================================================
    localparam mux_add  = 1'b1; 
    localparam mux_zero = 1'b0; 
    localparam mux_x    = 1'bx; 
    task cs
    (
        input cs_istream_rdy,
        input cs_ostream_val,
        input cs_incr_reg_en,
        input cs_incr_mux_sel,
        input cs_data_reg_en,
        input cs_data_mux_sel
    );
        begin
            istream_rdy       = cs_istream_rdy;
            ostream_val       = cs_ostream_val;
            incr_reg_en       = cs_incr_reg_en;
            incr_mux_sel      = cs_incr_mux_sel;
            data_reg_en       = cs_data_reg_en;
            data_mux_sel      = cs_data_mux_sel;
        end
    endtask

    always @(*) begin

        case ( state_reg )
            //                                                  incr  incr      data    data
            //                                  istream ostream reg   mux       reg     mux
            //                                  rdy        val  en    sel       en      sel
            STATE_IDLE:                     cs( 1,         0,    1,   mux_zero, 1,      mux_zero);
            STATE_RECEIVE:                  cs( 1,         0,    1,   mux_add,  1,      mux_add );
            STATE_WAIT:                     cs( 1,         0,    0,   mux_x,    0,      mux_x   );
            STATE_DONE:                     cs( 0,         1,    0,   mux_x,    0,      mux_x   );
            default:                        cs('x,        'x,   'x,   mux_x,    0,      mux_x   );
        endcase

    end

endmodule

`endif /* LAB3_CACHE_CACHE_MEM_RECEIVER_V */
