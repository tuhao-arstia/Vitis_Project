# RTL_Kernel_Creation

## Source files

| File                  | Role                    | Notes                          |
|-----------------------|-------------------------|--------------------------------|
| `mac.v`               | Top module              | Instantiates user RTL & ctrl   |
| `mac_control_s_axi.v` | Control interface       | AXI4-Lite for `ap_ctrl` signals|
| `mac_rtl.v`           | User RTL logic          | MAC ( FSM control: `ap_ctrl` )     |
|
| `ip_package.tcl`      | Tool script             | Vivado IP packaging flow       |


## Tutorial

### 1. **Environment Setup**
   
Ensure the Xilinx and GCC environments are sourced.

```
[Xilinx]
(your own setup)

[GCC]
scl enable devtoolset-7 bash
```

### 2. **Implementing RTL & Interfaces **
   
Finish the user RTL logic, ensuring all the I/O ports follow the AXI protocol.
   
Add I/O ports for `ap_ctrl` signals and implement a simple FSM controlled by `ap_ctrl`.

Refer to the following steps to better understand these modifications.

### 3. [**Generating RTL Template**](./template_generation.md)

### 4. [**Packaging RTL Kernel**](./kernel_packaging.md)



