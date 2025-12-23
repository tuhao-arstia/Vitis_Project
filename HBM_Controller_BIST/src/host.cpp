// host.cpp for hbm_controller BIST

#include "experimental/xrt_bo.h"
#include "experimental/xrt_device.h"
#include "experimental/xrt_kernel.h"
#include "experimental/xrt_ip.h"
#include <iostream>
#include <vector>
#include <unistd.h>
// =============================================================================
// Settings
// =============================================================================
constexpr size_t HBM_BUFFER_SIZE = 256ULL * 1024 * 1024;
// constexpr size_t HBM_BUFFER_SIZE = 1UL * 1024 * 1024 * 1024;
constexpr size_t DATA_WIDTH_BYTES = 128; // 1024 bits
constexpr uint32_t MAX_ADDR_INDEX = 4194303; // 2^22-1 = hardware address limit

// pseudo_core Registers
constexpr uint32_t REG_PC_CTRL   = 0x00;
constexpr uint32_t REG_PC_PKTS   = 0x10;
constexpr uint32_t REG_PC_ERRORS = 0x18;

int main(int argc, char** argv) {
    // argument parsing
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <xclbin> [num_pkts]" << std::endl;
        return 1;
    }

    std::string xclbin_file = argv[1];
    
    // user-defined num_pkts
    uint32_t num_pkts = 10000; // default
    if (argc > 2) {
        try {
            num_pkts = std::stoi(argv[2]);
        } catch (...) {
            std::cerr << "Error: Invalid number format for num_pkts." << std::endl;
            return 1;
        }
    }

    // 2. Safety Check for MAX_ADDR_INDEX
    if (num_pkts > MAX_ADDR_INDEX) {
        std::cerr << "\n[ERROR] Configuration Failed!" << std::endl;
        std::cerr << "Requested packets (" << num_pkts << ") exceeds hardware limit." << std::endl;
        std::cerr << "RTL Counter Width is 22-bit." << std::endl;
        std::cerr << "Max supported packets: " << MAX_ADDR_INDEX << std::endl;
        return 1; 
    }
    
    // HBM Controller total_cmds = R+W commands total
    int total_cmds = num_pkts * 2; 

    try {
        std::cout << "--- HBM Controller BIST System ---" << std::endl;
        auto device = xrt::device(0);
        auto uuid = device.load_xclbin(xclbin_file);

        // ---------------------------------------------------------------------
        // 1. Setup HBM Controller (HLS Kernel)
        // ---------------------------------------------------------------------
        std::cout << "[HOST] Setting up hbm_controller..." << std::endl;
        auto krnl_hbm = xrt::kernel(device, uuid, "hbm_controller");

        // Allocate HBM Buffers
        // Arg 2: hbm_port_wr
        // Arg 3: hbm_port_rd
        auto bo_wr = xrt::bo(device, HBM_BUFFER_SIZE, krnl_hbm.group_id(2));
        auto bo_rd = xrt::bo(device, HBM_BUFFER_SIZE, krnl_hbm.group_id(3));

        // HLS Arguments:
        // 0: s_axis_wr (Stream - auto)
        // 1: m_axis_rd (Stream - auto)
        // 2: hbm_port_wr (Pointer)
        // 3: hbm_port_rd (Pointer)
        // 4: total_cmds (Scalar)
        auto run_hbm = krnl_hbm(nullptr, nullptr, bo_wr, bo_rd, total_cmds);
        
        std::cout << "[HOST] hbm_controller started. (Waiting for stream data...)" << std::endl;

        // ---------------------------------------------------------------------
        // 2. Setup Pseudo Core (RTL BIST Kernel)
        // ---------------------------------------------------------------------
        std::cout << "[HOST] Setting up pseudo_core..." << std::endl;
        // auto krnl_core = xrt::kernel(device, uuid, "pseudo_core");
        auto ip_core   = xrt::ip(device, uuid, "pseudo_core");

        // RTL Arguments:
        // 0: total_pkts (Input)
        // 1: error_count (Dummy Input)
        std::cout << "[HOST] Starting pseudo_core with " << num_pkts << " packets..." << std::endl;
        // auto run_core = krnl_core(num_pkts, 0);
        ip_core.write_register(REG_PC_PKTS, num_pkts);
        uint32_t ctrl_val = 0x1; 
        ip_core.write_register(REG_PC_CTRL, ctrl_val);
        std::cout << "[HOST] pseudo_core started (via Register Write)." << std::endl;

        // ---------------------------------------------------------------------
        // 3. Monitor Loop
        // ---------------------------------------------------------------------
        while (true) {
            uint32_t errors = ip_core.read_register(REG_PC_ERRORS);
            uint32_t ctrl   = ip_core.read_register(REG_PC_CTRL);
            bool pc_done    = ctrl & 0x2;

            std::cout << "\r[Running] Errors: " << errors << " | BIST Done: " << pc_done << std::flush;

            // Check if BIST is done
            if (ctrl & 0x2) {
                break;
            }
            usleep(100000);
        }
        
        // Wait for HLS kernel to finish as well (should finish shortly after BIST)
        // run_hbm.wait();

        // ---------------------------------------------------------------------
        // 4. Results
        // ---------------------------------------------------------------------
        uint32_t final_errors = ip_core.read_register(REG_PC_ERRORS);
        std::cout << "\n\n--- Result ---" << std::endl;
        std::cout << "Packets Sent: " << num_pkts << std::endl;
        std::cout << "Errors      : " << final_errors << std::endl;
        
        if (final_errors == 0) std::cout << "TEST PASS" << std::endl << std::endl;
        else                   std::cout << "TEST FAIL" << std::endl << std::endl;

    } catch (const std::exception& ex) {
        std::cerr << "\nError: " << ex.what() << std::endl;
        return 1;
    }
    return 0;
}