# RTL_Kernel_Creation

## Source files

| File                      | Role                    | Notes                          |
|---------------------------|-------------------------|--------------------------------|
| `src/mac.v`               | Top module              | Instantiates user RTL & ctrl   |
| `src/mac_control_s_axi.v` | Control interface       | AXI4-Lite for `ap_ctrl` signals|
| `src/mac_rtl.v`           | User RTL logic          | MAC ( FSM control: `ap_ctrl` ) |
| `ip_package.tcl`          | Tool script             | Vivado IP packaging flow       |


## Tutorial

### 1. **Environment Setup**
   
Ensure the Xilinx and GCC environments are sourced.

```
[Xilinx]
(your own setup)

[GCC]
scl enable devtoolset-7 bash
```

### 2. [**Generating RTL Template**](./template_generation.md)

> Make sure to confirm the AXI protocols used by all I/O ports in the RTL design before step 2.

### 3. [**Packaging RTL Kernel**](./kernel_packaging.md)



