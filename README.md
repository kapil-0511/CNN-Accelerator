# CNN Accelerator — 3-Channel 64×64 with 8 Filters

RTL implementation of a 2D convolution accelerator for 3-channel 64×64 input with 8 parallel 3×3×3 filters, controlled via an APB slave interface. Written in Verilog-2001 with a SystemVerilog testbench.

---

## Features

- 3-channel (e.g. RGB) 64×64 input, signed 8-bit pixels
- 8 filters, each 3×3×3 kernel, signed 8-bit weights
- Same-padding (zero-pad): output size equals input size (8×64×64)
- Signed 32-bit accumulator output — no overflow for typical inputs
- APB slave interface: load input/weights, start, poll done, read output
- Fully pipelined row-buffer FSM: pre-fetches next row before computing current
- Verified with 10 random signed test cases — 327,680 / 327,680 PASS

---

## Directory Structure

```
cnn_3ch_64x64/
├── rtl/
│   ├── sram.v               Generic synchronous SRAM
│   ├── mac_unit.v           27-input signed dot product
│   ├── filter_bank.v        8 parallel mac_unit instances
│   ├── line_buffer.v        3-row circular row cache
│   ├── CNN_controller.v     FSM + datapath orchestrator
│   ├── apb_slave.v          APB bus interface + address decode
│   └── CNN_top.v            Top-level wrapper + SRAM arbiter
├── tb/
│   └── tb_CNN.sv            SystemVerilog testbench (10 test cases)
├── docs/
│   └── project_report.md    Full technical report
└── setup_project.tcl        Vivado GUI project setup script
```

---

## Architecture

```
  APB Bus
     │
  CNN_top (arbiter)
     │
     ├── apb_slave        — APB decode, CSR, SRAM mux
     │
     ├── sram (input)     — 16384×32b  (12288 pixels used)
     ├── sram (weight)    —   256×32b  (216 weights used)
     ├── sram (output)    — 32768×32b  (8×64×64 results)
     │
     └── CNN_controller
           │
           ├── line_buffer   — 3-row circular cache → window_flat[216b]
           └── filter_bank   — 8× mac_unit → 8×32b results
```

---

## Address Map

| `paddr[19:18]` | Address range  | Target       | word_addr       | Access     |
|:--------------:|----------------|--------------|-----------------|------------|
| `00`           | 0x00000–0x3FFFF | Input SRAM  | `paddr[15:2]`   | Write      |
| `01`           | 0x40000–0x7FFFF | Weight SRAM | `paddr[9:2]`    | Write      |
| `10`           | 0x80000–0xBFFFF | Output SRAM | `paddr[16:2]`   | Read       |
| `11`           | 0xC0000         | Control reg | —               | Write      |
| `11`           | 0xC0004         | Status reg  | —               | Read       |

**Control reg (0xC0000):** bit[0] = start  
**Status reg  (0xC0004):** bit[0] = done, bit[1] = busy

---

## How to Run Simulation

Requires Xilinx Vivado (tested on 2025.1). Run from the `sim/` directory:

```bash
# 1. Compile
xvlog --relax -prj tb_CNN_vlog.prj

# 2. Elaborate
xelab -debug typical xil_defaultlib.tb_CNN -s tb_CNN_sim

# 3. Simulate
xsim tb_CNN_sim -tclbatch tb_CNN.tcl
```

Expected output (per test):
```
--- Test 1/10  (t=85000) ---
  Input [ch=0] (6x6): ...
  Filter 0 weights (ch0 / ch1 / ch2, each 3x3): ...
  Reference output [filter=0] (6x6): ...
  Test 1 result: 32768 PASS  |  0 FAIL

  GRAND TOTAL (10 tests x 32768): 327680 PASS  |  0 FAIL
```

To open in Vivado GUI:
```bash
vivado -mode batch -source setup_project.tcl
vivado vivado_proj/cnn_3ch_64x64.xpr
```

---

## Module Summary

| Module             | Type        | Description                                      |
|--------------------|-------------|--------------------------------------------------|
| `sram.v`           | RTL         | Parameterised synchronous SRAM (1-cycle latency) |
| `mac_unit.v`       | RTL         | 27-tap signed MAC, combinational                 |
| `filter_bank.v`    | RTL         | 8 parallel mac_units sharing one input window    |
| `line_buffer.v`    | RTL         | 3-row circular buffer, zero-pad slot 3           |
| `CNN_controller.v` | RTL         | 10-state FSM, row-pipeline, weight registers     |
| `apb_slave.v`      | RTL         | APB decode, zero-wait-state, SRAM mux            |
| `CNN_top.v`        | RTL         | Top-level, SRAM arbitration                      |
| `tb_CNN.sv`        | Testbench   | 10 random signed tests, APB driver, checker      |

---

## Test Results

| Metric              | Value                  |
|---------------------|------------------------|
| Test cases          | 10 (random signed)     |
| Elements per test   | 32,768 (8×64×64)       |
| Total comparisons   | 327,680                |
| Pass                | 327,680                |
| Fail                | 0                      |
| Input range         | −128 to +127 (signed)  |
| Weight range        | −128 to +127 (signed)  |
| Output width        | 32-bit signed          |
