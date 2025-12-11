// hbm_controller.cpp
// Target: Vitis 2022.2, Alveo U280
// Application: LLM Inference (Read-intensive workload)
// Features:
// - Dataflow architecture for high throughput
// - Backpressure control for Read Credit
// - Write Barrier to prevent Read-After-Write hazards
// - AXI Stream interface

#include "ap_int.h"
#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include <cstddef>

// ==========================================================
// Parameter Definitions
// ==========================================================
#define CMD_WIDTH 23
#define DATA_WIDTH 1024

// Read Credit Limit:
#define MAX_READ_CREDITS 32

// ==========================================================
// Type Definitions
// ==========================================================
// AXI Stream Packet from RTL (TDATA + TUSER)
typedef ap_axiu<DATA_WIDTH, CMD_WIDTH, 0, 0> wr_pkt_t;

// AXI Stream Packet to RTL (TDATA only)
typedef ap_axiu<DATA_WIDTH, 0, 0, 0> rd_pkt_t;

// Token for Credit/Barrier signaling
typedef ap_uint<1> token_t;

// Internal Request Structures
struct write_req_t {
    ap_uint<22> addr;
    ap_uint<1024> data;
};

struct read_req_t {
    ap_uint<22> addr;
};

// ==========================================================
// Dispatcher (Command Decoding & Flow Control)
// ==========================================================
void dispatcher(
    hls::stream<wr_pkt_t>& s_axis_wr,        // Input from pseudo_core
    hls::stream<write_req_t>& wr_req_fifo,    // To Writer
    hls::stream<read_req_t>& rd_req_fifo,     // To Reader
    hls::stream<token_t>& read_credit_in,    // Read Credit Return
    hls::stream<token_t>& write_done_in,     // Write Done Signal
    int total_cmds
) {
    int outstanding_reads = 0;
    int outstanding_writes = 0;
    
    for(int i = 0; i < total_cmds; i++) {
    #pragma HLS PIPELINE II=1

        token_t tok;
        
        // 1. Reclaim Read Credit (Non-blocking)
        if (read_credit_in.read_nb(tok)) {
            outstanding_reads--;
        }
        
        // 2. Reclaim Write Done Token (Non-blocking)
        if (write_done_in.read_nb(tok)) {
            outstanding_writes--;
        }

        // 3. Read Command Packet
        wr_pkt_t pkt = s_axis_wr.read();
        
        // 4. Decode TUSER (Command)
        // TUSER[22] : 1=Read, 0=Write
        // TUSER[21:0]: Address (word-aligned index)
        ap_uint<23> cmd = pkt.user;
        bool is_read = cmd[22];
        ap_uint<22> addr = cmd(21, 0);

        if (is_read) {
            // =====================================================
            // READ Request
            // =====================================================

            // Step A: Write Barrier (RAW Hazard Prevention)
            // wait until all prior writes complete
            while (outstanding_writes > 0) {
                #pragma HLS PIPELINE II=1
                // During wait, continuously reclaim signals to prevent deadlock
                if (write_done_in.read_nb(tok)) outstanding_writes--;
                if (read_credit_in.read_nb(tok)) outstanding_reads--;
            }

            // Step B: Read Credit Check (Backpressure)
            // Ensure Read Data FIFO has space
            while (outstanding_reads >= MAX_READ_CREDITS) {
                #pragma HLS PIPELINE II=1
                if (read_credit_in.read_nb(tok)) outstanding_reads--;
                if (write_done_in.read_nb(tok)) outstanding_writes--;
            }
            
            // Step C: Send Read Request
            rd_req_fifo.write({addr});
            outstanding_reads++;

        } else {
            // =====================================================
            // WRITE Request
            // =====================================================
            
            // Send Write Request
            wr_req_fifo.write({addr, pkt.data});
            outstanding_writes++;
        }
    }
}

// ==========================================================
// Writer (HBM Write Operations)
// ==========================================================
void proc_writer(
    hls::stream<write_req_t>& wr_req_fifo,
    hls::stream<token_t>& write_done_out,  // Signal when Write is issued
    ap_uint<1024>* hbm_port_wr
) {
    while(1) {
    #pragma HLS PIPELINE II=1
        if (!wr_req_fifo.empty()) {
            write_req_t req = wr_req_fifo.read();
            
            // Perform HBM Write
            hbm_port_wr[req.addr] = req.data;
            
            // Report Write Done (when AXI Write Request is issued)
            write_done_out.write(1);
        }
    }
}

// ==========================================================
// Reader (HBM Read Operations)
// ==========================================================
void proc_reader(
    hls::stream<read_req_t>& rd_req_fifo,
    hls::stream<rd_pkt_t>& m_axis_rd,      // Output to RTL
    hls::stream<token_t>& read_credit_out, // Credit Return
    const ap_uint<1024>* hbm_port_rd
) {
    while(1) {
    #pragma HLS PIPELINE II=1
        if (!rd_req_fifo.empty()) {
            read_req_t req = rd_req_fifo.read();
            
            // Perform HBM Read
            ap_uint<1024> rdata = hbm_port_rd[req.addr];
            
            // Assemble AXI Stream Packet
            rd_pkt_t tx_pkt;
            tx_pkt.data = rdata;
            tx_pkt.keep = -1;  // All bytes valid
            tx_pkt.last = 0;   // TLAST handling
            
            // Send to RTL
            m_axis_rd.write(tx_pkt);
            
            // Release Credit (inform Dispatcher: FIFO has one free slot)
            read_credit_out.write(1);
        }
    }
}

// ==========================================================
// Top Level Kernel: hbm_controller
// ==========================================================
extern "C" {
void hbm_controller(
    // Input: From pseudo_core (m_axis_wr)
    hls::stream<wr_pkt_t>& s_axis_wr,    
    
    // Output: To pseudo_core (s_axis_rd)
    hls::stream<rd_pkt_t>& m_axis_rd,     
    
    // HBM Ports
    ap_uint<1024>* hbm_port_wr,  // Write Port        
    const ap_uint<1024>* hbm_port_rd,  // Read Port
    
    // Scalar Argument
    int total_cmds             // Total number of commands to process
) {
    // ======================================================
    // Interface Pragmas
    // ======================================================
    #pragma HLS INTERFACE axis port=s_axis_wr
    #pragma HLS INTERFACE axis port=m_axis_rd
    
    // HBM AXI-Master Interface
    #pragma HLS INTERFACE m_axi port=hbm_port_wr offset=slave bundle=gmem_wr \
        max_write_burst_length=16 num_write_outstanding=4
    #pragma HLS INTERFACE m_axi port=hbm_port_rd offset=slave bundle=gmem_rd \
        max_read_burst_length=16 num_read_outstanding=4
    
    // Control Interface (AXI-Lite)
    #pragma HLS INTERFACE s_axilite port=total_cmds bundle=control
    #pragma HLS INTERFACE s_axilite port=hbm_port_wr bundle=control
    #pragma HLS INTERFACE s_axilite port=hbm_port_rd bundle=control
    #pragma HLS INTERFACE s_axilite port=return bundle=control

    // ======================================================
    // Dataflow Architecture
    // ======================================================
    #pragma HLS DATAFLOW

    // Internal FIFOs
    static hls::stream<write_req_t> w_fifo;
    static hls::stream<read_req_t> r_fifo;
    static hls::stream<token_t> read_credit_fifo;
    static hls::stream<token_t> write_done_fifo;

    #pragma HLS STREAM variable=w_fifo depth=16
    #pragma HLS STREAM variable=write_done_fifo depth=16

    #pragma HLS STREAM variable=r_fifo depth=32
    #pragma HLS STREAM variable=read_credit_fifo depth=32

    // ======================================================
    // Launch Parallel Processes
    // ======================================================
    dispatcher(s_axis_wr, w_fifo, r_fifo, read_credit_fifo, write_done_fifo, total_cmds);
    proc_writer(w_fifo, write_done_fifo, hbm_port_wr);
    proc_reader(r_fifo, m_axis_rd, read_credit_fifo, hbm_port_rd);
}
}
