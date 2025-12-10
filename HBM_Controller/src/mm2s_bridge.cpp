// mm2s_bridge.cpp
#include "ap_int.h"
#include "ap_axi_sdata.h"
#include "hls_stream.h"

// =========================================================
// Configuration
// =========================================================
#define DATA_WIDTH 1024
#define CMD_WIDTH  25  // Matches pseudo_core s_axis_wr_tuser width
#define HOST_CMD_WIDTH 32 // Input command width from Host (Memory)

// =========================================================
// Type Definitions
// =========================================================

// AXI Stream Packet to Pseudo Core (TDATA + TUSER)
// TUSER carries the 25-bit command
typedef ap_axiu<DATA_WIDTH, CMD_WIDTH, 0, 0> wr_pkt_t;

// AXI Stream Packet from Pseudo Core (TDATA only)
// No TUSER needed for read data response
typedef ap_axiu<DATA_WIDTH, 0, 0, 0> rd_pkt_t;

// =========================================================
// Sub-module: mm2s
// =========================================================
void mm2s(
    hls::stream<wr_pkt_t>& m_axis_wr,
    const ap_uint<DATA_WIDTH>* in_data,
    const ap_uint<HOST_CMD_WIDTH>* in_cmd,
    int total_tx_pkts
) {
    for (int i = 0; i < total_tx_pkts; i++) {
        #pragma HLS PIPELINE II=1
        
        // 1. Read Inputs
        ap_uint<32> raw_cmd = in_cmd[i];
        ap_uint<1024> raw_data = in_data[i];
        
        // 2. Decode Host Command
        // [24]: op_type (1=Read, 0=Write)
        // [21:0]: address
        bool is_read = raw_cmd[24];
        ap_uint<22> addr = raw_cmd(21, 0);

        // 3. Assemble Packet
        wr_pkt_t pkt;

        // TUSER Format required by pseudo_core:
        // [24]   : Op Type (1=Read, 0=Write)
        // [23:22]: Dummy / Data Type (Truncated by pseudo_core)
        // [21:0] : Address
        ap_uint<CMD_WIDTH> tuser_val = 0;
        tuser_val(21, 0) = addr;
        tuser_val(23, 22) = 0; // Padding
        tuser_val[24] = is_read;

        pkt.user = tuser_val;
    
        pkt.data = raw_data;
        pkt.keep = -1; // Keep all bytes
        pkt.last = (i == total_tx_pkts - 1);
        
        // 4. Send
        m_axis_wr.write(pkt);
    }
}

// =========================================================
// Sub-module: s2mm
// =========================================================
void s2mm(
    hls::stream<rd_pkt_t>& s_axis_rd,
    ap_uint<DATA_WIDTH>* out_data,
    int total_rx_pkts
) {
    for (int i = 0; i < total_rx_pkts; i++) {
        #pragma HLS PIPELINE II=1
        
        // Read packet from stream
        rd_pkt_t pkt = s_axis_rd.read();
        
        // Write payload to memory
        out_data[i] = pkt.data;
    }
}

// =========================================================
// Top Level Kernel
// =========================================================
extern "C" {
void mm2s_bridge(
    // AXI Stream Interfaces (Connect to RTL Wrapper/Pseudo Core)
    hls::stream<wr_pkt_t>& m_axis_wr,
    hls::stream<rd_pkt_t>& s_axis_rd,
    
    // Memory Interfaces (Connect to Host Memory/DDR/HBM)
    const ap_uint<DATA_WIDTH>* in_data,
    const ap_uint<HOST_CMD_WIDTH>* in_cmd,
    ap_uint<DATA_WIDTH>* out_data,
    
    // Scalar Controls
    int total_tx_pkts, // Total packets to send (Writes + Reads)
    int total_rx_pkts  // Expected packets to receive (Reads only)
) {
    // AXI Stream Interfaces
    #pragma HLS INTERFACE axis port=m_axis_wr
    #pragma HLS INTERFACE axis port=s_axis_rd
    
    // Memory Interfaces (Separate bundles for potential bandwidth optimization)
    // Using max_read/write_burst_length for performance
    #pragma HLS INTERFACE m_axi port=in_data  bundle=gmem0 offset=slave max_read_burst_length=32
    #pragma HLS INTERFACE m_axi port=in_cmd   bundle=gmem1 offset=slave max_read_burst_length=32
    #pragma HLS INTERFACE m_axi port=out_data bundle=gmem0 offset=slave max_write_burst_length=32
    
    // Control Interface (AXI-Lite)
    #pragma HLS INTERFACE s_axilite port=in_data       bundle=control
    #pragma HLS INTERFACE s_axilite port=in_cmd        bundle=control
    #pragma HLS INTERFACE s_axilite port=out_data      bundle=control
    #pragma HLS INTERFACE s_axilite port=total_tx_pkts bundle=control
    #pragma HLS INTERFACE s_axilite port=total_rx_pkts bundle=control
    #pragma HLS INTERFACE s_axilite port=return        bundle=control

    // Dataflow Architecture: Run mm2s and s2mm in parallel
    #pragma HLS DATAFLOW
    
    mm2s(m_axis_wr, in_data, in_cmd, total_tx_pkts);
    s2mm(s_axis_rd, out_data, total_rx_pkts);
}
}
