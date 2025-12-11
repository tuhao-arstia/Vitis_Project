// host.cpp for hbm_controller_test
// Verification:
// 1. Generate command and write data on host, then transfer to HBM[4]
// 2. Launch pseudo_core and hbm_controller kernel.
// 3. Launch mm2s_bridge kernel
// 4. Wait for mm2s_bridge to finish
// 5. Verify data on host

#include "experimental/xrt_bo.h"
#include "experimental/xrt_device.h"
#include "experimental/xrt_kernel.h"
#include <iostream>
#include <vector>
#include <string>
#include <random>
#include <algorithm>
#include <cstring>
#include <memory>
#include <iomanip>

// =========================================================
// System Constants
// =========================================================
constexpr size_t HBM_CHANNEL_SIZE = 1UL * 1024 * 1024 * 1024;
constexpr size_t DATA_WIDTH_BYTES = 128; // 1024 bits
// constexpr uint32_t MAX_ADDR_INDEX = (HBM_CHANNEL_SIZE / DATA_WIDTH_BYTES) ; // 8388608 = 2^23
constexpr uint32_t MAX_ADDR_INDEX = 4194304; // 2^22 = hardware address limit

// =========================================================
// Data Structures
// =========================================================
// Transaction (for generation and verification)
struct Transaction {
    uint32_t addr_idx;
    std::vector<uint8_t> write_data; // 128 bytes
    // Read command doesn't need data, but we expect result == write_data
};

// =========================================================
// Pattern Generators
// =========================================================
class PatternGenerator {
public:
    virtual ~PatternGenerator() = default;
    virtual std::vector<Transaction> generate(int count) = 0;
};

// 1. Sequential Access Pattern
class SequentialGenerator : public PatternGenerator {
    uint32_t start_addr;
    uint32_t stride;
public:
    SequentialGenerator(uint32_t start, uint32_t s) : start_addr(start), stride(s) {}
    
    std::vector<Transaction> generate(int count) override {
        std::vector<Transaction> txs;
        std::mt19937 rng(42);
        std::uniform_int_distribution<uint8_t> dist(0, 255); // 8-bit range

        for (int i = 0; i < count; i++) {
            Transaction t;
            t.addr_idx = start_addr + i * stride;
            
            // safety check
            if (t.addr_idx >= MAX_ADDR_INDEX) {
                std::cerr << "[Warn] Generator hit memory limit at index " << i 
                          << ". Truncating pattern." << std::endl;
                break; 
            }

            t.write_data.resize(DATA_WIDTH_BYTES);
            for(auto& b : t.write_data) b = dist(rng);
            
            txs.push_back(t);
        }
        return txs;
    }
};

// 2. Random Access Pattern
class RandomGenerator : public PatternGenerator {
    uint32_t min_addr;
    uint32_t max_addr;
public:
    RandomGenerator(uint32_t min_a, uint32_t max_a) : min_addr(min_a), max_addr(max_a) {}

    std::vector<Transaction> generate(int count) override {
        std::vector<Transaction> txs;
        std::mt19937 rng(1337);
        std::uniform_int_distribution<uint32_t> addr_dist(min_addr, max_addr);
        std::uniform_int_distribution<uint8_t> data_dist(0, 255);

        for (int i = 0; i < count; i++) {
            Transaction t;
            t.addr_idx = addr_dist(rng);
            if (t.addr_idx >= MAX_ADDR_INDEX) t.addr_idx = MAX_ADDR_INDEX - 1;

            t.write_data.resize(DATA_WIDTH_BYTES);
            for(auto& b : t.write_data) b = data_dist(rng);
            
            txs.push_back(t);
        }
        return txs;
    }
};

// =========================================================
// Verification Helper
// =========================================================
void verify_results(const std::vector<Transaction>& golden_txs, const uint8_t* map_out_data) {
    int errors = 0;
    int total = golden_txs.size();
    
    std::cout << "\n=== Verification Report (Total: " << total << ") ===" << std::endl;
    
    // 表頭
    std::cout << std::left << std::setw(15) << "Item" 
              << std::setw(10) << "Address" 
              << std::setw(10) << "Status" 
              << "Details" << std::endl;
    std::cout << std::string(80, '-') << std::endl;

    for (int i = 0; i < total; i++) {
        const uint8_t* res_ptr = map_out_data + (i * DATA_WIDTH_BYTES);
        const uint8_t* golden_ptr = golden_txs[i].write_data.data();

        bool match = (std::memcmp(res_ptr, golden_ptr, DATA_WIDTH_BYTES) == 0);

        // 格式化左側 "Pat[i]"
        std::stringstream ss_item;
        ss_item << "Pat[" << i << "]";
        
        // 格式化 Address，保留7位數寬度
        std::stringstream ss_addr;
        ss_addr << golden_txs[i].addr_idx;

        // 印出基本資訊
        std::cout << std::left 
                  << std::setw(15) << ss_item.str()
                  << std::setw(10) << ss_addr.str();

        if (match) {
            std::cout << std::setw(10) << "[OK]" << "" << std::endl;
        } else {
            errors++;
            std::cout << std::setw(10) << "[FAIL]" << "" << std::endl;
            
            // 詳細 Hex 比較 (前 16 Bytes)
            // 縮排: 15+10+10 = 35 chars
            std::cout << std::string(35, ' ') << "Exp: ";
            for(int b=0; b<16; b++) std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)golden_ptr[b] << " ";
            std::cout << "\n";
            
            std::cout << std::string(35, ' ') << "Got: ";
            for(int b=0; b<16; b++) std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)res_ptr[b] << " ";
            std::cout << std::dec << "\n" << std::endl;
        }
    }
    
    std::cout << std::string(80, '-') << std::endl;
    if (errors == 0) {
        std::cout << "[SUMMARY] PASS! All " << total << " transactions matched." << std::endl;
    } else {
        std::cout << "[SUMMARY] FAIL! Found " << errors << " errors out of " << total << "." << std::endl;
    }
}



// =========================================================
// Main
// =========================================================
int main(int argc, char** argv) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <xclbin_file> [mode: 0=Seq, 1=Rand]" << std::endl;
        return EXIT_FAILURE;
    }
    std::string xclbin_file = argv[1];
    int mode = (argc > 2) ? std::atoi(argv[2]) : 0; // Default Mode: Sequential Access

    // =========================================================
    // 1. Select Generator
    // =========================================================
    std::unique_ptr<PatternGenerator> gen;
    int request_num_tx = 0; 

    // ===================================================================================================================
    //                                          PATTERN USER SETTINGS
    // ===================================================================================================================
    if (mode == 0) {
        std::cout << "=============================" << std::endl;
        std::cout << "-- Mode: Sequential Access --" << std::endl;
        std::cout << "=============================" << std::endl;
        gen = std::make_unique<SequentialGenerator>(0, 1); // User-defined: (Starting_Address, Stride)
        request_num_tx = 500000; // User-defined: number of transactions
    } else {
        std::cout << "===========================" << std::endl;
        std::cout << "--  Mode: Random Access  --" << std::endl;
        std::cout << "===========================" << std::endl;
        uint32_t user_max = 4194303; // User-defined max address index
        if (user_max >= MAX_ADDR_INDEX) {
            std::cerr << "[Warning] User max addr exceeds HBM limit. Clamping to " << (MAX_ADDR_INDEX - 1) << std::endl;
            user_max = MAX_ADDR_INDEX - 1;
        }
        gen = std::make_unique<RandomGenerator>(0, user_max);
        request_num_tx = 500000;  
    }
    // ===================================================================================================================

    // Generate Transactions
    auto transactions = gen->generate(request_num_tx);

    // [New] 建立 Golden Memory Map (模擬 HBM 行為)
    std::map<uint32_t, std::vector<uint8_t>> hbm_shadow_memory;

    // 1. 模擬 Write Phase
    for (const auto& tx : transactions) {
        // 更新 Shadow Memory (如果地址重複，這裡會覆蓋舊值)
        hbm_shadow_memory[tx.addr_idx] = tx.write_data;
    }

    // 2. 更新 Golden Data for Verification
    // 因為在 Read Phase，我們讀到的應該是 Shadow Memory 中的最後值
    // 我們需要一個新的 vector 來存「驗證用的 Golden」
    std::vector<Transaction> verify_golden_txs = transactions; // 複製一份

    for (auto& tx : verify_golden_txs) {
        // 將預期資料更新為 Shadow Memory 中的最終值
        tx.write_data = hbm_shadow_memory[tx.addr_idx];
    }

    // Calculate actual number of transactions generated
    int actual_num_tx = transactions.size();

    if (actual_num_tx < request_num_tx) {
        std::cout << "[Info] Adjusted transaction count from " << request_num_tx 
                  << " to " << actual_num_tx << " (valid range)." << std::endl;
    }
    
    // Calculate Total Packet Counts
    int total_tx_pkts = actual_num_tx * 2; // W + R
    int total_rx_pkts = actual_num_tx;     // R only

    if (total_tx_pkts == 0) {
        std::cerr << "[Error] No valid transactions generated. Check Pattern Settings." << std::endl;
        return EXIT_FAILURE;
    }

    // =========================================================
    // 2. XRT Setup & Buffers
    // =========================================================
    auto device = xrt::device(0);
    auto uuid = device.load_xclbin(xclbin_file);
    auto k_mm2s_bridge = xrt::kernel(device, uuid, "mm2s_bridge");
    // auto k_pseudo_core = xrt::kernel(device, uuid, "pseudo_core"); // ap_ctrl_none: no need to start
    auto k_hbm_ctrl    = xrt::kernel(device, uuid, "hbm_controller");

    auto bo_in_cmd   = xrt::bo(device, total_tx_pkts * 4, k_mm2s_bridge.group_id(3));
    auto bo_in_data  = xrt::bo(device, total_tx_pkts * DATA_WIDTH_BYTES, k_mm2s_bridge.group_id(2));
    auto bo_out_data = xrt::bo(device, total_rx_pkts * DATA_WIDTH_BYTES, k_mm2s_bridge.group_id(4));

    auto map_in_cmd   = bo_in_cmd.map<uint32_t*>();
    auto map_in_data  = bo_in_data.map<uint8_t*>();
    auto map_out_data = bo_out_data.map<uint8_t*>();

    // =========================================================
    // 3. Fill Host Buffers (Burst Write then Burst Read)
    // =========================================================
    int cmd_idx = 0;

    // --- Phase 1: Generate All Write Commands ---
    std::cout << "Generating Write Commands..." << std::endl;
    for (const auto& tx : transactions) {
        // [Write Command]
        // Bit 24 = 0 (Write)
        map_in_cmd[cmd_idx] = (0U << 24) | (tx.addr_idx & 0x3FFFFF);
        
        // [Write Data]
        // Fill in the Pattern
        std::memcpy(map_in_data + (cmd_idx * DATA_WIDTH_BYTES), tx.write_data.data(), DATA_WIDTH_BYTES);
        
        cmd_idx++;
    }

    // --- Phase 2: Generate All Read Commands ---
    std::cout << "Generating Read Commands..." << std::endl;
    for (const auto& tx : transactions) {
        // [Read Command]
        // Bit 24 = 1 (Read)
        map_in_cmd[cmd_idx] = (1U << 24) | (tx.addr_idx & 0x3FFFFF);
        
        // [Read Data (Dummy)]
        // 雖然是 Read，但 Traffic Gen 還是會順序讀取 in_data
        // 所以這裡必須填入 Dummy Data (全0) 來佔位，保持 cmd 和 data 數量 1:1 對齊
        std::memset(map_in_data + (cmd_idx * DATA_WIDTH_BYTES), 0, DATA_WIDTH_BYTES);
        
        cmd_idx++;
    }

    std::cout << "\nPattern Generation Complete. Total Packets: " << cmd_idx << std::endl;

    // Sync to Device
    bo_in_cmd.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_in_data.sync(XCL_BO_SYNC_BO_TO_DEVICE);

    // =========================================================
    // 4. Execution
    // =========================================================
    std::cout << "Starting Kernels..." << std::endl;
    auto run_hbm = k_hbm_ctrl(nullptr, nullptr, nullptr, nullptr, total_tx_pkts);
    // auto run_pseudo = k_pseudo_core(); // ap_ctrl_none: no need to run
    auto run_tg  = k_mm2s_bridge(nullptr, nullptr, bo_in_data, bo_in_cmd, bo_out_data, total_tx_pkts, total_rx_pkts);
    
    run_tg.wait(); 
    std::cout << "\nKernel Finished!" << std::endl;

    // =========================================================
    // 5. Verify
    // =========================================================
    bo_out_data.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
    verify_results(verify_golden_txs, map_out_data);

    return 0;
}
