# Vitis

## Source Description
```
├── src/
|   ├── host.cpp            (Host Application)
|   ├── RW.cpp              (2 HLS Kernels here)
|   └── rtl_kernel/mac.xo   (Generated Kernel File)
└── RW.cfg                  
```

## Makefile Usage

1. make build
2. make host
3. ./hbm_test build_dir.hw.xilinx_u280_gen3x16_xdma_1_202211_1/RW.xclbin

## make build
- TARGET = hw/hw_emu (default : hw)
- PLATFORM = xilinx_u280_gen3x16_xdma_1_202211_1 (default)