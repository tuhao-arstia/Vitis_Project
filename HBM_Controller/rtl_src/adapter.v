`default_nettype none
module adapter #(
  // command width (25)
  parameter integer C_S_AXIS_WR_TUSER_WIDTH = 25,
  // write data width
  parameter integer C_S_AXIS_WR_TDATA_WIDTH = 1024,
  // read data width
  parameter integer C_M_AXIS_RD_TDATA_WIDTH = 1024
)
(
  // System Signals
  input  wire                                  ap_clk,
  input  wire                                  ap_rst_n,
  // traffic generator signals
  // from traffic generator to core: s_axis_wr
  input  wire                                  s_axis_wr_tvalid,
  output wire                                  s_axis_wr_tready,
  input  wire [C_S_AXIS_WR_TDATA_WIDTH-1:0]    s_axis_wr_tdata , // write data
  input  wire [C_S_AXIS_WR_TUSER_WIDTH-1:0]    s_axis_wr_tuser , // command 25 bits
  input  wire [C_S_AXIS_WR_TDATA_WIDTH/8-1:0]  s_axis_wr_tkeep ,
  input  wire                                  s_axis_wr_tlast ,

  // Core Signals
  input  wire                                  i_controller_ready ,
  output wire                                  o_command_valid    ,
  output wire [C_S_AXIS_WR_TUSER_WIDTH-1:0]    o_command          ,
  output wire [C_S_AXIS_WR_TDATA_WIDTH-1:0]    o_write_data       ,

  input  wire                                  i_read_data_valid  ,
  input  wire [C_M_AXIS_RD_TDATA_WIDTH-1:0]    i_read_data        ,

  // from core to traffic generator: m_axis_rd
  output wire                                  m_axis_rd_tvalid,
  input  wire                                  m_axis_rd_tready,
  output wire [C_M_AXIS_RD_TDATA_WIDTH-1:0]    m_axis_rd_tdata , // write data
  output wire [C_M_AXIS_RD_TDATA_WIDTH/8-1:0]  m_axis_rd_tkeep ,
  output wire                                  m_axis_rd_tlast 
);

// tkeep
wire [127:0] tkeep_all_ones;
assign tkeep_all_ones = {128{1'b1}}; 

//--------------------------------------
//               Design
//--------------------------------------
// traffic generator to adapter: s_axis_wr
assign s_axis_wr_tready = i_controller_ready;

// core to core_wrapper
assign o_command_valid = s_axis_wr_tvalid;
assign o_command       = s_axis_wr_tuser;
assign o_write_data    = s_axis_wr_tdata;

// adapter to traffic generator: m_axis_rd
assign m_axis_rd_tvalid = i_read_data_valid;
assign m_axis_rd_tdata  = i_read_data;
assign m_axis_rd_tkeep  = tkeep_all_ones;
assign m_axis_rd_tlast  = 1'b0; // we do not need last

endmodule : adapter
