//=========================================================================
// A Cache-Memory Communication Module
//=========================================================================

`ifndef LAB3_CACHE_DMA_V
`define LAB3_CACHE_DMA_V


`include "mem-msgs-wide.v"
`include "vc/mem-msgs.v"
`include "vc/regs.v"

module lab3_cache_Dma
(
    input   logic           clk,
    input   logic           reset,
    
    // cache to dma
    input   mem_req_64B_t   cache_req_msg,
    input   logic           cache_req_val,
    output  logic           cache_req_rdy,

    output  mem_resp_64B_t  cache_resp_msg,
    output  logic           cache_resp_val,
    input   logic           cache_resp_rdy,

    // dma to memory
    output  mem_req_4B_t    mem_req_msg,
    output  logic           mem_req_val,
    input   logic           mem_req_rdy,

    input   mem_resp_4B_t   mem_resp_msg,
    input   logic           mem_resp_val,
    output  logic           mem_resp_rdy
);

    typedef enum logic [$clog2(8)-1:0] {
        STATE_IDLE, // waiting for start
        STATE_MEM_SEND,
        STATE_MEM_WAIT,
        STATE_RESP
    } state_t;

    state_t     state, state_next;
    
    logic   [511:0]   write_data_temp; // from cache
    logic   [511:0]   read_data_temp; // from memory

    
    logic   write_data_temp_reg_en;
    logic   read_data_temp_reg_en;

    logic   [5:0]  counter, counter_next;
    logic   [5:0]  resp_counter;
    assign resp_counter = counter - 1;
    vc_EnReg #(512) write_data_reg
    (
        .clk(clk),
        .reset(reset),
        .d(cache_req_msg.data),
        .q(write_data_temp),
        .en(write_data_temp_reg_en)
    );

    temp_reg512 read_data_reg
    (
        .clk(clk),
        .d(mem_resp_msg.data),
        .en(read_data_temp_reg_en),
        .q(read_data_temp),
        .addr(resp_counter[3:0])
    );

    logic [ 31:0] segmented_data [15:0]; 
    assign segmented_data[0]  = write_data_temp[ 31 :  0]; 
    assign segmented_data[1]  = write_data_temp[ 63 :  32]; 
    assign segmented_data[2]  = write_data_temp[ 95 :  64]; 
    assign segmented_data[3]  = write_data_temp[ 127 :  96]; 
    assign segmented_data[4]  = write_data_temp[ 159 :  128]; 
    assign segmented_data[5]  = write_data_temp[ 191 :  160]; 
    assign segmented_data[6]  = write_data_temp[ 223 :  192]; 
    assign segmented_data[7]  = write_data_temp[ 255 :  224]; 
    assign segmented_data[8]  = write_data_temp[ 287 :  256]; 
    assign segmented_data[9]  = write_data_temp[ 319 :  288]; 
    assign segmented_data[10] = write_data_temp[ 351 :  320]; 
    assign segmented_data[11] = write_data_temp[ 383 :  352]; 
    assign segmented_data[12] = write_data_temp[ 415 :  384]; 
    assign segmented_data[13] = write_data_temp[ 447 :  416]; 
    assign segmented_data[14] = write_data_temp[ 479 :  448]; 
    assign segmented_data[15] = write_data_temp[ 511 :  480]; 


    // lock the opaque, type, addr ===============================
    logic   reg_opaque_en;
    logic   [7:0] locked_opaque;
    vc_EnReg #(8) cache_opaque_reg
    (
        .clk(clk),
        .reset(reset),
        .d(cache_req_msg.opaque),
        .q(locked_opaque),
        .en(reg_opaque_en)
    );

    logic   req_type_en;
    logic   [2:0] locked_type;
    vc_EnReg #(3) req_type_reg
    (
        .clk(clk),
        .reset(reset),
        .d(cache_req_msg.type_),
        .q(locked_type),
        .en(req_type_en)
    );

    logic   reg_addr_en;
    logic   [31:0] locked_addr;
    vc_EnReg #(32) req_addr_reg
    (
        .clk(clk),
        .reset(reset),
        .d(cache_req_msg.addr),
        .q(locked_addr),
        .en(reg_addr_en)
    );
    

    always_comb begin
        state_next = state;
        counter_next = counter;

        // internel status
        read_data_temp_reg_en = 0;
        write_data_temp_reg_en = 0;
        reg_opaque_en = 0;
        req_type_en = 0;
        reg_addr_en = 0;
        // direct state output default
        cache_req_rdy = 0;
        cache_resp_val = 0;
        mem_req_val = 0;
        mem_resp_rdy = 0;
        //
        mem_req_msg.addr = 0;
        mem_req_msg.data = 0;
        case (state)
            STATE_IDLE: begin
                cache_req_rdy = 1;
                if (cache_req_val) begin
                    // reset counter, lock write_data
                    counter_next = 0;
                    write_data_temp_reg_en = 1;
                    reg_opaque_en = 1;
                    req_type_en = 1;
                    reg_addr_en = 1;
                    // state transition
                    state_next = STATE_MEM_SEND;
                end
            end
            STATE_MEM_SEND: begin
                mem_req_val = 1;
                mem_req_msg.addr = locked_addr + counter*4;
                mem_req_msg.data = segmented_data[counter[3:0]];
                if (mem_req_rdy) begin
                    // state transition
                    state_next = STATE_MEM_WAIT;
                    counter_next = counter + 1;
                end
            end
            STATE_MEM_WAIT: begin
                mem_resp_rdy = 1;
                if (mem_resp_val) begin
                    // write to temp
                    read_data_temp_reg_en = 1;
                    // state transition
                    if (counter == 16) begin
                        // reach the end of read, go to response to cache
                        state_next = STATE_RESP;
                    end else begin
                        // continue reading
                        state_next = STATE_MEM_SEND;
                        // if ready in same cycle, then send request immediately
                        if (mem_req_rdy) begin
                            mem_req_val = 1;
                            mem_req_msg.addr = locked_addr + counter*4;
                            mem_req_msg.data = segmented_data[counter[3:0]];
                            // state transition
                            counter_next = counter + 1;
                            state_next = STATE_MEM_WAIT;
                        end
                    end
                end
            end
            STATE_RESP: begin
                cache_resp_val = 1;
                
                if (cache_resp_rdy) begin
                    // state transition
                    state_next = STATE_IDLE;
                end
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

    assign mem_req_msg.type_ = locked_type;
    assign mem_req_msg.opaque = locked_opaque;
    assign mem_req_msg.len = 0;

    assign cache_resp_msg.type_ = locked_type;
    assign cache_resp_msg.opaque = locked_opaque;
    assign cache_resp_msg.test = 0;
    assign cache_resp_msg.len = 0;
    assign cache_resp_msg.data = read_data_temp;


    always_ff @(posedge clk) begin
        if (reset) begin
            state <= STATE_IDLE;
            counter <= 0;
        end else begin
            state <= state_next;
            counter <= counter_next;
        end
    end
endmodule

module temp_reg512
(
    input   logic   clk,

    input   logic   [31:0]    d,
    input   logic             en,
    output  logic   [511:0]   q,
    input   logic   [3:0]     addr
);

    logic [ 31:0] segmented_data2 [15:0]; 
    assign q[ 31 :  0] = segmented_data2[0]; 
    assign q[ 63 :  32] = segmented_data2[1]; 
    assign q[ 95 :  64] = segmented_data2[2]; 
    assign q[ 127 :  96] = segmented_data2[3]; 
    assign q[ 159 :  128] = segmented_data2[4]; 
    assign q[ 191 :  160] = segmented_data2[5]; 
    assign q[ 223 :  192] = segmented_data2[6]; 
    assign q[ 255 :  224] = segmented_data2[7]; 
    assign q[ 287 :  256] = segmented_data2[8]; 
    assign q[ 319 :  288] = segmented_data2[9]; 
    assign q[ 351 :  320] = segmented_data2[10]; 
    assign q[ 383 :  352] = segmented_data2[11]; 
    assign q[ 415 :  384] = segmented_data2[12]; 
    assign q[ 447 :  416] = segmented_data2[13]; 
    assign q[ 479 :  448] = segmented_data2[14]; 
    assign q[ 511 :  480] = segmented_data2[15]; 

    always_ff @(posedge clk) begin
        if (en) begin
            segmented_data2[addr] <= d; 
        end
    end
endmodule

`endif
