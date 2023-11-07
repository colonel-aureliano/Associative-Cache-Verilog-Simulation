//========================================================================
// utb_CacheBase
//========================================================================
// A basic Verilog unit test bench for the Cache Memory Sender module

`default_nettype none
`timescale 1ps/1ps


`include "CacheBase.v"
`include "vc/trace.v"
`include "vc/mem-msgs.v"

//------------------------------------------------------------------------
// Top-level module
//------------------------------------------------------------------------

module top(  input logic clk, input logic linetrace );

    logic         reset;

      // Read port 0 (combinational read)

    logic         memreq_val;
    logic         memreq_rdy;
    mem_req_4B_t  memreq_msg;

    logic         memresp_val;
    logic         memresp_rdy;
    mem_resp_4B_t memresp_msg;

    logic         cache_req_val;
    logic         cache_req_rdy;
    mem_req_4B_t  cache_req_msg;
 
    logic         cache_resp_val;
    logic         cache_resp_rdy;
    mem_resp_4B_t cache_resp_msg;


  // flush
    logic         flush;
    logic         flush_done;
    assign flush = 0; 
    //----------------------------------------------------------------------
    // Module instantiations
    //----------------------------------------------------------------------
    
    // Instantiate the processor datapath
    lab3_cache_CacheBase DUT
    ( 
        .*
    ); 

    //----------------------------------------------------------------------
    // Run the Test Bench
    //----------------------------------------------------------------------

    logic [511:0] expected;
    logic [31:0] holder; 
    initial begin

        $display("Start of Testbench");
        // Initalize all the signal inital values.
        reset = 1; 
        memreq_val = 0; 
        memresp_rdy = 0; 

        cache_req_rdy = 0; 
        cache_resp_val = 0;
        
        @(negedge clk);
        reset = 0; 
        @(negedge clk);

        memreq_val = 1; 
        memreq_msg = {3'd0, 8'd0, 21'd15, 5'd2, 4'd1, 2'd00, 2'd0, 32'hDEADBEEF}; // read request with tag 15, index 2, and offset 1
        
        cache_req_rdy = 1; 
        
        cache_resp_val = 0; 

        for (integer i = 0; i < 16; i++) begin 
            // should get 16 write requests to the memory 

            cache_req_rdy = 1; 
            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 

            cache_req_rdy = 0; 
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            @(negedge clk); 
        end

        @(negedge clk); 
        @(negedge clk); 
        memreq_val = 0; 
        for (integer i = 0; i < 16; i++) begin 
            assign holder = i; 
            cache_resp_msg = {3'd0, 8'd0, 2'd0, 2'd0, holder};
            cache_resp_val = 1; 
            
            @(negedge clk); 
            while ( !cache_resp_rdy ) @(negedge clk); 

            cache_resp_val = 0; 
            @(negedge clk);
        end
        @(negedge clk); 
        
        assertion512("new data", {32'hF,32'hE,32'hD,32'hC,32'hB,32'hA,32'h9,32'h8,32'h7,32'h6,32'h5,32'h4,32'h3,32'h2,32'h1,32'h0}, DUT.dpath.data_array.rfile[2]); 

        @(negedge clk); 
        while ( memresp_val ) @(negedge clk); 

        assertion("mem resp output: ", 32'd1, memresp_msg.data);
        
        memresp_rdy = 1; 
        @(negedge clk); 
        

        // ====================================================================
        //                      write on matching tag, and make dirty
        // ====================================================================

        memresp_rdy = 0;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd15, 5'd2, 4'd3, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 15, index 2, and offset 3
        
        @(negedge clk); 
        for (integer i = 0; i < 50; i++) begin 
            $display("iteration %d", i);
            if ( memresp_val ) break;
            @(negedge clk); 
        end
                
        @(negedge clk); 
        assertion512("new data: ", {32'hF,32'hE,32'hD,32'hC,32'hB,32'hA,32'h9,32'h8,32'h7,32'h6,32'h5,32'h4,32'hDEADBEEF,32'h2,32'h1,32'h0}, DUT.dpath.data_array.rfile[2]); 

        assertion("dirty: ", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[2]}); 

        memresp_rdy = 1; 
        @(negedge clk);

        // ====================================================================
        //          write on mismatching tag, evict, refill, make dirty
        // ====================================================================

        
        memresp_rdy = 0;
        memresp_rdy = 0;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd7, 5'd2, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3

        @(negedge clk); 

        assertion("dirty: ", 32'd1, {31'd0, DUT.dpath.is_dirty_0}); 
        assertion("tagmatch: ", 32'd0, {31'd0, DUT.dpath.tarray_match}); 
        
        assign expected = {32'hF,32'hE,32'hD,32'hC,32'hB,32'hA,32'h9,32'h8,32'h7,32'h6,32'h5,32'h4,32'hDEADBEEF,32'h2,32'h1,32'h0}; 
        assign holder = {21'd15, 5'd2, 6'd0}; 
        cache_req_rdy = 0; 
        for (integer i = 0; i < 16; i++) begin 
            // should get 16 write requests to the memory 

            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 
            
            assertion("is write request", {29'd0, `VC_MEM_REQ_MSG_TYPE_WRITE}, {29'd0, cache_req_msg.type_});
            assertion("write addr: ", holder + i * 4, cache_req_msg.addr);
            cache_req_rdy = 1; 
            @(negedge clk); 

        end

        #20;
        $finish();

    end
  
    task assertion( string varname, [31:0] expected, [31:0] actual ); 
        begin 
            assert(expected == actual) begin
                $display("%s is correct.  Expected: %h, Actual: %h", varname, expected, actual); pass();
            end else begin
                $display("%s is incorrect.  Expected: %h, Actual: %h", varname, expected, actual); fail(); 
            end 
        end
    endtask

    task assertion512( string varname, [511:0] expected, [511:0] actual ); 
        begin 
            assert(expected == actual) begin
                $display("%s is correct.  Expected: %h, Actual: %h", varname, expected, actual); pass();
            end else begin
                $display("%s is incorrect.  Expected: %h, Actual: %h", varname, expected, actual); fail(); 
            end 
        end
    endtask


endmodule
