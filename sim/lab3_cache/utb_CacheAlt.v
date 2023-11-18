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
    logic [20:0] tag_base;

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
        $display("========================Test 1: tag 15, index 2, and offset 1===================");

        memreq_val = 1; 
        memreq_msg = {3'd0, 8'd0, 21'd15, 5'd2, 4'd1, 2'd00, 2'd0, 32'hDEADBEEF}; // read request with tag 15, index 2, and offset 1
        
        refill({21'd15, 5'd2, 6'd0});

        assertion512("new data", {32'h0,32'h1,32'h2,32'h3,32'h4,32'h5,32'h6,32'h7,32'h8,32'h9,32'hA,32'hB,32'hC,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[34]); 

        assertion("mem resp output ", 32'he, memresp_msg.data);
        
        @(negedge clk); 

        // ==========================================================================
        //                  read request,tag_match, then same cycle read
        // ==========================================================================
        $display("========================Test 2: tag 15, index 2, and offset 1===================");

        memreq_val = 1; 
        memreq_msg = {3'd0, 8'd0, 21'd15, 5'd2, 4'd1, 2'd00, 2'd0, 32'hDEADBEEF}; // read request with tag 15, index 2, and offset 1
        memresp_rdy = 0;
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        memresp_rdy = 1; 
        #1;
        assertion512("read data", {32'h0,32'h1,32'h2,32'h3,32'h4,32'h5,32'h6,32'h7,32'h8,32'h9,32'hA,32'hB,32'hC,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[34]); 
        assertion("assert same cycle valid", 32'd1, {31'd0, memresp_val});
        @(negedge clk);
        
        // ====================================================================
        //       write on matching tag, and make dirty, should be same cycle
        // ====================================================================
        $display("========================Test 3: write tag 15, index 2, and offset 1===================");
        
        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd15, 5'd2, 4'd3, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 15, index 2, and offset 3
        
        #0.5; 
        assertion("assert same cycle valid", 32'd1, {31'd0, memresp_val}); 
        @(negedge clk);
        assertion512("new data", {32'h0,32'h1,32'h2,32'h3,32'h4,32'h5,32'h6,32'h7,32'h8,32'h9,32'hA,32'hB,32'hDEADBEEF,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[34]); 

        assertion("dirty way 1", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[34]}); 
        assertion("dirty way 0", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[2]}); 

        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk);

        // ====================================================================
        //          write on mismatching tag, use other way
        // ====================================================================
        // write request with tag 7, index 2, and offset 3
        $display("========================Test 4: tag 7, index 2, and offset 5===================");

        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd7, 5'd2, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3
        
        refill({21'd7, 5'd2, 6'd0});

        @(negedge clk);
        assertion512("new data from write", {32'h0,32'h1,32'h2,32'h3,32'h4,32'h5,32'h6,32'h7,32'h8,32'h9,32'hDEADBEEF,32'hB,32'hC,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[2]); 
        assertion("tag", {11'd0, 21'd7}, {11'd0, DUT.dpath.tag_array0.rfile[2]});
        assertion("dirty way 0", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[2]});
        assertion("dirty way 1", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[34]}); 
        
        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk);


        // ====================================================================
        //          write on mismatching tag, refill, make dirty
        // ====================================================================
        // write request with tag 9, index 5, and offset 11
        $display("========================Test 5: write tag 9, index 5, and offset 11===================");

        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd9, 5'd5, 4'd11, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 9, index 5, and offset 11

        while ( !memreq_rdy ) @(negedge clk); 

        @(negedge clk); 
        assertion("dirty index 2 way 0", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[2]});
        assertion("dirty index 2 way 1", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[34]}); 
        assertion("dirty index 5 way 1", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[37]}); 
        assertion("tagmatch way0 ", 32'd0, {31'd0, DUT.dpath.tarray0_match}); 
        assertion("tagmatch way1 ", 32'd0, {31'd0, DUT.dpath.tarray1_match}); 
        
        assign holder = {21'd15, 5'd2, 6'd0}; 
        cache_req_rdy = 1; 

        // should get 16 read reqeusts to the memory , no write
        cache_resp_val = 0; 
        for (integer i = 0; i < 16; i++) begin 
            $display("iteration: %d", i);
            @(negedge clk);
            cache_req_rdy = 1; 
            while ( !cache_req_val ) @(negedge clk); 
            
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            assertion("read addr: ", {21'd9, 5'd5, 6'd0} + i * 4, cache_req_msg.addr);
            @(negedge clk); 
            cache_req_rdy = 0; 

            holder = 32'hF - i; 
            cache_resp_msg = {3'd0, 8'd0, 2'd0, 2'd0, holder};
            cache_resp_val = 1; 
            
            while ( !cache_resp_rdy ) @(negedge clk); 
            
        end

        memreq_val = 0; 

        while ( !memresp_val ) @(negedge clk); 

        assertion("dirty", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[37]}); 
        assertion("tagmatch way0", 32'd0, {31'd0, DUT.dpath.tarray0_match}); 
        assertion("tagmatch way1", 32'd1, {31'd0, DUT.dpath.tarray1_match}); 

        assertion512("new data from write", {32'h0,32'h1,32'h2,32'h3,32'hDEADBEEF,32'h5,32'h6,32'h7,32'h8,32'h9,32'hA,32'hB,32'hC,32'hD,32'hE,32'hF}, DUT.dpath.data_array.rfile[37]); 
        assertion("tag", {11'd0, 21'd9}, {11'd0, DUT.dpath.tag_array1.rfile[5]});
        

        memresp_rdy = 1; 
        memreq_val = 0; 

        @(negedge clk); 
        // ==================================================================
        //                     flush test 
        // ==================================================================
        // flush tag 7,  index 2
        // flush tag 15, index 2
        // flush tag 9,  index 5

        $display("========================begin flush test===================");
        memreq_val = 1; 
        flush      = 1; 
        
        memresp_rdy = 1;
        @(negedge clk); 
        
        $display("memreq rdy"); 
        assign holder = {21'd7, 5'd2, 6'd0}; 
        
        cache_req_rdy = 1; 

        writeback({21'd7, 5'd2, 6'd0});

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

        assign holder = {21'd15, 5'd2, 6'd0}; 
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
        for (integer i = 0; i < 64; i++) begin 
            $display("iteration %d", i);
            assertion("not dirty", 32'd0, {31'd0, DUT.dpath.dirty_array.rfile[i]});
        end

        
        // ==================================================================
        //                     same cycle read hit 
        // ==================================================================
        // read tag 9, index 5, offset 11; 

        $display("========================Test 6: read tag 9, index 5, and offset 11===================");


        memreq_val = 1; 
        memreq_msg = {3'd0, 8'd0, 21'd9, 5'd5, 4'd11, 2'd00, 2'd0, 32'h12345678};
        
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

        $display("========================Test 7: write tag 9, index 5, and offset 5===================");


        memreq_val = 1; 
        memreq_msg = {3'd1, 8'd0, 21'd9, 5'd5, 4'd5, 2'd00, 2'd0, 32'h12345678};
        
        cache_req_rdy = 1; 
        
        cache_resp_val = 0; 
        #0.05;
        assertion("same cycle read hit", 32'd1, {31'd0, memresp_val}); 
        memresp_rdy = 0; 
        @(negedge clk); 
        assertion("right data", 32'h12345678, DUT.dpath.data_array.rfile[37][191:160]); 
        assertion("dirty after write", 32'd1, {31'd0, DUT.dpath.dirty_array.rfile[37]}); 
        
        memreq_val = 0; 
        @(negedge clk);

        // ==================================================================
        //                     same cycle write hit 
        // ==================================================================
        // write tag 7, index 2, and offset 9

        $display("========================Test 8: write tag 7, index 2 and offset 9===================");


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

        // ====================================================================
        //          read hit on matching tag
        // ====================================================================
        // write request with tag 7, index 2, and offset 3
        $display("========================Test 9: tag 7, index 2, and offset 5===================");

        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd7, 5'd2, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3
        
        @(negedge clk);
        assertion("tagmatch way0", 32'd1, {31'd0, DUT.dpath.tarray0_match}); 

        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk);

        $display("========================Test 10: tag 15, index 2, and offset 5===================");

        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd15, 5'd2, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3
        
        @(negedge clk);
        assertion("tagmatch way1", 32'd1, {31'd0, DUT.dpath.tarray1_match}); 

        memresp_rdy = 1; 
        memreq_val = 0; 
        @(negedge clk);

        // ====================================================================
        //            read miss, writeback
        // ====================================================================
        $display("========================Test 11: tag 20, index 2, and offset 5===================");
        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd20, 5'd2, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3
        @(negedge clk);
        assertion("tagmatch way0", 32'd0, {31'd0, DUT.dpath.tarray0_match}); 
        assertion("tagmatch way1", 32'd0, {31'd0, DUT.dpath.tarray1_match}); 
        
        writeback({21'd7, 5'd2, 6'd0});

        $display(DUT.dpath.dma.state);
        $display(DUT.ctrl.state);
        $display(DUT.dpath.dma.counter);

        refill({21'd20, 5'd2, 6'd0});

        @(negedge clk);

        $display("========================Test 12: tag 20, index 6, and offset 5===================");
        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd20, 5'd6, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF}; // write request with tag 7, index 2, and offset 3
        @(negedge clk);
        assertion("tagmatch way0", 32'd0, {31'd0, DUT.dpath.tarray0_match}); 
        assertion("tagmatch way1", 32'd0, {31'd0, DUT.dpath.tarray1_match}); 
    
        refill({21'd20, 5'd6, 6'd0});

        @(negedge clk);
        flush      = 1; 
        cache_req_rdy = 1; 
        cache_resp_val = 1; 
        @(negedge clk);
        flush      = 0; 
        while ( !flush_done ) @(negedge clk);

        while (! memreq_rdy ) @(negedge clk);

        reset = 1;
        @(negedge clk);
        @(negedge clk);
        @(negedge clk);
        reset = 0;
        @(negedge clk);

        $display("====================test===================");
        memresp_rdy = 1;

        memreq_val = 1; 
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd1, 5'd0, 4'd0, 2'd00, 2'd0, 32'hDEADBEEF};
        refill({21'd1, 5'd0, 6'd0});
        memreq_val = 0; 
        while (!memresp_val) @(negedge clk);
        
        memreq_val = 1;
        @(negedge clk);
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd1, 5'd0, 4'd0, 2'd00, 2'd0, 32'h99};
        @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 

        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd1, 5'd0, 4'd0, 2'd00, 2'd0, 32'hDEADBEEF};
        @(negedge clk);
        memreq_val = 0;
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'h99, memresp_msg.data); 

        @(negedge clk);
        memreq_val = 1;
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd0, 21'd1, 5'd0, 4'd0, 2'd00, 2'd0, 32'h4};
        @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'd4, memresp_msg.data); 

        @(negedge clk);
        memreq_val = 0;
        // flush = 1;

        // cache_req_rdy = 1; 
        
        // cache_resp_val = 1; 

        // for (integer i = 0; i < 64; i++) begin
        //     $display("flush counter: %d", DUT.ctrl.flush_counter);
        //     $display("read address: %d", DUT.dpath.data_address);
        //     $display("is dirty: %d", DUT.ctrl.is_dirty);
        //     if (DUT.ctrl.is_dirty) begin
        //         $display("val: %d", DUT.batch_send_istream_val);
        //         $display("rdy: %d", DUT.batch_send_istream_rdy);
        //         $display("data: %d", DUT.dpath.darray_rdata_0[7:0]);
        //     end
        //     @(negedge clk);
        // end

        @(negedge clk);
        memreq_val = 1;
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd10, 5'd0, 4'd0, 2'd00, 2'd0, 32'h4};
        @(negedge clk);
        refill({21'd10, 5'd0, 6'd0});
        while (!memresp_val) @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'hf, memresp_msg.data); 
        memreq_val = 0; 

        @(negedge clk);
        memreq_val = 1;
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'h1FFFFF, 5'd0, 4'd0, 2'd00, 2'd0, 32'h4};
        @(negedge clk);
        DUT.dpath.batch_send_istream_rdy = 0;
        #1;
        DUT.dpath.batch_send_istream_rdy = 1;
        writeback({21'd1, 5'd0, 6'd0});
        refill({21'h1FFFFF, 5'd0, 6'd0});
        @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'hf, memresp_msg.data); 
        @(negedge clk);

        @(negedge clk);
        memreq_val = 1;
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'h1FFFFF, 5'd0, 4'd0, 2'd00, 2'd0, 32'h4};
        @(negedge clk);
        assertion("data", 32'hf, memresp_msg.data); 
        @(negedge clk);
        
        memresp_rdy = 0;
        memreq_val = 1;
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_WRITE, 8'd1, 21'h1FFFFF, 5'd0, 4'd1, 2'd00, 2'd0, 32'hfFFFFFFF};
        @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'hffffffff, memresp_msg.data); 
        @(negedge clk);
        @(negedge clk);
        memresp_rdy = 1;
        @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 

        @(negedge clk);
        memreq_val = 1;
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd10, 5'd0, 4'd0, 2'd00, 2'd0, 32'h4};
        @(negedge clk);
        while (!memresp_val) @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'hf, memresp_msg.data); 
        memreq_val = 0; 

        @(negedge clk);
        memreq_val = 1;
        $display("((((()))))");
        memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'hF, 5'd0, 4'd0, 2'd00, 2'd0, 32'h4};
        @(negedge clk);
        writeback({21'h1FFFFF, 5'd0, 6'd0});
        refill({21'hF, 5'd0, 6'd0});
        @(negedge clk);
        assertion("valid", 32'd1, {31'd0, memresp_val}); 
        assertion("data", 32'hf, memresp_msg.data); 
        @(negedge clk);

        @(negedge clk);
        memreq_val = 1;
        memreq_msg = {3'b110, 8'hFF, 21'h1FFFFF, 5'h1F, 4'hF, 2'b11, 2'b11, 32'hFFFFFFFF};
        @(negedge clk);

        DUT.dpath.batch_send_istream_rdy = 0;
        #1;
        DUT.dpath.batch_send_istream_rdy = 1;

        while ( !DUT.batch_send_istream_rdy ) @(negedge clk); 
        cache_req_rdy = 1; 
        
        cache_resp_val = 0; 

        for (integer i = 0; i < 16; i++) begin 
            @(negedge clk); 
            cache_req_rdy = 1;
            while ( !cache_req_val ) @(negedge clk); 
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            assertion("read addr: ", {21'h1FFFFF, 5'h1F, 6'd0} + i * 4, cache_req_msg.addr);

            @(negedge clk); 
            cache_req_rdy = 0; 

            assign holder = 32'hFFFFFFFF;
            cache_resp_val = 1; 
            cache_resp_msg = {3'b111, 8'hFF, 2'b11, 2'b11, holder};
            while ( !cache_resp_rdy ) @(negedge clk); 
        end

        @(negedge clk); 
        memresp_rdy = 1; 

        while (!memresp_val) @(negedge clk); 

        // assign holder = {21'd1, 5'd0, 6'd0}; 
        // for (integer i = 0; i < 16; i++) begin 
        //     // should get 16 write requests to the memory 
        //     $display("iteration: %d", i);
            
        //     $display("write data: %d", cache_req_msg.data);
        //     @(negedge clk);
        //     while ( !cache_req_val ) @(negedge clk); 
            
        //     assertion("is write request", {29'd0, `VC_MEM_REQ_MSG_TYPE_WRITE}, {29'd0, cache_req_msg.type_});
        //     assertion("write addr: ", holder + i * 4, cache_req_msg.addr);
            
        //     cache_req_rdy = 1; 
        //     @(negedge clk); 
        // end 

        // flush = 0;

        // reset = 1;
        // @(negedge clk);
        // @(negedge clk);
        // @(negedge clk);
        // reset = 0;
        // @(negedge clk);
        // read_top_lines();
        // read_top_lines();

        $finish();
    end

    integer no = 13;

    task read_top_lines();
        logic [4:0] index_incr;
        index_incr = 0;

        for (integer i = 0; i < 3; i++) begin
            $display("========================Test %d: tag %d, index %d, and offset 5 way 0===================",no+i,i,i);
            memresp_rdy = 1;
            memreq_val = 1; 
            memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd1, index_incr, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF};
            @(negedge clk);

            refill({21'd1, index_incr, 6'd0});
            memreq_val = 0; 
            @(negedge clk);
            $display("========================Test %d: tag %d, index %d, and offset 5 way 1===================",no+i,i,i);
            memresp_rdy = 1;

            memreq_val = 1; 
            memreq_msg = {`VC_MEM_RESP_MSG_TYPE_READ, 8'd0, 21'd2, index_incr, 4'd5, 2'd00, 2'd0, 32'hDEADBEEF};
            @(negedge clk);

            refill({21'd2, index_incr, 6'd0});

            index_incr = index_incr + 1;

            @(negedge clk);
        end
        memreq_val = 0; 
        no = no + 3;
    endtask

    task writeback_no_check();
        while ( !DUT.batch_send_istream_rdy ) @(negedge clk); 
        cache_req_rdy = 1; 
        for (integer i = 0; i < 16; i++) begin 
            // should get 16 write requests to the memory 
            $display("iteration: %d", i);
            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 
            cache_resp_val = 1; 
            cache_req_rdy = 1; 
            @(negedge clk); 
        end 
    endtask

    task writeback([31:0] expected_addr);
        cache_req_rdy = 1; 

        for (integer i = 0; i < 16; i++) begin 
            // should get 16 write requests to the memory 
            $display("iteration: %d", i);

            @(negedge clk);
            while ( !cache_req_val ) @(negedge clk); 

            cache_resp_val = 1; 
            assertion("is write request", {29'd0, `VC_MEM_REQ_MSG_TYPE_WRITE}, {29'd0, cache_req_msg.type_});
            assertion("write addr: ", expected_addr + i * 4, cache_req_msg.addr);
            
            cache_req_rdy = 1; 
            @(negedge clk); 
        end 
    endtask

    task refill([31:0] expected_addr);
        while ( !DUT.batch_send_istream_rdy ) @(negedge clk); 
        cache_req_rdy = 1; 
        
        cache_resp_val = 0; 

        for (integer i = 0; i < 16; i++) begin 
            @(negedge clk); 
            cache_req_rdy = 1;
            while ( !cache_req_val ) @(negedge clk); 
            assertion("is read request", {29'd0, `VC_MEM_REQ_MSG_TYPE_READ}, {29'd0, cache_req_msg.type_});
            assertion("read addr: ", expected_addr + i * 4, cache_req_msg.addr);

            @(negedge clk); 
            cache_req_rdy = 0; 

            assign holder = 32'hF-i; 
            cache_resp_val = 1; 
            cache_resp_msg = {3'd0, 8'd0, 2'd0, 2'd0, holder};
            while ( !cache_resp_rdy ) @(negedge clk); 
        end

        @(negedge clk); 
        memresp_rdy = 1; 

        while (!memresp_val) @(negedge clk); 
    endtask
  
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
