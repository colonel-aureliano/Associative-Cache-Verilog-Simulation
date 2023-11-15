//========================================================================
// utb_CacheAlt
//========================================================================
// A basic Verilog unit test bench for the Cache Alternative Design module

`default_nettype none
`timescale 1ps/1ps


`include "CacheAlt.v"
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
    //----------------------------------------------------------------------
    // Module instantiations
    //----------------------------------------------------------------------
    
    // Instantiate the processor datapath
    lab3_cache_CacheAlt DUT
    ( 
        .*
    ); 

    //----------------------------------------------------------------------
    // Run the Test Bench
    //----------------------------------------------------------------------

    logic clock_counter; 

    logic [511:0] expected;
    logic [31:0] holder; 
    initial begin

        $display("Start of Testbench");
        // Initalize all the signal inital values.
        flush = 0;
        reset = 1; 
        memreq_val = 0; 
        memresp_rdy = 1; 

        cache_req_rdy = 0; 
        cache_resp_val = 0;
        
        @(negedge clk);
        reset = 0; 
        @(negedge clk);
        // ==========================================================================
        //                  read request,!tag_match, not dirty, refill, then read
        // ==========================================================================
        $display("========================tag 15, index 2, and offset 1===================");

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
        memresp_rdy = 0; 
        for (integer i = 0; i < 16; i++) begin 
            // writing in value for the refill
            assign holder = i; 
            cache_resp_msg = {3'd0, 8'd0, 2'd0, 2'd0, holder};
            cache_resp_val = 1; 
            
            @(negedge clk); 
            while ( !cache_resp_rdy ) @(negedge clk); 

            cache_resp_val = 0; 
            @(negedge clk);
        end

        @(negedge clk); 
        
        assertion("same cycle val", 32'd1, {31'd0, memresp_val});
        assertion512("new data", {32'hF,32'hE,32'hD,32'hC,32'hB,32'hA,32'h9,32'h8,32'h7,32'h6,32'h5,32'h4,32'h3,32'h2,32'h1,32'h0}, DUT.dpath.data_array.rfile[34]); 

        assertion("mem resp output ", 32'd1, memresp_msg.data);
        
        memresp_rdy = 1; 
        @(negedge clk); 
        
        // ====================================================================
        //       write on matching tag, and make dirty, should be same cycle
        // ====================================================================
        $display("========================write tag 15, index 2, and offset 1===================");
        
        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd15, 5'd2, 4'd3, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 15, index 2, and offset 3
        
        #0.5; 
        assertion("assert single cycle valid", 32'd1, {31'd0, memresp_val}); 
        @(negedge clk);
        assertion512("new data", {32'hF,32'hE,32'hD,32'hC,32'hB,32'hA,32'h9,32'h8,32'h7,32'h6,32'h5,32'h4,32'hDEADBEEF,32'h2,32'h1,32'h0}, DUT.dpath.data_array.rfile[34]); 

        assertion("dirty way 1", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[34]}); 
        assertion("dirty way 0", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[2]}); 

        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk);

        // ====================================================================
        //          write on mismatching tag, evict, refill, make dirty
        // ====================================================================
        // write request with tag 7, index 2, and offset 3
        $display("========================other way: tag 7, index 2, and offset 3===================");

        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd7, 5'd2, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3
            
        // should geet 16 read reqeusts to the memory 
        cache_req_rdy = 0; 
        holder = {21'd7, 5'd2, 6'd0}; 
        for (integer i = 0; i < 16; i++) begin 
            $display("iteration: %d", i);
            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 
            
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            assertion("read addr: ", holder + i * 4, cache_req_msg.addr);
            cache_req_rdy = 1; 
            @(negedge clk); 
        end


        @(negedge clk); 
        @(negedge clk); 
        for( integer i = 0; i < 16; i++ ) begin 
            // giving in 16 write responses
            // should be ignored by receiver

            cache_resp_msg = {3'd1, 8'd0, 2'd0, 2'd0, 32'd0};
            cache_resp_val = 1; 
            @(negedge clk); 
            assertion( "the receiver should remain rdy", 32'd1, {31'd0,cache_resp_rdy} );
            // while ( !cache_resp_rdy ) @(negedge clk); 
            cache_resp_val = 0; 
            @(negedge clk);
        end


        for (integer i = 0; i < 16; i++) begin 
            // giving in 16 read response value for the refill
            holder = 32'hF - i; 
            cache_resp_msg = {3'd0, 8'd0, 2'd0, 2'd0, holder};
            cache_resp_val = 1; 
            
            @(negedge clk); 
            while ( !cache_resp_rdy ) @(negedge clk); 

            cache_resp_val = 0; 
            @(negedge clk);
        end

        @(negedge clk); 
        assertion512("new data", {32'h0,32'h1,32'h2,32'h3,32'h4,32'h5,32'h6,32'h7,32'h8,32'h9,32'hA,32'hB,32'hC,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[2]); 
        assertion("tag", {11'd0, 21'd7}, {11'd0, DUT.dpath.tag_array0.rfile[2]});
        
        while ( !memresp_val ) @(negedge clk); 
        @(negedge clk);
        assertion("dirty way 0", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[2]});
        assertion("dirty way 1", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[34]}); 
        
        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk);


        // ====================================================================
        //          write on mismatching tag, refill, make dirty
        // ====================================================================
        // write request with tag 9, index 5, and offset 11
        $display("========================write tag 9, index 5, and offset 11===================");

        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd9, 5'd5, 4'd11, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 9, index 5, and offset 11

        while ( !memreq_rdy ) @(negedge clk); 

        @(negedge clk); 
        assertion("dirty", 32'd0, {31'd0, DUT.dpath.is_dirty}); 
        assertion("tagmatch way0 ", 32'd0, {31'd0, DUT.dpath.tarray0_match}); 
        assertion("tagmatch way1 ", 32'd0, {31'd0, DUT.dpath.tarray1_match}); 
        
        assign holder = {21'd15, 5'd2, 6'd0}; 
        cache_req_rdy = 0; 

        // should get 16 read reqeusts to the memory , no write
        cache_req_rdy = 0; 
        holder = {21'd9, 5'd5, 6'd0}; 
        for (integer i = 0; i < 16; i++) begin 
            $display("iteration: %d", i);
            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 
            
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            assertion("read addr: ", holder + i * 4, cache_req_msg.addr);
            cache_req_rdy = 1; 
            @(negedge clk); 
        end

        memreq_val = 0; 
        @(negedge clk); 
        @(negedge clk); 
        for (integer i = 0; i < 16; i++) begin 
            // giving in 16 read response value for the refill
            holder = 32'hF - i; 
            cache_resp_msg = {3'd0, 8'd0, 2'd0, 2'd0, holder};
            cache_resp_val = 1; 
            
            @(negedge clk); 
            while ( !cache_resp_rdy ) @(negedge clk); 

            cache_resp_val = 0; 
            @(negedge clk);
        end

        @(negedge clk); 
        assertion("dirty", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[37]}); 
        assertion("tagmatch way0", 32'd0, {31'd0, DUT.dpath.tarray0_match}); 
        assertion("tagmatch way1", 32'd1, {31'd0, DUT.dpath.tarray1_match}); 

        $display("state: %d", DUT.ctrl.state);
        
        $display("address: %d", DUT.dpath.data_address);
        $display("data to write: %x", DUT.dpath.darray_wdata_0);
        $display("data write en: %d", DUT.ctrl.darray_wen_0);
        $display("data write word en: %d", DUT.ctrl.darray_write_word_en_mux_sel);
        
        while (!memresp_val) @(negedge clk); 
        assertion512("new data from write", {32'h0,32'h1,32'h2,32'h3,32'hDEADBEEF,32'h5,32'h6,32'h7,32'h8,32'h9,32'hA,32'hB,32'hC,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[37]); 
        assertion("tag", {11'd0, 21'd9}, {11'd0, DUT.dpath.tag_array1.rfile[5]});
        

        memresp_rdy = 1; 
        memreq_val = 0; 

        $finish();

        @(negedge clk); 
        // ==================================================================
        //                     flush test 
        // ==================================================================
        // should only flush tag 7, index 2, and offset 3

        $display("========================begin flush test===================");
        memreq_val = 1; 
        flush      = 1; 
        
        memresp_rdy = 1;
        @(negedge clk); 
        
        $display("memreq rdy"); 
        assign holder = {21'd7, 5'd2, 6'd0}; 
        
        cache_req_rdy = 1; 

        // for ( integer i = 0; i < 100; i++ ) @(negedge clk); 
        for (integer i = 0; i < 16; i++) begin 
            // should get 16 write requests to the memory 
            $display("iteration: %d", i);

            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 
            
            assertion("is write request", {29'd0, `VC_MEM_REQ_MSG_TYPE_WRITE}, {29'd0, cache_req_msg.type_});
            assertion("write addr: ", holder + i * 4, cache_req_msg.addr);
            
            cache_req_rdy = 1; 
            @(negedge clk); 
        end 

        assign holder = {21'd9, 5'd5, 6'd0}; 
        for (integer i = 0; i < 16; i++) begin 
            // should get 16 write requests to the memory 
            $display("iteration: %d", i);

            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 
            
            assertion("is write request", {29'd0, `VC_MEM_REQ_MSG_TYPE_WRITE}, {29'd0, cache_req_msg.type_});
            assertion("write addr: ", holder + i * 4, cache_req_msg.addr);
            
            cache_req_rdy = 1; 
            @(negedge clk); 
        end 


        while ( !flush_done ) @(negedge clk); 
        flush = 0; 
        memreq_val = 0; 
        memresp_rdy = 1; 
        @(negedge clk);

        memresp_rdy = 0; 
        for (integer i = 0; i < 32; i++) begin 
            $display("iteration %d", i);
            assertion("not dirty", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[i]});
        end

        
        // ==================================================================
        //                     same cycle read hit 
        // ==================================================================
        // read tag 9, index 5, offset 11; 

        memreq_val = 1; 
        memreq_msg = {3'd0, 8'd0, 21'd9, 5'd5, 4'd11, 2'd00, 2'd0, 32'h12345678}; // read request with tag 15, index 2, and offset 1
        
        cache_req_rdy = 1; 
        
        cache_resp_val = 0; 
        memresp_val = 0; 
        #0.5;
        assertion("same cycle read hit", 32'd1, {31'd0, memresp_val}); 
        assertion("right data", 32'hDEADBEEF, memresp_msg.data); 
        @(negedge clk); 
        @(negedge clk); 
        assertion("no dirty changes", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[5]}); 
        
        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk); 
        // ==================================================================
        //                     same cycle write hit 
        // ==================================================================
        // write tag 9, index 5, offset 5; 

        memreq_val = 1; 
        memreq_msg = {3'd1, 8'd0, 21'd9, 5'd5, 4'd5, 2'd00, 2'd0, 32'h12345678}; // read request with tag 15, index 5, and offset 5
        
        cache_req_rdy = 1; 
        
        cache_resp_val = 0; 
        memresp_rdy = 0; 
        #0.05;
        assertion("same cycle read hit", 32'd1, {31'd0, memresp_val}); 
        @(negedge clk); 
        assertion("right data", 32'h12345678, DUT.dpath.data_array.rfile[5][191:160]); 
        assertion("dirty after write", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[5]}); 
        
        memreq_val = 0; 
        @(negedge clk);

        // ==================================================================
        //                     same cycle write hit 
        // ==================================================================
        // write tag 7, index 2, and offset 9

        memreq_val = 1; 
        memreq_msg = {3'd1, 8'd0, 21'd7, 5'd2, 4'd9, 2'd00, 2'd0, 32'h87654321}; // read request with tag 15, index 5, and offset 5
        
        @(negedge clk); 
        @(negedge clk); 
        @(negedge clk); 
        // delaying resp ready 
        assertion("still ready after delay", 32'd1, {31'd0, memresp_val}); 
        
        memresp_rdy = 1; 
        @(negedge clk);
        #0.05;
        assertion("same cycle read hit", 32'd1, {31'd0, memresp_val}); 
        @(negedge clk); 
        assertion("right data", 32'h87654321, DUT.dpath.data_array.rfile[2][319:288]); 
        assertion("dirty after write", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[2]}); 

        @(negedge clk);

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

    initial begin 
        for (integer i = 0; i < 20000; i++) begin 
            @(negedge clk);
            clock_counter = !clock_counter; 
        end

        $display("test time exceeded, Terminating"); 
        $finish();
    end

endmodule
