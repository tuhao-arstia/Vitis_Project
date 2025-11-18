// RW.cpp
#include <ap_int.h>
#include <hls_stream.h>
#include <cstddef>

extern "C" {
void RW(
    // Data type 'a'
    const ap_int<1024>*   a_hbm_ch,
    hls::stream<ap_int<1024>>& a_fifo,
    // Data type 'b'
    const ap_int<1024>*   b_hbm_ch,
    hls::stream<ap_int<1024>>& b_fifo,
    // Data type 'c'
    const ap_int<1024>*   c_hbm_ch,
    hls::stream<ap_int<1024>>& c_fifo,
    size_t                num_elements // 10
) {
    #pragma HLS DATAFLOW
    // port interfaces
    #pragma HLS INTERFACE m_axi port=a_hbm_ch   offset=slave bundle=gmem0
    #pragma HLS INTERFACE axis  port=a_fifo
    #pragma HLS STREAM variable=a_fifo depth=8

    #pragma HLS INTERFACE m_axi port=b_hbm_ch   offset=slave bundle=gmem2
    #pragma HLS INTERFACE axis  port=b_fifo
    #pragma HLS STREAM variable=b_fifo depth=8

    #pragma HLS INTERFACE m_axi port=c_hbm_ch   offset=slave bundle=gmem4
    #pragma HLS INTERFACE axis  port=c_fifo
    #pragma HLS STREAM variable=c_fifo depth=8

    // Core logic: simultaneously copy three sets of data
    // HLS will process these three loops in parallel
    copy_a: for (size_t i = 0; i < num_elements; ++i) {
        #pragma HLS PIPELINE II=1
        a_fifo.write(a_hbm_ch[i]);
    }

    copy_b: for (size_t i = 0; i < num_elements; ++i) {
        #pragma HLS PIPELINE II=1
        b_fifo.write(b_hbm_ch[i]);
    }

    copy_c: for (size_t i = 0; i < num_elements; ++i) {
        #pragma HLS PIPELINE II=1
        c_fifo.write(c_hbm_ch[i]);
    }
}
}

extern "C" {
void WB(
    hls::stream<ap_int<1024>>& output_fifo,  // mac output fifo
    ap_int<1024>*              output_hbm_ch,    // write back to HBM
    size_t                     num_elements// 10
) {
    // Port interfaces for WB
    #pragma HLS INTERFACE axis  port=output_fifo
    #pragma HLS INTERFACE m_axi port=output_hbm_ch offset=slave bundle=gmem6 // 使用一個新的 HBM bank

    // --- Stream Depth (optional but recommended) ---
    #pragma HLS STREAM variable=output_fifo depth=8

    // Core logic: write stream data back to HBM
    write_loop: for (size_t i = 0; i < num_elements; ++i) {
        #pragma HLS PIPELINE II=1
        output_hbm_ch[i] = output_fifo.read();
    }
}
} // extern "C"