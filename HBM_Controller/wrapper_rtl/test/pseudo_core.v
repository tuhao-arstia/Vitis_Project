// This is a generated file. Use and modify at your own risk.
//////////////////////////////////////////////////////////////////////////////// 
// default_nettype of none prevents implicit wire declaration.
`default_nettype none
`timescale 1 ns / 1 ps
// Top level of the kernel. Do not modify module name, parameters or ports.
module pseudo_core #(
  parameter integer C_S_AXIS_WR_TDATA_WIDTH = 1024,
  parameter integer C_S_AXIS_WR_TUSER_WIDTH = 25 ,
  parameter integer C_M_AXIS_WR_TDATA_WIDTH = 1024,
  parameter integer C_M_AXIS_WR_TUSER_WIDTH = 23 ,
  parameter integer C_S_AXIS_RD_TDATA_WIDTH = 1024,
  parameter integer C_M_AXIS_RD_TDATA_WIDTH = 1024
)
(
  // System Signals
  input  wire                                 ap_clk          ,
  input  wire                                 ap_rst_n        ,
  // AXI4-Stream (slave) interface s_axis_wr
  input  wire                                 s_axis_wr_tvalid,
  output wire                                 s_axis_wr_tready,
  input  wire [C_S_AXIS_WR_TDATA_WIDTH-1:0]   s_axis_wr_tdata ,
  input  wire [C_S_AXIS_WR_TUSER_WIDTH-1:0]   s_axis_wr_tuser ,
  input  wire [C_S_AXIS_WR_TDATA_WIDTH/8-1:0] s_axis_wr_tkeep ,
  input  wire                                 s_axis_wr_tlast ,
  // AXI4-Stream (master) interface m_axis_wr
  output wire                                 m_axis_wr_tvalid,
  input  wire                                 m_axis_wr_tready,
  output wire [C_M_AXIS_WR_TDATA_WIDTH-1:0]   m_axis_wr_tdata ,
  output wire [C_M_AXIS_WR_TUSER_WIDTH-1:0]   m_axis_wr_tuser ,
  output wire [C_M_AXIS_WR_TDATA_WIDTH/8-1:0] m_axis_wr_tkeep ,
  output wire                                 m_axis_wr_tlast ,
  // AXI4-Stream (slave) interface s_axis_rd
  input  wire                                 s_axis_rd_tvalid,
  output wire                                 s_axis_rd_tready,
  input  wire [C_S_AXIS_RD_TDATA_WIDTH-1:0]   s_axis_rd_tdata ,
  input  wire [C_S_AXIS_RD_TDATA_WIDTH/8-1:0] s_axis_rd_tkeep ,
  input  wire                                 s_axis_rd_tlast ,
  // AXI4-Stream (master) interface m_axis_rd
  output wire                                 m_axis_rd_tvalid,
  input  wire                                 m_axis_rd_tready,
  output wire [C_M_AXIS_RD_TDATA_WIDTH-1:0]   m_axis_rd_tdata ,
  output wire [C_M_AXIS_RD_TDATA_WIDTH/8-1:0] m_axis_rd_tkeep ,
  output wire                                 m_axis_rd_tlast 
);

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
(* DONT_TOUCH = "yes" *)
reg                                 areset                         = 1'b0;

// Register and invert reset signal.
always @(posedge ap_clk) begin
  areset <= ~ap_rst_n;
end

///////////////////////////////////////////////////////////////////////////////
// Begin control interface RTL.  Modifying not recommended.
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Add kernel logic here.  Modify/remove example code as necessary.
///////////////////////////////////////////////////////////////////////////////

// Insert custom logic.
wire                                  controller_ready ;
wire                                  command_valid    ;
wire [C_S_AXIS_WR_TUSER_WIDTH-1:0]    command          ; // 25 bits
wire [C_S_AXIS_WR_TDATA_WIDTH-1:0]    write_data       ;
wire                                  read_data_valid  ;
wire [C_M_AXIS_RD_TDATA_WIDTH-1:0]    read_data        ;

// Instantiate adapter
adapter #(
    .C_S_AXIS_WR_TUSER_WIDTH ( C_S_AXIS_WR_TUSER_WIDTH ),
    .C_S_AXIS_WR_TDATA_WIDTH ( C_S_AXIS_WR_TDATA_WIDTH ),
    .C_M_AXIS_RD_TDATA_WIDTH ( C_M_AXIS_RD_TDATA_WIDTH )
) adapter_inst (
    .ap_clk             ( ap_clk           ),
    .ap_rst_n           ( ap_rst_n         ),

    .s_axis_wr_tvalid   ( s_axis_wr_tvalid ),
    .s_axis_wr_tready   ( s_axis_wr_tready ),
    .s_axis_wr_tdata    ( s_axis_wr_tdata  ),
    .s_axis_wr_tuser    ( s_axis_wr_tuser  ),
    .s_axis_wr_tkeep    ( s_axis_wr_tkeep  ),
    .s_axis_wr_tlast    ( s_axis_wr_tlast  ),

    .i_controller_ready ( controller_ready ),
    .o_command_valid    ( command_valid    ),
    .o_command          ( command          ),
    .o_write_data       ( write_data       ),

    .i_read_data_valid  ( read_data_valid  ),
    .i_read_data        ( read_data        ),

    .m_axis_rd_tvalid   ( m_axis_rd_tvalid ),
    .m_axis_rd_tready   ( m_axis_rd_tready ),
    .m_axis_rd_tdata    ( m_axis_rd_tdata  ),
    .m_axis_rd_tkeep    ( m_axis_rd_tkeep  ),
    .m_axis_rd_tlast    ( m_axis_rd_tlast  )
);

// Instantiate core_wrapper
core_wrapper #(
    .C_M_AXIS_WR_TUSER_WIDTH ( C_M_AXIS_WR_TUSER_WIDTH ),
    .C_M_AXIS_WR_TDATA_WIDTH ( C_M_AXIS_WR_TDATA_WIDTH ),
    .C_S_AXIS_RD_TDATA_WIDTH ( C_S_AXIS_RD_TDATA_WIDTH )
) core_wrapper_inst (
    .ap_clk             ( ap_clk           ),
    .ap_rst_n           ( ap_rst_n         ),
    .o_controller_ready ( controller_ready ),
    .i_command_valid    ( command_valid    ),
    .i_command          ( command          ), // command 25 bits
    .i_write_data       ( write_data       ),

    .o_read_data_valid  ( read_data_valid  ),
    .o_read_data        ( read_data        ),

    .m_axis_wr_tvalid   ( m_axis_wr_tvalid ),
    .m_axis_wr_tready   ( m_axis_wr_tready ),
    .m_axis_wr_tdata    ( m_axis_wr_tdata  ), // write data
    .m_axis_wr_tuser    ( m_axis_wr_tuser  ), // command 23 bits
    .m_axis_wr_tkeep    ( m_axis_wr_tkeep  ),
    .m_axis_wr_tlast    ( m_axis_wr_tlast  ),

    .s_axis_rd_tvalid   ( s_axis_rd_tvalid ),
    .s_axis_rd_tready   ( s_axis_rd_tready ),
    .s_axis_rd_tdata    ( s_axis_rd_tdata  ), // read data
    .s_axis_rd_tkeep    ( s_axis_rd_tkeep  ),
    .s_axis_rd_tlast    ( s_axis_rd_tlast  )
);


endmodule
`default_nettype wire
