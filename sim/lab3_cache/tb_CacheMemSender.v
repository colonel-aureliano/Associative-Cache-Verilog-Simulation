//========================================================================
// utb_ProcBaseDpath
//========================================================================
// A basic Verilog unit test bench for the Processor Base Datapath module

`default_nettype none
`timescale 1ps/1ps


`include "CacheMemSender.v"
`include "vc/trace.v"

//------------------------------------------------------------------------
// Top-level module
//------------------------------------------------------------------------

module top(  input logic clk, input logic linetrace );

    logic         reset;
    logic         istream_val;
    logic         istream_rdy;
    logic         ostream_val;
    logic         ostream_rdy;
    logic [ 31:0] inp_addr;
    logic [511:0] inp_data;
    logic [ 31:0] mem_addr;
    logic [ 31:0] mem_data;

    //----------------------------------------------------------------------
    // Module instantiations
    //----------------------------------------------------------------------
    
    // Instantiate the processor datapath
    lab3_cache_CacheMemSender DUT
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
        istream_rdy = 0; 
        ostream_val = 0; 
        inp_addr = 32'hFFFFFFFF; 
        inp_data = {32'd1, 32'd2,  32'd3, 32'd4, 32'd5, 32'd6, 32'd7, 32'd8, 32'd9, 32'd10, 32'd11, 32'd12, 32'd13, 32'd14, 32'd15, 32'd16}; 
        @(negedge clk) 
        reset = 0; 
        istream_rdy = 1; 

        for(integer i = 0; i < 16; i++) begin 
            
            istream_rdy = 1; 
            while ( !ostream_val ) @(negedge clk) 
            

            ostream_rdy = 1; 
            assertion("addr:", inp_addr&32'hFFFFFFC0 + i * 32, mem_addr);
            expected = inp_data>>(i*32);
            assertion("indexing: ", expected[31:0], mem_data); 
        end

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
