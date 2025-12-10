`default_nettype none
module core_wrapper #(
  // command width (25->23)
  parameter integer C_M_AXIS_WR_TUSER_WIDTH = 23 ,
  // write data width
  parameter integer C_M_AXIS_WR_TDATA_WIDTH = 1024,
  // read data width
  parameter integer C_S_AXIS_RD_TDATA_WIDTH = 1024
)
(
  // System Signals
  input  wire                                  ap_clk,
  input  wire                                  ap_rst_n,
  // Core Signals
  output wire                                  o_controller_ready ,
  input  wire                                  i_command_valid    ,
  input  wire [C_M_AXIS_WR_TUSER_WIDTH+1:0]    i_command          ,
  input  wire [C_M_AXIS_WR_TDATA_WIDTH-1:0]    i_write_data       ,

  output wire                                  o_read_data_valid  ,
  output wire [C_S_AXIS_RD_TDATA_WIDTH-1:0]    o_read_data        ,

  // command & write data channel: m_axis_wr
  output wire                                  m_axis_wr_tvalid,
  input  wire                                  m_axis_wr_tready,
  output wire [C_M_AXIS_WR_TDATA_WIDTH-1:0]    m_axis_wr_tdata , // write data
  output wire [C_M_AXIS_WR_TUSER_WIDTH-1:0]    m_axis_wr_tuser , // command
  output wire [C_M_AXIS_WR_TDATA_WIDTH/8-1:0]  m_axis_wr_tkeep ,
  output wire                                  m_axis_wr_tlast ,
  // read data channel:s_axis_rd
  input  wire                                  s_axis_rd_tvalid,
  output wire                                  s_axis_rd_tready,
  input  wire [C_S_AXIS_RD_TDATA_WIDTH-1:0]    s_axis_rd_tdata , // read data
  input  wire [C_S_AXIS_RD_TDATA_WIDTH/8-1:0]  s_axis_rd_tkeep ,
  input  wire                                  s_axis_rd_tlast ,
);

// tkeep
wire [127:0] tkeep_all_ones;
assign tkeep_all_ones = {128{1'b1}}; 

//--------------------------------------
//               Design
//--------------------------------------
// COMMAND & WRITE DATA CHANNEL:
// wrapper to core:
assign o_controller_ready = m_axis_wr_tready;
// wrapper to controller:
assign m_axis_wr_tvalid = i_command_valid;
assign m_axis_wr_tdata  = i_write_data;
assign m_axis_wr_tuser  = {i_command[24], i_command[21:0]};
assign m_axis_wr_tkeep  = tkeep_all_ones;
assign m_axis_wr_tlast  = 1'b0; // we do not need last here

// READ DATA CHANNEL:
// controller to wrapper:
assign s_axis_rd_tready = 1'b1;
// wrapper to core:
assign o_read_data_valid = s_axis_rd_tvalid;
assign o_read_data       = s_axis_rd_tdata;

endmodule : core_wrapper
