// This is a generated file. Use and modify at your own risk.
//////////////////////////////////////////////////////////////////////////////// 
// default_nettype of none prevents implicit wire declaration.
`default_nettype none
`timescale 1 ns / 1 ps
// Top level of the kernel. Do not modify module name, parameters or ports.
module mac #(
  parameter integer C_S_AXI_CONTROL_ADDR_WIDTH = 12 ,
  parameter integer C_S_AXI_CONTROL_DATA_WIDTH = 32 ,
  parameter integer C_S_AXIS_A_TDATA_WIDTH     = 1024,
  parameter integer C_S_AXIS_B_TDATA_WIDTH     = 1024,
  parameter integer C_S_AXIS_C_TDATA_WIDTH     = 1024,
  parameter integer C_M_AXIS_OUT_TDATA_WIDTH   = 1024
)
(
  // System Signals
  input  wire                                    ap_clk               ,
  input  wire                                    ap_rst_n             ,
  //  Note: A minimum subset of AXI4 memory mapped signals are declared.  AXI
  // signals omitted from these interfaces are automatically inferred with the
  // optimal values for Xilinx accleration platforms.  This allows Xilinx AXI4 Interconnects
  // within the system to be optimized by removing logic for AXI4 protocol
  // features that are not necessary. When adapting AXI4 masters within the RTL
  // kernel that have signals not declared below, it is suitable to add the
  // signals to the declarations below to connect them to the AXI4 Master.
  // 
  // List of ommited signals - effect
  // -------------------------------
  // ID - Transaction ID are used for multithreading and out of order
  // transactions.  This increases complexity. This saves logic and increases Fmax
  // in the system when ommited.
  // SIZE - Default value is log2(data width in bytes). Needed for subsize bursts.
  // This saves logic and increases Fmax in the system when ommited.
  // BURST - Default value (0b01) is incremental.  Wrap and fixed bursts are not
  // recommended. This saves logic and increases Fmax in the system when ommited.
  // LOCK - Not supported in AXI4
  // CACHE - Default value (0b0011) allows modifiable transactions. No benefit to
  // changing this.
  // PROT - Has no effect in current acceleration platforms.
  // QOS - Has no effect in current acceleration platforms.
  // REGION - Has no effect in current acceleration platforms.
  // USER - Has no effect in current acceleration platforms.
  // RESP - Not useful in most acceleration platforms.
  // 
  // AXI4-Stream (slave) interface s_axis_a
  input  wire                                    s_axis_a_tvalid      ,
  output wire                                    s_axis_a_tready      ,
  input  wire [C_S_AXIS_A_TDATA_WIDTH-1:0]       s_axis_a_tdata       ,
  input  wire [C_S_AXIS_A_TDATA_WIDTH/8-1:0]     s_axis_a_tkeep       ,
  input  wire                                    s_axis_a_tlast       ,
  // AXI4-Stream (slave) interface s_axis_b
  input  wire                                    s_axis_b_tvalid      ,
  output wire                                    s_axis_b_tready      ,
  input  wire [C_S_AXIS_B_TDATA_WIDTH-1:0]       s_axis_b_tdata       ,
  input  wire [C_S_AXIS_B_TDATA_WIDTH/8-1:0]     s_axis_b_tkeep       ,
  input  wire                                    s_axis_b_tlast       ,
  // AXI4-Stream (slave) interface s_axis_c
  input  wire                                    s_axis_c_tvalid      ,
  output wire                                    s_axis_c_tready      ,
  input  wire [C_S_AXIS_C_TDATA_WIDTH-1:0]       s_axis_c_tdata       ,
  input  wire [C_S_AXIS_C_TDATA_WIDTH/8-1:0]     s_axis_c_tkeep       ,
  input  wire                                    s_axis_c_tlast       ,
  // AXI4-Stream (master) interface m_axis_out
  output wire                                    m_axis_out_tvalid    ,
  input  wire                                    m_axis_out_tready    ,
  output wire [C_M_AXIS_OUT_TDATA_WIDTH-1:0]     m_axis_out_tdata     ,
  output wire [C_M_AXIS_OUT_TDATA_WIDTH/8-1:0]   m_axis_out_tkeep     ,
  output wire                                    m_axis_out_tlast     ,
  // AXI4-Lite slave interface
  input  wire                                    s_axi_control_awvalid,
  output wire                                    s_axi_control_awready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_awaddr ,
  input  wire                                    s_axi_control_wvalid ,
  output wire                                    s_axi_control_wready ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_wdata  ,
  input  wire [C_S_AXI_CONTROL_DATA_WIDTH/8-1:0] s_axi_control_wstrb  ,
  input  wire                                    s_axi_control_arvalid,
  output wire                                    s_axi_control_arready,
  input  wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]   s_axi_control_araddr ,
  output wire                                    s_axi_control_rvalid ,
  input  wire                                    s_axi_control_rready ,
  output wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   s_axi_control_rdata  ,
  output wire [2-1:0]                            s_axi_control_rresp  ,
  output wire                                    s_axi_control_bvalid ,
  input  wire                                    s_axi_control_bready ,
  output wire [2-1:0]                            s_axi_control_bresp  ,
  output wire                                    interrupt            
);

///////////////////////////////////////////////////////////////////////////////
// Local Parameters
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
// Wires and Variables
///////////////////////////////////////////////////////////////////////////////
(* DONT_TOUCH = "yes" *)
reg                                 areset                         = 1'b0;
wire                                ap_start                      ;
wire                                ap_idle                       ;
wire                                ap_done                       ;
wire                                ap_ready                      ;

// Register and invert reset signal.
always @(posedge ap_clk) begin
  areset <= ~ap_rst_n;
end

///////////////////////////////////////////////////////////////////////////////
// Begin control interface RTL.  Modifying not recommended.
///////////////////////////////////////////////////////////////////////////////


// AXI4-Lite slave interface
mac_control_s_axi #(
  .C_S_AXI_ADDR_WIDTH ( C_S_AXI_CONTROL_ADDR_WIDTH ),
  .C_S_AXI_DATA_WIDTH ( C_S_AXI_CONTROL_DATA_WIDTH )
)
inst_control_s_axi (
  .ACLK      ( ap_clk                ),
  .ARESET    ( areset                ),
  .ACLK_EN   ( 1'b1                  ),
  .AWVALID   ( s_axi_control_awvalid ),
  .AWREADY   ( s_axi_control_awready ),
  .AWADDR    ( s_axi_control_awaddr  ),
  .WVALID    ( s_axi_control_wvalid  ),
  .WREADY    ( s_axi_control_wready  ),
  .WDATA     ( s_axi_control_wdata   ),
  .WSTRB     ( s_axi_control_wstrb   ),
  .ARVALID   ( s_axi_control_arvalid ),
  .ARREADY   ( s_axi_control_arready ),
  .ARADDR    ( s_axi_control_araddr  ),
  .RVALID    ( s_axi_control_rvalid  ),
  .RREADY    ( s_axi_control_rready  ),
  .RDATA     ( s_axi_control_rdata   ),
  .RRESP     ( s_axi_control_rresp   ),
  .BVALID    ( s_axi_control_bvalid  ),
  .BREADY    ( s_axi_control_bready  ),
  .BRESP     ( s_axi_control_bresp   ),
  .interrupt ( interrupt             ),
  .ap_start  ( ap_start              ),
  .ap_done   ( ap_done               ),
  .ap_ready  ( ap_ready              ),
  .ap_idle   ( ap_idle               )
);

///////////////////////////////////////////////////////////////////////////////
// Add kernel logic here.  Modify/remove example code as necessary.
///////////////////////////////////////////////////////////////////////////////

// Example RTL block.  Remove to insert custom logic.
wire [127:0] tkeep_all_ones;
assign tkeep_all_ones = {128{1'b1}}; 

mac_rtl #(
  .C_S_AXIS_A_TDATA_WIDTH   ( C_S_AXIS_A_TDATA_WIDTH   ),
  .C_S_AXIS_B_TDATA_WIDTH   ( C_S_AXIS_B_TDATA_WIDTH   ),
  .C_S_AXIS_C_TDATA_WIDTH   ( C_S_AXIS_C_TDATA_WIDTH   ),
  .C_M_AXIS_OUT_TDATA_WIDTH ( C_M_AXIS_OUT_TDATA_WIDTH )
)
inst_mac_rtl (
  .ap_clk            ( ap_clk            ),
  .ap_rst_n          ( ap_rst_n          ),
  .s_axis_a_tvalid   ( s_axis_a_tvalid   ),
  .s_axis_a_tready   ( s_axis_a_tready   ),
  .s_axis_a_tdata    ( s_axis_a_tdata    ),
  .s_axis_a_tkeep    ( tkeep_all_ones    ),
  .s_axis_a_tlast    ( s_axis_a_tlast    ),
  .s_axis_b_tvalid   ( s_axis_b_tvalid   ),
  .s_axis_b_tready   ( s_axis_b_tready   ),
  .s_axis_b_tdata    ( s_axis_b_tdata    ),
  .s_axis_b_tkeep    ( tkeep_all_ones    ),
  .s_axis_b_tlast    ( s_axis_b_tlast    ),
  .s_axis_c_tvalid   ( s_axis_c_tvalid   ),
  .s_axis_c_tready   ( s_axis_c_tready   ),
  .s_axis_c_tdata    ( s_axis_c_tdata    ),
  .s_axis_c_tkeep    ( tkeep_all_ones    ),
  .s_axis_c_tlast    ( s_axis_c_tlast    ),
  .m_axis_out_tvalid ( m_axis_out_tvalid ),
  .m_axis_out_tready ( m_axis_out_tready ),
  .m_axis_out_tdata  ( m_axis_out_tdata  ),
  .m_axis_out_tkeep  ( tkeep_all_ones    ),
  .m_axis_out_tlast  ( m_axis_out_tlast  ),
  .ap_start          ( ap_start          ),
  .ap_done           ( ap_done           ),
  .ap_idle           ( ap_idle           ),
  .ap_ready          ( ap_ready          )
);

endmodule
`default_nettype wire
