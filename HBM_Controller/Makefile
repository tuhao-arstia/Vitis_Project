#
# Copyright 2019-2021 Xilinx, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# makefile-generator v1.0.3
#

############################## Help Section ##############################
ifneq ($(findstring Makefile, $(MAKEFILE_LIST)), Makefile)
help:
	$(ECHO) "Makefile Usage:"
	$(ECHO) "  make all TARGET=<hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to generate the design for specified Target and Shell."
	$(ECHO) ""
	$(ECHO) "  make run TARGET=<hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to run application in emulation."
	$(ECHO) ""
	$(ECHO) "  make build TARGET=<hw_emu/hw> PLATFORM=<FPGA platform>"
	$(ECHO) "      Command to build xclbin application."
	$(ECHO) ""
	$(ECHO) "  make host"
	$(ECHO) "      Command to build host application."
	$(ECHO) ""
	$(ECHO) "  make clean "
	$(ECHO) "      Command to remove the generated non-hardware files."
	$(ECHO) ""
	$(ECHO) "  make cleanall"
	$(ECHO) "      Command to remove all the generated files."
	$(ECHO) ""

endif

############################## Setting up Project Variables ##############################
# Change : set default TARGET and PLATFORM
TARGET ?= hw
PLATFORM ?= xilinx_u280_gen3x16_xdma_1_202211_1

VPP_LDFLAGS :=
include ./utils.mk

TEMP_DIR := ./_x.$(TARGET).$(XSA)
BUILD_DIR := ./build_dir.$(TARGET).$(XSA)

LINK_OUTPUT := $(BUILD_DIR)/test.link.xclbin
PACKAGE_OUT = ./package.$(TARGET)

VPP_PFLAGS := 
CMD_ARGS = -x $(BUILD_DIR)/test.xclbin
CXXFLAGS += -I$(XILINX_XRT)/include -I$(XILINX_VIVADO)/include -Wall -O0 -g -std=c++1y
LDFLAGS += -L$(XILINX_XRT)/lib -pthread -lOpenCL

# Change : include the RTL kernel xo
RTL_KRNL_XO := ./src/rtl_kernel/pseudo_core.xo
# Change : Vitis_HLS include path
CXXFLAGS += -I/tools/Xilinx/Vitis_HLS/2022.2/include


########################## Checking if PLATFORM in allowlist #######################
PLATFORM_BLOCKLIST += nodma 
############################## Setting up Host Variables ##############################
#Include Required Host Source Files
CXXFLAGS += -I$(XF_PROJ_ROOT)/common/includes/cmdparser
CXXFLAGS += -I$(XF_PROJ_ROOT)/common/includes/logger
HOST_SRCS += $(XF_PROJ_ROOT)/common/includes/cmdparser/cmdlineparser.cpp $(XF_PROJ_ROOT)/common/includes/logger/logger.cpp ./src/host.cpp 
# Host compiler global settings
CXXFLAGS += -fmessage-length=0
LDFLAGS += -lrt -lstdc++ 
LDFLAGS += -luuid -lxrt_coreutil

############################## Setting up Kernel Variables ##############################
# Kernel compiler global settings
VPP_FLAGS += --save-temps 

# Change : connectivity linker
VPP_LDFLAGS_RW += --config ./hbm_controller.cfg

EXECUTABLE = ./hbm_test
EMCONFIG_DIR = $(TEMP_DIR)

############################## Setting Targets ##############################
.PHONY: all clean cleanall docs emconfig
all: check-platform check-device check-vitis $(EXECUTABLE) $(BUILD_DIR)/test.xclbin emconfig

.PHONY: host
host: $(EXECUTABLE)

.PHONY: build
build: check-vitis check-device $(BUILD_DIR)/test.xclbin

.PHONY: xclbin
xclbin: build

############################## Setting Rules for Binary Containers (Building Kernels) ##############################
# change : HLS kernel compilation rules
$(TEMP_DIR)/mm2s_bridge.xo: src/mm2s_bridge.cpp
	mkdir -p $(TEMP_DIR)
	v++ -c $(VPP_FLAGS) -t $(TARGET) --platform $(PLATFORM) -k mm2s_bridge --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'

$(TEMP_DIR)/hbm_controller.xo: src/hbm_controller.cpp
	mkdir -p $(TEMP_DIR)
	v++ -c $(VPP_FLAGS) -t $(TARGET) --platform $(PLATFORM) -k hbm_controller --temp_dir $(TEMP_DIR)  -I'$(<D)' -o'$@' '$<'

# change(1) : add cfg file $(VPP_LDFLAGS_RW)
# change(2) : add RTL kernel xo file during linking $()
# template:
# $(BUILD_DIR)/<xclbin_name>.xclbin: $add all xo files one by one here
# 	mkdir -p $(BUILD_DIR)
# 	v++ -l $(VPP_FLAGS) $(VPP_LDFLAGS) -t $(TARGET) --platform $(PLATFORM) --temp_dir $(TEMP_DIR) -o'$(LINK_OUTPUT)' $(+)
# 	v++ -p $(LINK_OUTPUT) $(VPP_FLAGS) -t $(TARGET) --platform $(PLATFORM) --package.out_dir $(PACKAGE_OUT) -o $(BUILD_DIR)/<xclbin_name>.xclbin
$(BUILD_DIR)/test.xclbin: $(TEMP_DIR)/mm2s_bridge.xo  $(TEMP_DIR)/hbm_controller.xo $(RTL_KRNL_XO)
	mkdir -p $(BUILD_DIR)
	v++ -l $(VPP_FLAGS) $(VPP_LDFLAGS) -t $(TARGET) --platform $(PLATFORM) --temp_dir $(TEMP_DIR) $(VPP_LDFLAGS_RW) -o'$(LINK_OUTPUT)' $(TEMP_DIR)/mm2s_bridge.xo $(TEMP_DIR)/hbm_controller.xo $(RTL_KRNL_XO)
	v++ -p $(LINK_OUTPUT) $(VPP_FLAGS) -t $(TARGET) --platform $(PLATFORM) --package.out_dir $(PACKAGE_OUT) -o $(BUILD_DIR)/test.xclbin

############################## Setting Rules for Host (Building Host Executable) ##############################
$(EXECUTABLE): $(HOST_SRCS) | check-xrt
		g++ -o $@ $^ $(CXXFLAGS) $(LDFLAGS)

emconfig:$(EMCONFIG_DIR)/emconfig.json
$(EMCONFIG_DIR)/emconfig.json:
	emconfigutil --platform $(PLATFORM) --od $(EMCONFIG_DIR)

############################## Setting Essential Checks and Running Rules ##############################
run: all
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	cp -rf $(EMCONFIG_DIR)/emconfig.json .
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

.PHONY: test
test: $(EXECUTABLE)
ifeq ($(TARGET),$(filter $(TARGET),sw_emu hw_emu))
	XCL_EMULATION_MODE=$(TARGET) $(EXECUTABLE) $(CMD_ARGS)
else
	$(EXECUTABLE) $(CMD_ARGS)
endif

############################## Cleaning Rules ##############################
# Cleaning stuff
clean:
	-$(RMDIR) $(EXECUTABLE) $(XCLBIN)/{*sw_emu*,*hw_emu*} 
	-$(RMDIR) profile_* TempConfig system_estimate.xtxt *.rpt *.csv 
	-$(RMDIR) src/*.ll *v++* .Xil emconfig.json dltmp* xmltmp* *.log *.jou *.wcfg *.wdb

cleanall: clean
	-$(RMDIR) build_dir*
	-$(RMDIR) package.*
	-$(RMDIR) _x* *xclbin.run_summary qemu-memory-_* emulation _vimage pl* start_simulation.sh *.xclbin

