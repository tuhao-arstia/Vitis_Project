set_property vendor fpga_demo [ipx::current_core]
set_property display_name mac_kernel [ipx::current_core]
set_property description mac_kernel_v3 [ipx::current_core]

set_property ipi_drc {ignore_freq_hz false} [ipx::current_core]
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
set_property vitis_drc {ctrl_protocol ap_ctrl_hs} [ipx::current_core]
set_property ipi_drc {ignore_freq_hz true} [ipx::current_core]

ipx::associate_bus_interfaces -busif m_axis_out -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axis_a -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axis_b -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axis_c -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -clock ap_clk -reset interrupt [ipx::current_core]


ipx::add_register CTRL [ipx::get_address_blocks reg0 -of_objects [ipx::get_memory_maps s_axi_control -of_objects [ipx::current_core]]]
set_property address_offset 0x00 [ipx::get_registers CTRL -of_objects [ipx::get_address_blocks reg0 -of_objects [ipx::get_memory_maps s_axi_control -of_objects [ipx::current_core]]]]
set_property size 32 [ipx::get_registers CTRL -of_objects [ipx::get_address_blocks reg0 -of_objects [ipx::get_memory_maps s_axi_control -of_objects [ipx::current_core]]]]