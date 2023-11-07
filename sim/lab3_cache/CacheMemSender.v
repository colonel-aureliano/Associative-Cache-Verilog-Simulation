//=========================================================================
// Cache Memory Sender 512B module
//=========================================================================

`ifndef LAB3_CACHE_CACHE_MEM_SENDER_V
`define LAB3_CACHE_CACHE_MEM_SENDER_V

`include "vc/arithmetic.v"
`include "vc/mem-msgs.v"
`include "vc/muxes.v"
`include "vc/regs.v"
`include "vc/regfiles.v"

module lab3_cache_CacheMemSender

(
    input  logic         clk,
    input  logic         reset,
 
    input  logic         istream_val,
    output logic         istream_rdy,
 
    output logic         ostream_val,
    input  logic         ostream_rdy,

    input  logic [ 31:0] inp_addr,
    input  logic [511:0] inp_data,
    input  logic         rw,            // 0 if read, 1 if write 

    output mem_req_4B_t  mem_req
);

    // Control signals

    logic incr_reg_en;
    logic incr_mux_sel;

    logic [31:0] mem_addr; 
    logic [31:0] mem_data; 

    logic [31:0] addr; 
    logic [31:0] data; 
    // Instantiate and connect datapath

    lab3_cache_CacheMemSender_Dpath dpath
    (
        .clk           (clk),
        .reset         (reset), 
        .inp_addr      (inp_addr),
        .inp_data      (inp_data),
        .mem_addr      (addr), 
        .mem_data      (data),
        .*
    );

    // Instantiate and connect control unit

    lab3_cache_CacheMemSender_Control ctrl
    (
        .*
    );


    assign mem_addr = addr & {32{ostream_val}};
    assign mem_data = data & {32{ostream_val}};

    assign mem_req = {2'd0, rw, 8'd0, mem_addr, 2'd0, mem_data}; 

endmodule

module lab3_cache_CacheMemSender_Dpath
(
    input  logic         clk, 
    input  logic         reset,

    input  logic [ 31:0] inp_addr,
    input  logic [511:0] inp_data,            // 64B

    output logic [ 31:0] mem_addr, 
    output logic [ 31:0] mem_data, 

    //---------------------- control inputs ------------
    input  logic         incr_reg_en, 
    input  logic         incr_mux_sel

);
    
    logic [ 25:0] tag; 
    assign tag = inp_addr[31:6];

    logic [  5:0] offset; 
    assign offset = inp_addr[5:0]; 

    logic [ 31:0] segmented_data [15:0]; 
    assign segmented_data[0]  = inp_data[ 31 :  0]; 
    assign segmented_data[1]  = inp_data[ 63 :  32]; 
    assign segmented_data[2]  = inp_data[ 95 :  64]; 
    assign segmented_data[3]  = inp_data[ 127 :  96]; 
    assign segmented_data[4]  = inp_data[ 159 :  128]; 
    assign segmented_data[5]  = inp_data[ 191 :  160]; 
    assign segmented_data[6]  = inp_data[ 223 :  192]; 
    assign segmented_data[7]  = inp_data[ 255 :  224]; 
    assign segmented_data[8]  = inp_data[ 287 :  256]; 
    assign segmented_data[9]  = inp_data[ 319 :  288]; 
    assign segmented_data[10] = inp_data[ 351 :  320]; 
    assign segmented_data[11] = inp_data[ 383 :  352]; 
    assign segmented_data[12] = inp_data[ 415 :  384]; 
    assign segmented_data[13] = inp_data[ 447 :  416]; 
    assign segmented_data[14] = inp_data[ 479 :  448]; 
    assign segmented_data[15] = inp_data[ 511 :  480]; 

    //=======================================================================
    //                      increment addr by 4 each cycle
    //=======================================================================

    logic [  5:0] next_offset; 
    logic [  5:0] incr_reg_out;

    vc_EnReg#(6) incr_reg
    (
        .clk   (clk),
        .reset (reset),
        .en    (incr_reg_en),
        .d     (next_offset),
        .q     (incr_reg_out)
    );


    logic [ 5:0] incr_mux_out;
    vc_Mux2#(6) incr_mux
    (
        .in0  (offset),
        .in1  (incr_reg_out),
        .sel  (incr_mux_sel),
        .out  (incr_mux_out)
    );
    
    assign next_offset = incr_mux_out + 4; 

    assign mem_addr = {tag, incr_mux_out}; 

    //=======================================================================
    //                      outputting correct 4B data
    //=======================================================================
    // assign mem_data = segmented_data[incr_mux_out[5:2]]; 

    logic [31:0] sel_mux_out_lower_res; 

    vc_Mux8#(32) selector_mux_lower
    (
        .in0  (segmented_data[0]),
        .in1  (segmented_data[1]),
        .in2  (segmented_data[2]),
        .in3  (segmented_data[3]),
        .in4  (segmented_data[4]),
        .in5  (segmented_data[5]),
        .in6  (segmented_data[6]),
        .in7  (segmented_data[7]),
        .sel  (incr_mux_out[4:2]),
        .out  (sel_mux_out_lower_res)
    );

    logic [31:0] sel_mux_out_upper_res; 
    vc_Mux8#(32) selector_mux_upper
    (
        .in0  (segmented_data[8]),
        .in1  (segmented_data[9]),
        .in2  (segmented_data[10]),
        .in3  (segmented_data[11]),
        .in4  (segmented_data[12]),
        .in5  (segmented_data[13]),
        .in6  (segmented_data[14]),
        .in7  (segmented_data[15]),
        .sel  (incr_mux_out[4:2]),
        .out  (sel_mux_out_upper_res)
    );

    vc_Mux2#(32) selector_mux
    (
        .in0 (sel_mux_out_lower_res) , 
        .in1 (sel_mux_out_upper_res), 
        .sel (incr_mux_out[5]), 
        .out (mem_data)
    );

endmodule

module lab3_cache_CacheMemSender_Control
(
    input  logic clk, 
    input  logic reset, 

    // Dataflow signals
    input  logic istream_val,
    output logic istream_rdy,

    output logic ostream_val,
    input  logic ostream_rdy,
    
    // Ctrl signals 
    output logic incr_mux_sel, 
    output logic incr_reg_en
);

    //----------------------------------------------------------------------
    // States
    //----------------------------------------------------------------------

    localparam STATE_IDLE = 3'd0;
    localparam STATE_CALC = 3'd1;
    localparam STATE_SEND = 3'd2;
    localparam STATE_WAIT = 3'd3;
    localparam STATE_DONE = 3'd4; 

    logic [2:0] state_reg;
    logic [2:0] state_next;

    always_ff @(posedge clk)
    if ( reset ) begin 
        state_reg <= STATE_IDLE;
        counter <= 0; 
    end
    else begin
        if ( state_reg == STATE_IDLE) counter <= 5'd0; 
        if ( state_reg == STATE_SEND && state_next == STATE_CALC ) counter <= next_counter; 
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
                    state_next = STATE_CALC;
                end
                else state_next = STATE_IDLE;
            end
            STATE_CALC: if ( !ostream_rdy ) state_next = STATE_WAIT; else state_next = STATE_SEND; 
            STATE_SEND: begin 
                if ( ostream_rdy && ostream_val && counter < 16) begin 
                    state_next = STATE_CALC;
                end
                else if ( ostream_rdy && ostream_val ) state_next = STATE_DONE; 
                else state_next = STATE_SEND;
            end  
            STATE_WAIT: begin 
                if ( ostream_rdy ) state_next = STATE_SEND; 
                else state_next = STATE_WAIT;
            end 
            STATE_DONE: state_next = STATE_IDLE;
            default: state_next = STATE_IDLE;
        endcase
    end


    //===================================================================
    //                      State Transitions 
    //===================================================================
    localparam mux_reg = 1; 
    localparam mux_inp = 0; 
    localparam mux_x   = 1'bx; 
    task cs
    (
        input cs_istream_rdy,
        input cs_ostream_val,
        input cs_incr_reg_en,
        input cs_incr_mux_sel
    );
        begin
            istream_rdy       = cs_istream_rdy;
            ostream_val       = cs_ostream_val;
            incr_reg_en       = cs_incr_reg_en;
            incr_mux_sel      = cs_incr_mux_sel;
        end
    endtask

    always @(*) begin

        case ( state_reg )

            //                                  istream ostream reg     mux  
            //                                  rdy        val   en     sel  
            STATE_IDLE:                     cs( 1,         0,    0,   mux_x   );
            STATE_CALC: if ( counter == 0 ) cs( 0,         0,    0,   mux_inp );
                        else                cs( 0,         0,    1,   mux_reg );
            STATE_SEND: if ( counter == 0 ) cs( 0,         1,    0,   mux_inp );
                        else                cs( 0,         1,    0,   mux_reg );
            STATE_WAIT:                     cs( 0,         0,    0,   mux_x   );
            STATE_DONE:                     cs( 0,         0,   'x,   mux_x   );
            default:                        cs('x,        'x,   'x,   mux_x   );
        endcase

    end



endmodule

`endif /* LAB3_CACHE_CACHE_MEM_SENDER_V */
