# Generating RTL Template 

**Make sure to confirm the AXI protocols used by all I/O ports in the RTL design beforehand !!!**

---

## Create a New Vitis Project

Launch the Vitis GUI. Define and choose the workspace by yourself.
   
(1) **Create Application Project**
        
(2) **Platform**
- Choose `xilinx_u280_gen3x16_xdma_1_202211_1`
- Click **Next**

(3) **Application Project Details**
- Application project name : `mac`
- Click **Next**

(4) **Templates** : 
- Choose `Empty Application (XRT Native API's)`
- Click **Finish**

The project window will appear soon.

![create_project](../image/create_project.png)

## Configure the RTL Kernel Wizard
 
Select `Xilinx` > `Launch RTL Kernel Wizard` > `1 mac_kernels`

![launch_wizard](../image/launch_wizard.png)

Based on User RTL I/O definition, complete the settings. 

Please refer to my project architecture.

(1) **General Settings** :

- Kernel control interface : `ap_ctrl_hs`

- Number of clocks : 1

- Has reset : 1 

(2) **Scalars** :

- Number of scalar kernel input arguments : 0

(3) **Global Memory** :

- Number of AXI master interfaces : 0

(4) **Streaming interfaces for Kernel to Kernel Communication** :

- Number of AXI4-Stream interfaces : 4

![axis_interface](../image/axis_interface.png)

    > Note: Vivado 2022.2 does not support 128-byte data width in the wizard, but it can be modified after generating the template.

(5) **Summary** :

- Check everything here and click **OK**. Wait for the Vivado 2022.2 GUI to launch.

## Modify the Generated Template Files

The generated template files are now available in the `Sources` window:

![template_sources](../image/template.png)

| Generated File                        | Role              | Action  | Note                                        |
| :---                                  | :---              | :---    | :---                                        |
| `rtl_kernel_wizard_0.v`               | Top module        | Modify  | Update parameters and integrate user logic. |
| `rtl_kernel_wizard_0_control_s_axi.v` | Control interface | Keep    | No changes required.                        |
| `rtl_kernel_wizard_0_example.sv`      | User RTL logic    | Replace | Delete and replace with user logic.         |

### 1. Top Module
  
The top-level I/O configuration is already done by RTL kernel wizard.

The remaining tasks are :

- **Update the module parameters to meet project requirements**
  
  For this project, the `tdata_width` for 4 AXI-Stream channels (a,b,c, and out) are set to 1024.

- **Integrate user RTL logic**

  Replace the default example instance (`example.sv`) with the user RTL module.

### 2. Control Interface

- **Zero modifications here** (Change the module name if you want.)

### 3. User RTL logic

- **Finish the user RTL design including the AXI protocols (Verification by yourself)**

- **Add I/O ports for `ap_ctrl_hs` signals**

  Handle these 4 signals: `ap_start`, `ap_done`, `ap_idle`, and `ap_ready`.

  Implement a simple FSM to ensure the module can be driven by `ap_start` signal and send `ap_done` signal back correctly.

  > Note: It is highly recommended to use `ap_start_pulse` to drive the FSM instead of using the level-sensitive `ap_start` signal directly. This prevents the FSM from re-triggering unintentionally. 
  
  Here is the example code:

  ```
  [Verilog]
  reg  ap_start_reg;
  wire ap_start_pulse;
  
  always @(posedge ap_clk) begin
      if (ap_rst) begin
          ap_start_reg <= 1'b0;
      end else begin
          ap_start_reg <= ap_start;
      end
  end
  
  // Pulse Generation
  assign ap_start_pulse = ap_start & ~ap_start_reg;
  
  // FSM example
  always @(posedge ap_clk) begin
      if (ap_rst) begin
          current_state <= IDLE;
      end else begin
          case (current_state)
              IDLE: begin
                  if (ap_start_pulse) begin 
                      current_state <= RUNNING;
                  end
              end
              .
              .
              .
          endcase
      end
  end

  ```

After all modifications are done, collect all files into a single directory structure:
```
src/
├── mac.v                (Top-level wrapper)
├── mac_control_s_axi.v  (Control interface)
└── mac_rtl.v            (User logic implementation)
```

## Next Step

Next, you will learn how to [package the user RTL Logic as Vitis kernels](./kernel_packaging.md) (`.xo`) with this directory.