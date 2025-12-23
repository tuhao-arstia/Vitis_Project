`default_nettype none
// Top level of the kernel. Do not modify module name, parameters or ports.
module pseudo_core_rtl #(
    parameter integer C_M_AXIS_WR_TUSER_WIDTH = 23,
    parameter integer C_M_AXIS_WR_TDATA_WIDTH = 1024,
    parameter integer C_S_AXIS_RD_TDATA_WIDTH = 1024
)
(
    // system signals
    input   wire                                 ap_clk,
    input   wire                                 ap_rst_n,

    // ap_ctrl signals
    input   wire                                 ap_start,
    output  reg                                  ap_done,
    output  reg                                  ap_idle,
    output  reg                                  ap_ready,
    
    // configuration/status signals (uint)
    input   wire [31:0]                          total_pkts,   
    output  wire [31:0]                          total_error_count,  

    // AXI Stream interfaces to HBM controller
    // command & write data channel: m_axis_wr
    output wire                                  m_axis_wr_tvalid,
    input  wire                                  m_axis_wr_tready,
    output wire [C_M_AXIS_WR_TDATA_WIDTH-1:0]    m_axis_wr_tdata , // write data
    output wire [C_M_AXIS_WR_TUSER_WIDTH-1:0]    m_axis_wr_tuser , // command 23 bits
    output wire [C_M_AXIS_WR_TDATA_WIDTH/8-1:0]  m_axis_wr_tkeep ,
    output wire                                  m_axis_wr_tlast ,
    
    // read data channel: s_axis_rd
    input  wire                                  s_axis_rd_tvalid,
    output wire                                  s_axis_rd_tready,
    input  wire [C_S_AXIS_RD_TDATA_WIDTH-1:0]    s_axis_rd_tdata , // read data
    input  wire [C_S_AXIS_RD_TDATA_WIDTH/8-1:0]  s_axis_rd_tkeep ,
    input  wire                                  s_axis_rd_tlast
);

// =========================================================================
// FSM States
// =========================================================================
localparam ST_IDLE       = 3'd0;
localparam ST_SEED_LOAD  = 3'd1; // Load Seed for LFSR
localparam ST_WRITE      = 3'd2; // Write Command Phase
localparam ST_READ       = 3'd3; // Read Command Phase
localparam ST_WAIT_RESP  = 3'd4; // Wait for HBM response
localparam ST_DONE       = 3'd5;

// =========================================================================
// Declarations
// =========================================================================
// FSM
reg [2:0] state, next_state;

// Counters
reg [21:0] cnt_wr_cmd;      // Write transaction counter
reg [21:0] cnt_rd_cmd;  // Read command counter
reg [21:0] cnt_rd_resp; // Read response counter
reg [21:0] cnt_error;   // Error counter

// LFSR Signals
reg         lfsr_load_seed_flag;
reg         lfsr_enable_tx; // For generating Write Data
reg         lfsr_enable_rx; // For generating Expected Data
wire [31:0] lfsr_out_tx;
wire [31:0] lfsr_out_rx;

// wrapper <-> pseudo core signals
wire                                  controller_ready;
reg                                   command_valid_reg;
reg  [C_M_AXIS_WR_TUSER_WIDTH+1:0]    command_reg; // 25-bit command
wire [C_M_AXIS_WR_TDATA_WIDTH-1:0]    write_data;  // From LFSR
wire                                  read_data_valid;
wire [C_S_AXIS_RD_TDATA_WIDTH-1:0]    read_data;

// verification
wire [1023:0] expected_data;

// =========================================================================
// Design
// =========================================================================
// LFSR Instances
// seed should be the same.
// TX LFSR (Generates Data to HBM)
lfsr_32 u_lfsr_tx (
    .clk(ap_clk),
    .rst_n(ap_rst_n),
    .load_seed_flag(lfsr_load_seed_flag),
    .enable(lfsr_enable_tx),
    .seed(32'hA5A5_5A5A), // Fixed Seed for reproducibility
    .rand_data(lfsr_out_tx)
);

// RX LFSR (Generates Expected Data for Check)
lfsr_32 u_lfsr_rx (
    .clk(ap_clk),
    .rst_n(ap_rst_n),
    .load_seed_flag(lfsr_load_seed_flag),
    .enable(lfsr_enable_rx),
    .seed(32'hA5A5_5A5A), // Must match TX seed
    .rand_data(lfsr_out_rx)
);

// Expand 32-bit random to 1024-bit (Replicate)
assign write_data = {32{lfsr_out_tx}};
assign expected_data = {32{lfsr_out_rx}};

// =========================================================================
// FSM Logic
// =========================================================================
always @(posedge ap_clk or negedge ap_rst_n) begin
    if (!ap_rst_n) state <= ST_IDLE;
    else           state <= next_state;
end

always @(*) begin
    next_state = state;
    case (state)
        ST_IDLE: begin
            if (ap_start) next_state = ST_SEED_LOAD;
        end
        ST_SEED_LOAD: begin
            next_state = ST_WRITE;
        end
        ST_WRITE: begin
            // If all write commands are sent
            if ((cnt_wr_cmd == total_pkts) && !command_valid_reg)
                next_state = ST_READ;
        end
        ST_READ: begin
            // If all read commands are sent
             if ((cnt_rd_cmd == total_pkts) && !command_valid_reg)
                next_state = ST_WAIT_RESP;
        end
        ST_WAIT_RESP: begin
            // Wait until all responses received
            if (cnt_rd_resp == total_pkts)
                next_state = ST_DONE;
        end
        ST_DONE: begin
            // Leave ST_DONE when ap_start is dropped
            if (!ap_start) next_state = ST_IDLE;
        end
    endcase
end

// ap_ctrl signals
assign ap_idle  = (state == ST_IDLE);
assign ap_ready = (state == ST_IDLE);
assign ap_done  = (state == ST_DONE);

// load seed flag
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        lfsr_load_seed_flag <= 0;
    end else begin
        lfsr_load_seed_flag <= (state == ST_SEED_LOAD);
    end
end
// =========================================================================
// Command Generation (TX)
// =========================================================================
// command counter
// wr cnt
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        cnt_wr_cmd <= 0; 
    end else begin
        case (state)
            ST_IDLE:begin
                cnt_wr_cmd <= 0; 
            end
            ST_WRITE: begin
                if(controller_ready) begin
                    if(cnt_wr_cmd < total_pkts) begin
                        cnt_wr_cmd <= cnt_wr_cmd + 1;
                    end
                end
            end
        endcase
    end
end
// rd cnt
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        cnt_rd_cmd <= 0;
    end else begin
        case (state)
            ST_IDLE: begin
                cnt_rd_cmd <= 0;
            end
            ST_READ: begin
                if(controller_ready) begin
                    if(cnt_rd_cmd < total_pkts) begin
                        cnt_rd_cmd <= cnt_rd_cmd + 1;
                    end
                end
            end
        endcase
    end
end

// command_valid generation
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        command_valid_reg <= 0;
    end else begin
        case (state)
            ST_IDLE: begin
                command_valid_reg <= 0;
            end
            ST_WRITE: begin
                if(controller_ready) begin
                    if(cnt_wr_cmd < total_pkts) begin
                        command_valid_reg <= 1;
                    end else begin
                        command_valid_reg <= 0;
                    end
                end
            end
            ST_READ: begin
                if(controller_ready) begin
                    if(cnt_rd_cmd < total_pkts) begin
                        command_valid_reg <= 1;
                    end else begin
                        command_valid_reg <= 0;
                    end
                end
            end
            default: begin
                command_valid_reg <= 0;
            end
        endcase
    end
end

// command generation
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        command_reg <= 0;
    end else begin
        case (state)
            ST_WRITE:begin
                if (controller_ready) begin
                    if (cnt_wr_cmd < total_pkts) begin
                        // request type = 0 (Write)
                        // data type = 00 (dummy here)
                        // address = 22 bit cnt_wr_cmd
                        command_reg <= {1'b0, 2'b00, cnt_wr_cmd};
                    end
                end
            end
            ST_READ: begin
                if (controller_ready) begin
                    if (cnt_rd_cmd < total_pkts) begin
                        // request type = 1 (Read)
                        // data type = 00 (dummy here)
                        // address = 22 bit cnt_rd_cmd
                        command_reg <= {1'b1, 2'b00, cnt_rd_cmd};
                    end
                end
            end
            default: begin
                command_reg <= 25'b0;
            end 
        endcase
    end
end

// lsfr_tx enable control
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        lfsr_enable_tx <= 0;
    end else begin
        case (state)
            ST_WRITE: begin
                if (controller_ready) begin
                    if (cnt_wr_cmd < total_pkts) begin
                        lfsr_enable_tx <= 1; // advance LFSR for next data
                    end
                end
            end
            default: begin
                lfsr_enable_tx <= 0;
            end
        endcase
    end
end

// =========================================================================
// Receiver & Checker (RX)
// =========================================================================
// response counter 
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        cnt_rd_resp <= 0;
    end else begin
        if (state == ST_IDLE) begin
            cnt_rd_resp <= 0;
        end
        // not using state control here to collect every response
        else if (read_data_valid) begin
            cnt_rd_resp <= cnt_rd_resp + 1;
        end
    end
end

// error counter
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        cnt_error <= 0;
    end else begin
        if (state == ST_IDLE) begin
            cnt_error <= 0;
        end
        else if (read_data_valid) begin
            // Check read_data using the RX LFSR to generate the corresponding expected data
            if (read_data !== expected_data) begin
                cnt_error <= cnt_error + 1;
            end
        end
    end
end

// lsfr_rx enable control
always @(posedge ap_clk or negedge ap_rst_n) begin
    if(!ap_rst_n) begin
        lfsr_enable_rx <= 0;
    end else begin
        if (read_data_valid) begin
            // Check read_data using the RX LFSR to generate the corresponding expected data
            lfsr_enable_rx <= 1; 
        end else begin
            lfsr_enable_rx <= 0;
        end
    end
end

assign total_error_count = cnt_error;

// =========================================================================
// Core Wrapper Instantiation
// =========================================================================
core_wrapper #(
    .C_M_AXIS_WR_TUSER_WIDTH(C_M_AXIS_WR_TUSER_WIDTH),
    .C_M_AXIS_WR_TDATA_WIDTH(C_M_AXIS_WR_TDATA_WIDTH),
    .C_S_AXIS_RD_TDATA_WIDTH(C_S_AXIS_RD_TDATA_WIDTH)
) inst_core_wrapper (
    .ap_clk(ap_clk),
    .ap_rst_n(ap_rst_n),
    
    // Connect to Pseudo Core Logic
    .o_controller_ready(controller_ready),
    .i_command_valid(command_valid_reg),
    .i_command(command_reg),
    .i_write_data(write_data),
    
    .o_read_data_valid(read_data_valid),
    .o_read_data(read_data),
    
    // Connect to External Ports
    .m_axis_wr_tvalid(m_axis_wr_tvalid),
    .m_axis_wr_tready(m_axis_wr_tready),
    .m_axis_wr_tdata(m_axis_wr_tdata),
    .m_axis_wr_tuser(m_axis_wr_tuser),
    .m_axis_wr_tkeep(m_axis_wr_tkeep),
    .m_axis_wr_tlast(m_axis_wr_tlast),
    
    .s_axis_rd_tvalid(s_axis_rd_tvalid),
    .s_axis_rd_tready(s_axis_rd_tready),
    .s_axis_rd_tdata(s_axis_rd_tdata),
    .s_axis_rd_tkeep(s_axis_rd_tkeep),
    .s_axis_rd_tlast(s_axis_rd_tlast)
);

endmodule


// =============================================================================
// Helper Module: 32-bit Galois LFSR
// =============================================================================
module lfsr_32 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [31:0] seed,      
    input  wire        load_seed_flag, 
    output wire [31:0] rand_data  
);
    reg [31:0] r_lfsr;
    wire feedback = r_lfsr[31]; // x^32

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // lfsr reset value cannot be zero
            r_lfsr <= 32'hDEAD_BEEF; 
        end else if (load_seed_flag) begin
            r_lfsr <= seed;          
        end else if (enable) begin
            // Polynomial: x^32 + x^22 + x^2 + x^1 + 1
            r_lfsr <= {r_lfsr[30:0], 1'b0} ^ (feedback ? 32'h00400007 : 32'd0);
        end
    end
    assign rand_data = r_lfsr;
endmodule
