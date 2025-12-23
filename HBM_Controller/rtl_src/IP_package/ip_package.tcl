# ap_ctrl_none for pseudo core
set_property ipi_drc {ignore_freq_hz false} [ipx::current_core]
set_property sdx_kernel true [ipx::current_core]
set_property sdx_kernel_type rtl [ipx::current_core]
set_property vitis_drc {ctrl_protocol ap_ctrl_hs} [ipx::current_core]
set_property vitis_drc {ctrl_protocol ap_ctrl_none} [ipx::current_core]
set_property ipi_drc {ignore_freq_hz true} [ipx::current_core]

ipx::associate_bus_interfaces -busif m_axis_rd -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif m_axis_wr -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axis_rd -clock ap_clk [ipx::current_core]
ipx::associate_bus_interfaces -busif s_axis_wr -clock ap_clk [ipx::current_core]

