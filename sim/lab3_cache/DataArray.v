`ifndef LAB3_CACHE_DATA_ARRAY_V
`define LAB3_CACHE_DATA_ARRAY_V

module lab3_cache_DataArray
#(
  parameter p_num_entries = 32,

  // Local constants not meant to be set from outside the module
  parameter c_addr_nbits  = $clog2(p_num_entries)
)(
  input  logic         clk,
  input  logic         reset,

  // Read port 0 (combinational read)

  input  logic [c_addr_nbits-1:0] read_addr0,
  output logic [511:0]            read_data0,

  // Read port 1 (combinational read)

  input  logic [c_addr_nbits-1:0] read_addr1,
  output logic [511:0]            read_data1,

  // Write port 0 (sampled on the rising clock edge)

  input  logic                    write_en0,
  input  logic [c_addr_nbits-1:0] write_addr0,
  input  logic [511:0]            write_data0,
  input  logic [ 15:0]            write_word_en_0,    // assume one-hot encoding

  // Write port 1 (sampled on the rising clock edge)

  input  logic                    write_en1,
  input  logic [c_addr_nbits-1:0] write_addr1,
  input  logic [511:0]            write_data1,
  input  logic [ 15:0]            write_word_en_1
);
  logic [511:0] rfile[p_num_entries-1:0];

  logic [511:0] wdata_0; 
  logic [511:0] wdata_mask_0; 
  assign wdata_mask_0 = {{32{write_word_en_0[15:15]}}, {32{write_word_en_0[14:14]}}, 
                         {32{write_word_en_0[13:13]}}, {32{write_word_en_0[12:12]}}, 
                         {32{write_word_en_0[11:11]}}, {32{write_word_en_0[10:10]}}, 
                         {32{write_word_en_0[9:9]}},  {32{write_word_en_0[8:8]}}, 
                         {32{write_word_en_0[7:7]}},  {32{write_word_en_0[6:6]}}, 
                         {32{write_word_en_0[5:5]}},  {32{write_word_en_0[4:4]}}, 
                         {32{write_word_en_0[3:3]}},  {32{write_word_en_0[2:2]}}, 
                         {32{write_word_en_0[1:1]}},  {32{write_word_en_0[0:0]}}}; 
  assign wdata_0 = (rfile[write_addr0] & (~wdata_mask_0)) + (write_data0 & wdata_mask_0);

  logic [511:0] wdata_1; 
  logic [511:0] wdata_mask_1; 
  assign wdata_mask_1 = {{32{write_word_en_1[15:15]}}, {32{write_word_en_1[14:14]}}, 
                         {32{write_word_en_1[13:13]}}, {32{write_word_en_1[12:12]}}, 
                         {32{write_word_en_1[11:11]}}, {32{write_word_en_1[10:10]}}, 
                         {32{write_word_en_1[9:9]}},   {32{write_word_en_1[8:8]}}, 
                         {32{write_word_en_1[7:7]}},   {32{write_word_en_1[6:6]}}, 
                         {32{write_word_en_1[5:5]}},   {32{write_word_en_1[4:4]}}, 
                         {32{write_word_en_1[3:3]}},   {32{write_word_en_1[2:2]}}, 
                         {32{write_word_en_1[1:1]}},   {32{write_word_en_1[0:0]}}}; 
  assign wdata_1 = (rfile[write_addr1] & (~wdata_mask_1)) + (write_data1 & wdata_mask_1);

  // Combinational read

  assign read_data0 = rfile[read_addr0];
  assign read_data1 = rfile[read_addr1];

  // Write on positive clock edge

  genvar i;
  generate
    for ( i = 0; i < p_num_entries; i = i+1 )
    begin: wport
      always_ff @( posedge clk )
        if ( reset )
          rfile[i] <= 512'd0;
        else if ( write_en0 && (i[c_addr_nbits-1:0] == write_addr0) )
          rfile[i] <= wdata_0;
        else if ( write_en1 && (i[c_addr_nbits-1:0] == write_addr1) )
          rfile[i] <= wdata_1;
    end
  endgenerate

endmodule
`endif /* DataArray */
