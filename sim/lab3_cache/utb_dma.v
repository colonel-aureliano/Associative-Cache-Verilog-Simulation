//========================================================================
// utb_dma
//========================================================================
// A basic Verilog unit test bench for the Cache Memory Sender/Receiver module

`default_nettype none
`timescale 1ps/1ps

`include "dma.v"
`include "mem-msgs-wide.v"
`include "vc/mem-msgs.v"

//------------------------------------------------------------------------
// Top-level module
//------------------------------------------------------------------------

module top(  input logic clk, input logic linetrace );

    logic         reset;
    logic         batch_send_istream_val;
    logic         batch_send_istream_rdy;
    logic         batch_send_ostream_val;
    logic         batch_send_ostream_rdy;
    logic [ 31:0] inp_addr;
    logic [511:0] inp_data;
    logic         rw; 

    logic         batch_receive_istream_val;
    logic         batch_receive_istream_rdy;
    logic         batch_receive_ostream_val;
    logic         batch_receive_ostream_rdy;
    mem_resp_4B_t  mem_resp_msg;
    logic [511:0] mem_data;

    mem_req_4B_t  send_mem_req;

    mem_req_64B_t   cache_req_msg;
    assign cache_req_msg.type_ = {2'b0, rw};
    assign cache_req_msg.data = inp_data;
    assign cache_req_msg.addr = inp_addr;

    mem_resp_64B_t  cache_resp_msg;
    assign mem_data = cache_resp_msg.data;

    //----------------------------------------------------------------------
    // Module instantiations
    //----------------------------------------------------------------------
    
    // Instantiate the processor datapath
    lab3_cache_Dma DUT
    ( 
        .cache_req_msg(cache_req_msg),
        .cache_req_val(batch_send_istream_val),
        .cache_req_rdy(batch_send_istream_rdy),

        .cache_resp_msg(cache_resp_msg),
        .cache_resp_val(batch_receive_ostream_val),
        .cache_resp_rdy(batch_receive_ostream_rdy),

        .mem_req_msg(send_mem_req),
        .mem_req_val(batch_send_ostream_val),
        .mem_req_rdy(batch_send_ostream_rdy),

        .mem_resp_msg(mem_resp_msg),
        .mem_resp_val(batch_receive_istream_val),
        .mem_resp_rdy(batch_receive_istream_rdy),
        .*
    ); 

    //----------------------------------------------------------------------
    // Run the Test Bench
    //----------------------------------------------------------------------

    logic [511:0] expected;
    initial begin

        $display("Start of Testbench");
        $display("Start send only test");
        // Initalize all the signal inital values.
        reset = 1; 
        batch_send_istream_val = 0; 
        batch_send_ostream_rdy = 0; 
        inp_addr = 32'hFFFFFFC0; 
        inp_data = {32'd1, 32'd2,  32'd3, 32'd4, 32'd5, 32'd6, 32'd7, 32'd8, 32'd9, 32'd10, 32'd11, 32'd12, 32'd13, 32'd14, 32'd15, 32'd16}; 
        rw       = 1; 
        $display("beginning: istream val is %d", batch_send_istream_val);
        $display("beginning: istream rdy is %d", batch_send_istream_rdy);

        @(negedge clk);
        reset = 0; 
        batch_send_istream_val = 1; 
        $display("beginning: istream val is %d", batch_send_istream_val);
        $display("beginning: istream rdy is %d", batch_send_istream_rdy);
        batch_receive_ostream_rdy = 1;

        // @(negedge clk)
        for(integer i = 0; i < 16; i++) begin 
            $display("in for loop: %d", i);
            batch_send_ostream_rdy = 1;  
            batch_receive_istream_val = 1;
            // @(negedge clk);
            while ( !batch_send_ostream_val ) begin 
                @(negedge clk);
                $display("in while: state is %d", DUT.state);
                $display("in while: next state is %d", DUT.state_next);
                $display("in while: istream val is %d", batch_send_istream_val);
                $display("in while: istream rdy is %d", batch_send_istream_rdy);
            end

            assertion("addr:", inp_addr + i * 4, send_mem_req.addr);
            expected = inp_data>>(i*32);
            assertion("data: ", expected[31:0], send_mem_req.data); 
            
            assertion("rw: ", 32'd1, {29'd0, send_mem_req.type_});
            @(negedge clk);
            batch_send_ostream_rdy = 0; 
        end
        batch_send_istream_val = 0; 
        
        @(negedge clk); 
        @(negedge clk); 
        assertion("end state: ", 32'd0, {29'd0, DUT.state});
        assertion("rdy: ", {31'd0, 1'd1}, {31'd0, batch_send_istream_rdy});

        $display("Start Send and Receive Test");
        test_case("Basic Test 1", {{16{32'd4}}});
        test_case("Basic Test 2", {{8{32'd2}},{8{32'd3}}});
        test_case("Basic Test 3", {{2{32'd1}},{14{32'd7}}});
        test_case("Basic Test 4", {{10{32'd38}},{6{32'hFFFFFFFF}}});
        test_case("Basic Test 5", {{5{32'd55}},{11{32'd26}}});
        test_case("Basic Test 6", {{7{32'hFFFFFFFF}},{9{32'd8000}}});
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


    logic [ 31:0] segmented_data [15:0]; 

    task test_case( string name, [511:0] test_input); 
        begin 
          $display("Test case: %s",name);
          reset = 1; 
          batch_receive_istream_val = 0;
          batch_receive_ostream_rdy = 0; 
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
            batch_receive_istream_val = 1;  
            batch_send_istream_val = 1; 
            batch_send_ostream_rdy = 1; 
            $display("wait on send ostream val");
            $display("state is %d", DUT.state);
            while ( !batch_send_ostream_val ) @(negedge clk);
            @(negedge clk);
            mem_resp_msg.data = segmented_data[i];
            mem_resp_msg.type_ = `VC_MEM_RESP_MSG_TYPE_READ;
            $display("wait on receive istream rdy");
            $display("state is %d", DUT.state);
            while ( !batch_receive_istream_rdy ) @(negedge clk);
          end

          #20;
          @(negedge clk);
          batch_receive_ostream_rdy = 1; 
          while ( !batch_receive_ostream_val ) @(negedge clk); 
          assertion512("data", test_input, mem_data);
        end
    endtask

  endmodule
