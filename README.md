# Asynchronous FIFO — Clock Domain Crossing (CDC)

**Course:** Testing and Verification of Digital Circuits — 3EC605ME24  
**Institution:** Nirma University, Department of ECE  
**Authors:** Purvesh Vaghela (23BEC201) | Utsav Raiyani (23BEC199)

---

## Overview

This project implements and verifies a parameterised Asynchronous FIFO
for safe multi-bit Clock Domain Crossing. The design uses Gray code
pointers and 2-FF synchronizers to safely transfer data between two
independent clock domains.

---

## Repository Structure
```
Async-FIFO-CDC/
├── rtl/          # Synthesisable Verilog RTL — all 5 modules
├── tb/           # SystemVerilog testbench with SVA assertions
├── constraints/  # XDC timing constraints for Vivado
└── docs/         # Full project report (PDF)
```

---

## Design Parameters

| Parameter  | Value | Description          |
|------------|-------|----------------------|
| ADDR_WIDTH | 4     | FIFO depth = 2^4 = 16|
| DATA_WIDTH | 8     | 8-bit data bus       |
| W_CLK      | 100 MHz | Write clock        |
| R_CLK      | ~59 MHz | Read clock         |

---

## Modules

| Module | Description |
|--------|-------------|
| FIFO_TOP | Top-level wrapper connecting all modules |
| ASYNC_FIFO_RAM | Dual-port RAM — sync write, async read |
| FIFO_Write_Pointer | Binary counter + Gray code + Full flag |
| FIFO_R_Pointer | Binary counter + Gray code + Empty flag |
| Sync_R2W | 2-FF synchronizer — read ptr to write domain |
| Sync_W2R | 2-FF synchronizer — write ptr to read domain |

---

## Test Cases

9 test cases verified with zero scoreboard errors:

- TC1: Reset behaviour
- TC2: Single write then read
- TC3: Fill FIFO to full
- TC4: Write when full (ignored)
- TC5: Drain FIFO to empty
- TC6: Read when empty (ignored)
- TC7: Half-full streaming operation
- TC8: Reset during operation
- TC9: Pointer wrap-around (3 full cycles)

---

## Tools Used

- Simulation: Xilinx Vivado 2021.x (xsim)
- Synthesis: Xilinx Vivado (Artix-7 xc7a35tcpg236-1)
- Language: Verilog RTL + SystemVerilog Testbench
