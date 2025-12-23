`default_nettype none
module core_wrapper_with_ap_ctrl #(
  // command width (25->23)
  parameter integer C_M_AXIS_WR_TUSER_WIDTH = 23 ,
  // write data width
  parameter integer C_M_AXIS_WR_TDATA_WIDTH = 1024,
  // read data width
  parameter integer C_S_AXIS_RD_TDATA_WIDTH = 1024
)
(
  // System Signals
  input  wire                                  ap_clk           ,
  input  wire                                  ap_rst_n         ,

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
  // Control Signals
  input  wire                                  ap_start        ,
  output wire                                  ap_idle         ,
  output wire                                  ap_done         ,
  output wire                                  ap_ready        
);

// Local Parameters
parameter IDLE   = 1'b0;
parameter BUSY   = 1'b1;

// Decalarations
// FSM
reg     c_state;
reg     n_state;

// ap_ctrl related signals
wire    ap_start_pulse;
reg     ap_start_d;
reg     ap_done_reg;

// tkeep
wire [127:0] tkeep_all_ones;
assign tkeep_all_ones = {128{1'b1}}; 

//--------------------------------------
//               Design
//--------------------------------------
// FSM
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        c_state <= IDLE;
    end else begin
        c_state <= n_state;
    end
end

always @(*) begin
    n_state = c_state;
    case (c_state)
        IDLE: begin
            if (ap_start_pulse) begin
                n_state = BUSY;
            end
        end
        BUSY: begin
            if (s_axis_rd_tlast && s_axis_rd_tready && s_axis_rd_tvalid) begin
                n_state = IDLE;
            end
        end
    endcase
end

// ap_start pulse generation
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        ap_start_d <= 1'b0;
    end else begin
        ap_start_d <= ap_start;
    end
end
assign ap_start_pulse = ap_start & ~ap_start_d;

// ap_ctrl signals
assign ap_idle  = (c_state == IDLE);
assign ap_ready = (c_state == IDLE);
assign ap_done  = ap_done_reg;

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        ap_done_reg <= 1'b0;
    end else begin
        // when reading all data back, it is done 
        if (s_axis_rd_tlast && s_axis_rd_tready && s_axis_rd_tvalid) begin
            ap_done_reg <= 1'b1;
        end else begin
            ap_done_reg <= 1'b0;
        end
    end
end

// COMMAND & WRITE DATA CHANNEL:
// wrapper to core:
assign o_controller_ready = (c_state == BUSY) ? m_axis_wr_tready : 1'b0;
// wrapper to controller:
assign m_axis_wr_tvalid = (c_state == BUSY) ? i_command_valid : 1'b0;
assign m_axis_wr_tdata  = (c_state == BUSY) ? i_write_data  : 1024'b0;
assign m_axis_wr_tuser  = (c_state == BUSY) ? {i_command[24], i_command[21:0]} : 23'b0;
assign m_axis_wr_tkeep  = tkeep_all_ones;
assign m_axis_wr_tlast  = 1'b0; // we do not need last here

// READ DATA CHANNEL:
// controller to wrapper:
assign s_axis_rd_tready = (c_state == BUSY) ? 1'b1 : 1'b0;
// wrapper to core:
assign o_read_data_valid = (c_state == BUSY) ? s_axis_rd_tvalid : 1'b0;
assign o_read_data       = (c_state == BUSY) ? s_axis_rd_tdata : 1024'b0;

endmodule : core_wrapper_with_ap_ctrl
