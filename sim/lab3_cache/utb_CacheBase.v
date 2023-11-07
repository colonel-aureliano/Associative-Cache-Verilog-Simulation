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

            while ( !cache_req_val ) @(negedge clk); 

            cache_req_rdy = 0; 
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            @(negedge clk); 
        end

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

endmodule
