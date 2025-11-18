#include "experimental/xrt_bo.h"
#include "experimental/xrt_device.h"
#include "experimental/xrt_kernel.h"
#include <iostream>
#include <vector>
#include <random>
#include <cstring> // for memcmp
#include <iomanip> // for std::hex
#include <algorithm> // for std::min

// 1024 bits = 128 bytes
constexpr size_t DATA_WIDTH_BITS = 1024;
constexpr size_t DATA_WIDTH_BYTES = DATA_WIDTH_BITS / 8; // 128 bytes
constexpr size_t NUM_ELEMENTS = 1;
constexpr size_t BUFFER_SIZE_BYTES = NUM_ELEMENTS * DATA_WIDTH_BYTES;

// 輔助函數：解析 1024-bit 緩衝區，印出每個元素末 16-bit 的十進位值
void print_data(const std::string& title, const std::vector<unsigned char>& data, size_t elements_to_print) {
    std::cout << "--- " << title << " ---" << std::endl;
    
    // 計算總共有多少個 1024-bit 的元素
    size_t total_elements = data.size() / DATA_WIDTH_BYTES;
    // 實際要印出的元素數量，取兩者中較小者
    size_t num_to_print = std::min(total_elements, elements_to_print);

    // 遍歷每一個 1024-bit 元素
    for (size_t i = 0; i < num_to_print; ++i) {
        // 計算目前元素在 vector 中的起始位元組索引
        size_t byte_offset = i * DATA_WIDTH_BYTES;

        // 確保我們不會讀取超過 vector 的邊界 (雖然在正常邏輯下不會發生)
        if (byte_offset + 1 < data.size()) {
            // 從 vector 中提取末 16-bit (前 2 bytes)
            // 假設是小端序 (Little-Endian)，這是 x86 和 Alveo 平台的標準
            // Byte 0 是最低位元組 (LSB)，Byte 1 是次低位元組
            uint16_t value = static_cast<uint16_t>(data[byte_offset]) | 
                             (static_cast<uint16_t>(data[byte_offset + 1]) << 8);
            
            // 以十進位形式印出
            std::cout << "Element " << i << ": " << value << std::endl;
        }
    }
    std::cout << "--------------------" << std::endl;
}

int verify_and_print(
    const std::vector<uint8_t>& host_a, 
    const std::vector<uint8_t>& host_b, 
    const std::vector<uint8_t>& host_c, 
    const std::vector<uint64_t>& golden_out, 
    const std::vector<unsigned char>& final_result_buffer,
    size_t elements_to_check) {

    std::cout << "\n==================== VERIFICATION ====================" << std::endl;
    int error_count = 0;
    
    // 確保不會檢查超過實際擁有的元素數量
    size_t num_to_check = std::min({host_a.size(), host_b.size(), host_c.size(), golden_out.size(), elements_to_check});
    num_to_check = std::min(num_to_check, final_result_buffer.size() / DATA_WIDTH_BYTES);

    for (size_t i = 0; i < num_to_check; ++i) {
        std::cout << "PATTERN [" << i << "]:" << std::endl;
        
        // --- 印出輸入 ---
        // static_cast<int> 是為了確保 cout 將 uint8_t 當作數字而不是字元來印
        std::cout << "  a: " << static_cast<int>(host_a[i]) 
                  << "\tb: " << static_cast<int>(host_b[i]) 
                  << "\tc: " << static_cast<int>(host_c[i]) << std::endl;

        // --- 印出黃金輸出 ---
        std::cout << "  golden_output: " << golden_out[i] << std::endl;

        // --- 從 HBM 結果緩衝區中解析出實際輸出 ---
        size_t byte_offset = i * DATA_WIDTH_BYTES;
        uint64_t actual_output = 0; // 用 64-bit 來接收結果
        if (byte_offset + sizeof(uint64_t) <= final_result_buffer.size()) {
            // 從 vector<unsigned char> 中複製 8 bytes 到一個 uint64_t 變數
            memcpy(&actual_output, &final_result_buffer[byte_offset], sizeof(uint64_t));
        }
        std::cout << "  output:        " << actual_output << std::endl;

        // --- 比較並標示錯誤 ---
        if (golden_out[i] != actual_output) {
            std::cout << "  ==> MISMATCH FOUND!" << std::endl;
            error_count++;
        }
        std::cout << std::endl; // 每個 pattern 之間空一行
    }
    
    std::cout << "================ END OF VERIFICATION ================" << std::endl;
    return error_count;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <xclbin>" << std::endl;
        return EXIT_FAILURE;
    }

    // 1. Initialize XRT and device
    auto device = xrt::device(0);
    auto uuid = device.load_xclbin(argv[1]);
    auto kernel_rw = xrt::kernel(device, uuid, "RW");
    auto kernel_mac = xrt::kernel(device, uuid, "mac"); 
    auto kernel_wb = xrt::kernel(device, uuid, "WB");

    // 2. Prepare input data on host
    std::cout << "Generating random host-side input data..." << std::endl;
    std::cout << "Number of patterns: " << NUM_ELEMENTS << std::endl;
    std::vector<uint8_t> host_a(NUM_ELEMENTS);
    std::vector<uint8_t> host_b(NUM_ELEMENTS);
    std::vector<uint8_t> host_c(NUM_ELEMENTS);
    std::vector<uint64_t> golden_mac_out(NUM_ELEMENTS);
    // generate random data and compute golden MAC results
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_int_distribution<uint8_t> distrib(0, 255);
    for (size_t i = 0; i < NUM_ELEMENTS; ++i) {
        host_a[i] = distrib(gen);
        host_b[i] = distrib(gen);
        host_c[i] = distrib(gen);
        golden_mac_out[i] = static_cast<uint64_t>(host_a[i] * host_b[i]) + host_c[i];
    }

    // 8-bit data packed into 1024-bit wide buffers, with the rest zero-padded
    std::vector<unsigned char> packed_a(BUFFER_SIZE_BYTES, 0);
    std::vector<unsigned char> packed_b(BUFFER_SIZE_BYTES, 0);
    std::vector<unsigned char> packed_c(BUFFER_SIZE_BYTES, 0);
    for (size_t i = 0; i < NUM_ELEMENTS; ++i) {
        packed_a[i * DATA_WIDTH_BYTES] = host_a[i];
        packed_b[i * DATA_WIDTH_BYTES] = host_b[i];
        packed_c[i * DATA_WIDTH_BYTES] = host_c[i];
    }
    // golden output packed similarly
    std::vector<unsigned char> packed_golden_out(BUFFER_SIZE_BYTES, 0);
    for (size_t i = 0; i < NUM_ELEMENTS; ++i) {
        memcpy(&packed_golden_out[i * DATA_WIDTH_BYTES], &golden_mac_out[i], sizeof(uint64_t));
    }

    // 3. 在 HBM 上分配緩衝區 (與原程式碼相同)
    std::cout << "Allocating buffers on HBM..." << std::endl;
    // RW 核心的輸入緩衝區 (對應 HBM[0], HBM[2], HBM[4])
    auto bo_in_a = xrt::bo(device, BUFFER_SIZE_BYTES, kernel_rw.group_id(0)); // in_a
    auto bo_in_b = xrt::bo(device, BUFFER_SIZE_BYTES, kernel_rw.group_id(2)); // in_b
    auto bo_in_c = xrt::bo(device, BUFFER_SIZE_BYTES, kernel_rw.group_id(4)); // in_c
    
    // WB 核心的輸出緩衝區 (對應 HBM[6])
    // kernel_wb.group_id(1) 對應 WB 核心的第二個參數 'out_hbm'
    auto bo_out_wb = xrt::bo(device, BUFFER_SIZE_BYTES, kernel_wb.group_id(1));

    // 4. 將輸入資料從主機傳輸到 HBM
    std::cout << "Writing data to HBM..." << std::endl;
    bo_in_a.write(packed_a.data());
    bo_in_b.write(packed_b.data());
    bo_in_c.write(packed_c.data());
    bo_in_a.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_in_b.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_in_c.sync(XCL_BO_SYNC_BO_TO_DEVICE);

    // 5. 執行核心管線 (Pipeline)
    //    同時啟動三個核心，資料會自動從 RW -> mac -> WB
    std::cout << "Executing kernel pipeline..." << std::endl;
    // --- 啟動 RW 核心 ---
    // void RW:
    // a_hbm_ch[0], a_fifo[1], b_hbm_ch[2], b_fifo[3]
    // c_hbm_ch[4], c_fifo[5], num_elements[6]
    auto run_rw = xrt::run(kernel_rw);
    run_rw.set_arg(0, bo_in_a);        // arg 0: in_a
    run_rw.set_arg(2, bo_in_b);        // arg 2: in_b
    run_rw.set_arg(4, bo_in_c);        // arg 4: in_c
    run_rw.set_arg(6, NUM_ELEMENTS);   // arg 6: num_elements
    run_rw.start();

    // --- 啟動 mac 核心 ---
    // mac 核心沒有任何 Host 可設定的參數
    auto run_mac = xrt::run(kernel_mac);
    run_mac.start();

    // --- 啟動 WB 核心 ---
    // void WB(output_fifo[0], output_hbm_ch[1], num_elements[2])
    auto run_wb = xrt::run(kernel_wb);
    run_wb.set_arg(1, bo_out_wb);      // arg 1: out_hbm
    run_wb.set_arg(2, NUM_ELEMENTS);   // arg 2: num_elements
    run_wb.start();
    
    // 只需要等待管線的最後一個核心 (WB) 完成即可
    std::cout << "Waiting for WB kernel to complete writing back 10 elements..." << std::endl;
    run_wb.wait();

    // 6. 將 WB 的結果從 HBM 讀回主機
    std::cout << "Reading results from HBM..." << std::endl;
    std::vector<unsigned char> final_result(BUFFER_SIZE_BYTES);
    bo_out_wb.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
    bo_out_wb.read(final_result.data());
    
    // 7. 驗證結果 (使用新的輔助函數)
    int errors = verify_and_print(
        host_a, 
        host_b, 
        host_c, 
        golden_mac_out, 
        final_result, 
        NUM_ELEMENTS
    );

    if (errors == 0) {
        std::cout << "\nTEST PASSED! All patterns match." << std::endl;
    } else {
        std::cout << "\nTEST FAILED! " << errors << " mismatches found." << std::endl;
    }

    return (errors == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
