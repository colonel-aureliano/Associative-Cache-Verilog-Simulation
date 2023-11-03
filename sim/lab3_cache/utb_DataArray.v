//========================================================================
// utb_CacheMemSender
//========================================================================
// A basic Verilog unit test bench for the Cache Memory Sender module

`default_nettype none
`timescale 1ps/1ps


`include "DataArray.v"
`include "vc/trace.v"

//------------------------------------------------------------------------
// Top-level module
//------------------------------------------------------------------------

module top(  input logic clk, input logic linetrace );

    logic         reset;

      // Read port 0 (combinational read)

    logic [  4:0] read_addr0;
    logic [511:0] read_data0;

      // Read port 1 (combinational read)

    logic [  4:0] read_addr1;
    logic [511:0] read_data1;

      // Write port (sampled on the rising clock edge)

    logic         write_en0;
    logic [  4:0] write_addr0;
    logic [511:0] write_data0;
    logic [ 15:0] write_word_en_0;    // assume one-hot encoding

      // Write port (sampled on the rising clock edge)

    logic         write_en1;
    logic [  4:0] write_addr1;
    logic [511:0] write_data1;
    logic [ 15:0] write_word_en_1;

    //----------------------------------------------------------------------
    // Module instantiations
    //----------------------------------------------------------------------
    
    // Instantiate the processor datapath
    lab3_cache_DataArray DUT
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
        write_en0 = 0;
        write_addr0 = 0;
        write_data0 = 0;
        write_word_en_0 = 0;    // assume one-hot encoding


        @(negedge clk);
        reset = 0; 
        write_addr0 = 2; 
        write_data0 = {32'd1, 32'd2,  32'd3, 32'd4, 32'd5, 32'd6, 32'd7, 32'd8, 32'd9, 32'd10, 32'd11, 32'd12, 32'd13, 32'd14, 32'd15, 32'd16}; 
        write_word_en_0 = 16'b10; 
        write_en0 = 1;
        @(negedge clk);         
        assertion("check response", {{14{32'd0}}, 32'd15, 32'd0}, DUT.rfile[2]);
        
        write_word_en_0 = 16'b100; 

        @(negedge clk); 
        assertion("check response", {{13{32'd0}}, 32'd14, 32'd15, 32'd0}, DUT.rfile[2]);

        write_word_en_0 = 16'hFFFF; 


        @(negedge clk); 
        assertion("check response", write_data0, DUT.rfile[2]);


        $finish();

    end
  
    task assertion( string varname, [511:0] expected, [511:0] actual ); 
        begin 
            assert(expected == actual) begin
                $display("%s is correct.  Expected: %h, Actual: %h", varname, expected, actual); pass();
            end else begin
                $display("%s is incorrect.  Expected: %h, Actual: %h", varname, expected, actual); fail(); 
            end 
        end
    endtask

endmodule
