//========================================================================
// utb_CacheMemSender
//========================================================================
// A basic Verilog unit test bench for the Cache Memory Sender module

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
    logic         rw; 
    // logic [ 31:0] mem_addr;
    // logic [ 31:0] mem_data;

    mem_req_4B_t  mem_req; 
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
        istream_val = 0; 
        ostream_rdy = 0; 
        inp_addr = 32'hFFFFFFC0; 
        inp_data = {32'd1, 32'd2,  32'd3, 32'd4, 32'd5, 32'd6, 32'd7, 32'd8, 32'd9, 32'd10, 32'd11, 32'd12, 32'd13, 32'd14, 32'd15, 32'd16}; 
        rw       = 1; 
        $display("beginning: istream val is %d", DUT.ctrl.istream_val);
        $display("beginning: istream rdy is %d", DUT.ctrl.istream_rdy);

        @(negedge clk);
        reset = 0; 
        istream_val = 1; 
        $display("beginning: istream val is %d", DUT.ctrl.istream_val);
        $display("beginning: istream rdy is %d", DUT.ctrl.istream_rdy);

        // @(negedge clk)
        for(integer i = 0; i < 16; i++) begin 
            $display("in for loop: %d", i);
            // istream_rdy = 0;
            ostream_rdy = 1;  
            @(negedge clk);
            while ( !ostream_val ) begin 
                @(negedge clk);
                $display("in while: state is %d", DUT.ctrl.state_reg);
                $display("in while: next state is %d", DUT.ctrl.state_next);
                $display("in while: istream val is %d", DUT.ctrl.istream_val);
                $display("in while: istream rdy is %d", DUT.ctrl.istream_rdy);
            end
        

            assertion("addr:", inp_addr + i * 4, mem_req.addr);
            expected = inp_data>>(i*32);
            assertion("data: ", expected[31:0], mem_req.data); 
            ostream_rdy = 0; 
            assertion("rw: ", 32'd1, {29'd0, mem_req.type_});
            @(negedge clk);
        end
        
        @(negedge clk); 
        assertion("end state: ", 32'd0, {29'd0, DUT.ctrl.state_reg});
        assertion("rdy: ", {31'd0, 1'd1}, {31'd0, istream_rdy});

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
