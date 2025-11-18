// This is a generated file. Use and modify at your own risk.
//////////////////////////////////////////////////////////////////////////////// 
// default_nettype of none prevents implicit wire declaration.
module mac_rtl #(
  parameter integer C_S_AXIS_A_TDATA_WIDTH   = 1024,
  parameter integer C_S_AXIS_B_TDATA_WIDTH   = 1024,
  parameter integer C_S_AXIS_C_TDATA_WIDTH   = 1024,
  parameter integer C_M_AXIS_OUT_TDATA_WIDTH = 1024
)
(
  // System Signals
  input  wire                                  ap_clk           ,
  input  wire                                  ap_rst_n         ,
  // Pipe (AXI4-Stream host) interface s_axis_a
  input  wire                                  s_axis_a_tvalid  ,
  output wire                                  s_axis_a_tready  ,
  input  wire [C_S_AXIS_A_TDATA_WIDTH-1:0]     s_axis_a_tdata   ,
  input  wire [C_S_AXIS_A_TDATA_WIDTH/8-1:0]   s_axis_a_tkeep   ,
  input  wire                                  s_axis_a_tlast   ,
  // Pipe (AXI4-Stream host) interface s_axis_b
  input  wire                                  s_axis_b_tvalid  ,
  output wire                                  s_axis_b_tready  ,
  input  wire [C_S_AXIS_B_TDATA_WIDTH-1:0]     s_axis_b_tdata   ,
  input  wire [C_S_AXIS_B_TDATA_WIDTH/8-1:0]   s_axis_b_tkeep   ,
  input  wire                                  s_axis_b_tlast   ,
  // Pipe (AXI4-Stream host) interface s_axis_c
  input  wire                                  s_axis_c_tvalid  ,
  output wire                                  s_axis_c_tready  ,
  input  wire [C_S_AXIS_C_TDATA_WIDTH-1:0]     s_axis_c_tdata   ,
  input  wire [C_S_AXIS_C_TDATA_WIDTH/8-1:0]   s_axis_c_tkeep   ,
  input  wire                                  s_axis_c_tlast   ,
  // Pipe (AXI4-Stream host) interface m_axis_out
  output wire                                  m_axis_out_tvalid,
  input  wire                                  m_axis_out_tready,
  output wire [C_M_AXIS_OUT_TDATA_WIDTH-1:0]   m_axis_out_tdata ,
  output wire [C_M_AXIS_OUT_TDATA_WIDTH/8-1:0] m_axis_out_tkeep ,
  output wire                                  m_axis_out_tlast ,
  // Control Signals
  input  wire                                  ap_start         ,
  output wire                                  ap_idle          ,
  output wire                                  ap_done          ,
  output wire                                  ap_ready         
);

// Local Parameters
parameter IDLE   = 1'b0;
parameter BUSY   = 1'b1;

// Decalarations

// FSM
reg c_state;
reg n_state;
reg ap_done_reg;
// create start pulse
wire ap_start_pulse;
reg ap_start_d;

// Buffers
reg  [7:0] a_buffer;
reg        a_buffer_valid;

reg  [7:0] b_buffer;
reg        b_buffer_valid;

reg [15:0] c_buffer;
reg        c_buffer_valid;

// MAC signals
wire [15:0] mac_mult;
reg  [15:0] mac_result;

// last signal
reg        last;
reg        last_d1;

// all buffer valid
wire all_buffer_valid;
reg  all_buffer_valid_d1;

wire hs_axis_a;
wire hs_axis_b;
wire hs_axis_c;

// back-pressure signals
wire pipeline_stall;
wire pipeline_ready;

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
    n_state = IDLE;
    case (c_state)
        IDLE: begin
            if (ap_start_pulse) begin
                n_state = BUSY;
            end
        end
        BUSY: begin
            if (m_axis_out_tlast && m_axis_out_tready && m_axis_out_tvalid) begin
                n_state = IDLE;
            end
        end
    endcase
end

// ap_ctrl signals
// ap_start pulse generation
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        ap_start_d <= 1'b0;
    end else begin
        ap_start_d <= ap_start;
    end
end
assign ap_start_pulse = ap_start & ~ap_start_d;

assign ap_idle  = (c_state == IDLE);
assign ap_ready = (c_state == IDLE);

assign ap_done  = ap_done_reg;
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        ap_done_reg <= 1'b0;
    end else begin
        if (c_state == BUSY && m_axis_out_tlast && m_axis_out_tready && m_axis_out_tvalid) begin
            ap_done_reg <= 1'b1;
        end else begin
            ap_done_reg <= 1'b0;
        end
    end
end

// back-pressure: stall when the output is valid but the receiver is not ready
assign pipeline_stall = m_axis_out_tvalid && ~m_axis_out_tready;
assign pipeline_ready = ~pipeline_stall;

// handshake
assign all_buffer_valid = a_buffer_valid && b_buffer_valid && c_buffer_valid;
assign hs_axis_a = s_axis_a_tvalid && s_axis_a_tready;
assign hs_axis_b = s_axis_b_tvalid && s_axis_b_tready;
assign hs_axis_c = s_axis_c_tvalid && s_axis_c_tready;

// A
assign s_axis_a_tready = (c_state == BUSY) && (!a_buffer_valid || (all_buffer_valid && pipeline_ready));

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        a_buffer_valid <= 1'b0;
    end else begin
        if (hs_axis_a) begin
            a_buffer_valid <= 1'b1;
        end else if (all_buffer_valid && pipeline_ready) begin
            // no new data but pipeline proceeds
            a_buffer_valid <= 1'b0;
        end
    end
end

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        a_buffer <= 8'b0;
    end else begin
        if (hs_axis_a) begin
            a_buffer <= s_axis_a_tdata[7:0];
        end
    end
end

// B
assign s_axis_b_tready = (c_state == BUSY) && (!b_buffer_valid || (all_buffer_valid && pipeline_ready));

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        b_buffer_valid <= 1'b0;
    end else begin
        if (hs_axis_b) begin
            b_buffer_valid <= 1'b1;
        end else if (all_buffer_valid && pipeline_ready) begin
            // no new data but pipeline proceeds
            b_buffer_valid <= 1'b0;
        end
    end
end

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        b_buffer <= 8'b0;
    end else begin
        if (hs_axis_b) begin
            b_buffer <= s_axis_b_tdata[7:0];
        end
    end
end

// C
assign s_axis_c_tready = (c_state == BUSY) && (!c_buffer_valid || (all_buffer_valid && pipeline_ready));

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        c_buffer_valid <= 1'b0;
    end else begin
        if (hs_axis_c) begin
            c_buffer_valid <= 1'b1;
        end else if (all_buffer_valid && pipeline_ready) begin
            // no new data but pipeline proceeds
            c_buffer_valid <= 1'b0;
        end
    end
end

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        c_buffer <= 16'b0;
    end else begin
        if (hs_axis_c) begin
            c_buffer <= s_axis_c_tdata[15:0];
        end
    end
end

// MAC operation
assign mac_mult = a_buffer * b_buffer;

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        mac_result <= 16'b0;
    end else begin
        if (all_buffer_valid && pipeline_ready) begin
            mac_result <= mac_mult + c_buffer;
        end
    end
end

// output
// delayed all_buffer_valid
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        all_buffer_valid_d1 <= 1'b0;
    end else if (all_buffer_valid && pipeline_ready) begin
        all_buffer_valid_d1 <= all_buffer_valid;
    end else begin
        all_buffer_valid_d1 <= 1'b0;
    end
end

// last signal reference : A
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        last <= 1'b0;
    end else begin
        if (hs_axis_a) begin
            last <= s_axis_a_tlast;
        end else if (all_buffer_valid && pipeline_ready) begin
            // no new data but pipeline proceeds, clear last
            last <= 1'b0;
        end // else retain the value
    end
end

always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) begin
        last_d1 <= 1'b0;
    end else if (all_buffer_valid && pipeline_ready) begin
        last_d1 <= last;
    end else begin
        last_d1 <= 1'b0;
    end
end

assign m_axis_out_tdata = {1008'b0, mac_result};
assign m_axis_out_tvalid = all_buffer_valid_d1;
assign m_axis_out_tlast  = last_d1;

endmodule : mac_rtl
