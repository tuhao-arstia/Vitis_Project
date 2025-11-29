# Packaging RTL Kernel 

## Source files

| File                  | Role                    | Notes                          |
|-----------------------|-------------------------|--------------------------------|
| `mac.v`               | Top module              | Instantiates user RTL & ctrl   |
| `mac_control_s_axi.v` | Control interface       | AXI4-Lite for `ap_ctrl` signals|
| `mac_rtl.v`           | User RTL logic          | MAC ( FSM control: `ap_ctrl` )     |
|
| `ip_package.tcl`      | Tool script             | Vivado IP packaging flow       |





