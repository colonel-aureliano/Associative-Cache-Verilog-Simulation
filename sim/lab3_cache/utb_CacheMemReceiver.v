//========================================================================
// utb_CacheMemReceiver
//========================================================================
// A basic Verilog unit test bench for the Cache Memory Receiver module

`default_nettype none
`timescale 1ps/1ps


`include "CacheMemReceiver.v"
`include "vc/trace.v"
`include "vc/mem-msgs.v"

//------------------------------------------------------------------------
// Top-level module
//------------------------------------------------------------------------

module top(  input logic clk, input logic linetrace );

    logic         reset;
    logic         istream_val;
    logic         istream_rdy;
    logic         ostream_val;
    logic         ostream_rdy;
    mem_resp_4B_t  cache_resp_msg;
    logic [511:0] mem_data;

    //----------------------------------------------------------------------
    // Module instantiations
    //----------------------------------------------------------------------
    
    // Instantiate the processor datapath
    lab3_cache_CacheMemReceiver DUT
    ( 
        .*
    ); 

    //----------------------------------------------------------------------
    // Run the Test Bench
    //----------------------------------------------------------------------

    task assertion( string varname, [511:0] expected, [511:0] actual ); 
        begin 
            assert(expected == actual) begin
                $display("%s is correct.  Expected: %h, Actual: %h", varname, expected, actual); pass();
            end else begin
                $display("%s is incorrect.  Expected: %h, Actual: %h", varname, expected, actual); fail(); 
            end 
        end
    endtask

    logic [ 31:0] segmented_data [15:0]; 

    task test_case( string name, [511:0] test_input); 
        begin 
          $display("Test case: %s",name);
          reset = 1; 
          istream_val = 0;
          ostream_rdy = 0; 
          @(negedge clk);
          reset = 0; 
          @(negedge clk);

          assign segmented_data[0]  = test_input[ 31 :  0]; 
          assign segmented_data[1]  = test_input[ 63 :  32]; 
          assign segmented_data[2]  = test_input[ 95 :  64]; 
          assign segmented_data[3]  = test_input[ 127 :  96]; 
          assign segmented_data[4]  = test_input[ 159 :  128]; 
          assign segmented_data[5]  = test_input[ 191 :  160]; 
          assign segmented_data[6]  = test_input[ 223 :  192]; 
          assign segmented_data[7]  = test_input[ 255 :  224]; 
          assign segmented_data[8]  = test_input[ 287 :  256]; 
          assign segmented_data[9]  = test_input[ 319 :  288]; 
          assign segmented_data[10] = test_input[ 351 :  320]; 
          assign segmented_data[11] = test_input[ 383 :  352]; 
          assign segmented_data[12] = test_input[ 415 :  384]; 
          assign segmented_data[13] = test_input[ 447 :  416]; 
          assign segmented_data[14] = test_input[ 479 :  448]; 
          assign segmented_data[15] = test_input[ 511 :  480]; 
          
          for(integer i = 0; i < 16; i++) begin 
            // $display("in for loop: %d", i);
            @(negedge clk);
            while ( !istream_rdy ) @(negedge clk);
            cache_resp_msg.data = segmented_data[i];
            cache_resp_msg.type_ = `VC_MEM_RESP_MSG_TYPE_READ;
            istream_val = 1;  
          end
          #20;
          @(negedge clk);
          ostream_rdy = 1; 
          while ( !ostream_val ) @(negedge clk); 
          assertion("data", test_input, mem_data);
        end
    endtask

    task noisy_test_case( string name, [511:0] test_input); 
        begin 
          $display("Test case: %s",name);
          reset = 1; 
          istream_val = 0;
          ostream_rdy = 0; 
          @(negedge clk);
          reset = 0; 

          assign segmented_data[0]  = test_input[ 31 :  0]; 
          assign segmented_data[1]  = test_input[ 63 :  32]; 
          assign segmented_data[2]  = test_input[ 95 :  64]; 
          assign segmented_data[3]  = test_input[ 127 :  96]; 
          assign segmented_data[4]  = test_input[ 159 :  128]; 
          assign segmented_data[5]  = test_input[ 191 :  160]; 
          assign segmented_data[6]  = test_input[ 223 :  192]; 
          assign segmented_data[7]  = test_input[ 255 :  224]; 
          assign segmented_data[8]  = test_input[ 287 :  256]; 
          assign segmented_data[9]  = test_input[ 319 :  288]; 
          assign segmented_data[10] = test_input[ 351 :  320]; 
          assign segmented_data[11] = test_input[ 383 :  352]; 
          assign segmented_data[12] = test_input[ 415 :  384]; 
          assign segmented_data[13] = test_input[ 447 :  416]; 
          assign segmented_data[14] = test_input[ 479 :  448]; 
          assign segmented_data[15] = test_input[ 511 :  480]; 
          
          for(integer i = 0; i < 16; i++) begin 
            // $display("in for loop: %d", i);
            @(negedge clk);
            while ( !istream_rdy ) @(negedge clk);
            cache_resp_msg.data = segmented_data[i];
            cache_resp_msg.type_ = `VC_MEM_RESP_MSG_TYPE_WRITE;
            istream_val = 1;  
          end
          #20;  
          @(negedge clk);
          ostream_rdy = 1; 
          @(negedge clk);
          ostream_rdy = 0; 
          for(integer i = 0; i < 16; i++) begin 
            // $display("in for loop: %d", i);
            @(negedge clk);
            while ( !istream_rdy ) @(negedge clk);
            cache_resp_msg.data = segmented_data[i];
            cache_resp_msg.type_ = `VC_MEM_RESP_MSG_TYPE_READ;
            istream_val = 1;  
          end
          #20;
          @(negedge clk);
          ostream_rdy = 1; 
          while ( !ostream_val ) @(negedge clk); 
          assertion("data", test_input, mem_data);
        end
    endtask

    initial begin

        $display("Start of Testbench");
        test_case("Basic Test 1", {{16{32'd4}}});
        test_case("Basic Test 2", {{8{32'd2}},{8{32'd3}}});
        test_case("Basic Test 3", {{2{32'd1}},{14{32'd7}}});
        noisy_test_case("Noisy Test 1", {{16{32'd4}}});
        noisy_test_case("Noisy Test 2", {{8{32'd2}},{8{32'd3}}});

        $finish();

    end

endmodule
