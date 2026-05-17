# Synchronous FIFO Design and Verification using UVM

## Project Overview

This project implements and verifies a **Synchronous FIFO** using **SystemVerilog** and **UVM methodology**.

Link : https://www.edaplayground.com/x/94BG

A FIFO, or First-In First-Out memory, stores data in the same order in which it is written. The first data written into the FIFO will be the first data read out.

This project includes:

- RTL design of a parameterized synchronous FIFO
- UVM-based verification environment
- Directed and random test sequences
- Functional coverage
- SystemVerilog Assertions
- Scoreboard-based checking
- Waveform analysis
- Simulation output with 0 errors and 100% functional coverage

---

## Design Name

```text
sync_fifo
```

---

## FIFO Parameters

| Parameter | Value | Description |
|---|---:|---|
| DATA_WIDTH | 8 | Width of the FIFO data bus |
| DEPTH | 16 | Number of FIFO storage locations |
| ADDR_WIDTH | 4 | Address width required for 16 locations |

---

## DUT Interface Signals

| Signal | Direction | Width | Description |
|---|---|---:|---|
| clk | Input | 1 | Clock signal |
| rst_n | Input | 1 | Active-low synchronous reset |
| wr_en | Input | 1 | Write enable |
| rd_en | Input | 1 | Read enable |
| wr_data | Input | 8 | Data input to FIFO |
| rd_data | Output | 8 | Data output from FIFO |
| full | Output | 1 | Indicates FIFO is full |
| empty | Output | 1 | Indicates FIFO is empty |
| almost_full | Output | 1 | Indicates FIFO has only one free location left |
| almost_empty | Output | 1 | Indicates FIFO has only one valid entry left |
| count | Output | 5 | Number of valid entries currently stored in FIFO |

---

## RTL Design Description

The synchronous FIFO is designed using:

- Memory array
- Write pointer
- Read pointer
- Count register
- Full and empty flag logic
- Almost full and almost empty flag logic

### Internal Memory

```systemverilog
logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
```

The FIFO memory stores `DEPTH` number of entries, each having `DATA_WIDTH` bits.

---

## Write Operation

A write operation is accepted only when:

```text
wr_en = 1
full  = 0
```

The internal valid write condition is:

```systemverilog
wire wr_valid = wr_en && !full;
```

When `wr_valid` is high:

- `wr_data` is written into memory
- `wr_ptr` increments
- `count` increments by 1

If the FIFO is full, the write operation is blocked even if `wr_en` is high.

---

## Read Operation

A read operation is accepted only when:

```text
rd_en = 1
empty = 0
```

The internal valid read condition is:

```systemverilog
wire rd_valid = rd_en && !empty;
```

When `rd_valid` is high:

- Data is read from memory
- `rd_data` gets updated
- `rd_ptr` increments
- `count` decrements by 1

If the FIFO is empty, the read operation is blocked even if `rd_en` is high.

---

## Count Logic

The FIFO count tracks the number of valid entries currently stored in the FIFO.

```systemverilog
case ({wr_valid, rd_valid})
    2'b10:   count <= count + 1;  // Write only
    2'b01:   count <= count - 1;  // Read only
    default: count <= count;      // Idle or simultaneous read/write
endcase
```

### Count Behavior

| Operation | wr_valid | rd_valid | Count Behavior |
|---|---:|---:|---|
| Write only | 1 | 0 | Count increments |
| Read only | 0 | 1 | Count decrements |
| Simultaneous read/write | 1 | 1 | Count remains same |
| Idle | 0 | 0 | Count remains same |

---

## Status Flag Logic

```systemverilog
assign full         = (count == DEPTH);
assign empty        = (count == 0);
assign almost_full  = (count == DEPTH - 1);
assign almost_empty = (count == 1);
```

### Flag Behavior

| Condition | Expected Flag |
|---|---|
| count = 0 | empty = 1 |
| count = 1 | almost_empty = 1 |
| count = DEPTH - 1 | almost_full = 1 |
| count = DEPTH | full = 1 |

For this design:

```text
DEPTH = 16
```

So:

```text
count = 0  -> empty = 1
count = 1  -> almost_empty = 1
count = 15 -> almost_full = 1
count = 16 -> full = 1
```

---

## Reset Behavior

The design uses an **active-low synchronous reset**.

When `rst_n = 0`, the FIFO resets on the positive edge of the clock.

During reset:

```text
wr_ptr  = 0
rd_ptr  = 0
rd_data = 0
count   = 0
empty   = 1
full    = 0
```

Since reset is synchronous, output changes are expected only with respect to the clock edge.

---

## UVM Testbench Architecture

The verification environment is developed using UVM.

### UVM Components

```text
fifo_test
  |
  |-- fifo_env
        |
        |-- fifo_agent
        |     |
        |     |-- fifo_sequencer
        |     |-- fifo_driver
        |     |-- fifo_monitor
        |
        |-- fifo_scoreboard
```

---

## UVM Testbench Block Diagram

```text
+------------------+
|    fifo_test     |
+--------+---------+
         |
         v
+------------------+
|     fifo_env     |
+--------+---------+
         |
         +-----------------------------+
         |                             |
         v                             v
+------------------+          +------------------+
|    fifo_agent    |          | fifo_scoreboard  |
+--------+---------+          +------------------+
         |
         +-----------------------------+
         |              |              |
         v              v              v
+-------------+  +-------------+  +-------------+
| sequencer   |  |   driver    |  |  monitor    |
+-------------+  +-------------+  +-------------+
                       |              |
                       v              v
                +----------------------------+
                |        fifo_if             |
                +----------------------------+
                       |
                       v
                +----------------------------+
                |        sync_fifo DUT       |
                +----------------------------+
```

---

## Interface

The testbench uses a SystemVerilog interface named:

```systemverilog
fifo_if
```

The interface contains:

- DUT input signals
- DUT output signals
- Driver clocking block
- Monitor clocking block
- Driver modport
- Monitor modport
- SystemVerilog Assertions

---

## Configuration Class

The testbench uses a UVM configuration class:

```systemverilog
class fifo_config extends uvm_object;
```

The configuration class contains:

- Virtual interface handle
- Agent active/passive setting
- FIFO data width
- FIFO depth

This configuration object is passed through the UVM configuration database.

---

## Sequence Item

The transaction class is:

```systemverilog
class fifo_item extends uvm_sequence_item;
```

It contains stimulus fields:

```systemverilog
rand logic       rst_n;
rand logic       wr_en;
rand logic       rd_en;
rand logic [7:0] wr_data;
```

It also contains response fields sampled by the monitor:

```systemverilog
logic [7:0] rd_data;
logic       full;
logic       empty;
logic       almost_full;
logic       almost_empty;
logic [4:0] count;
```

---

## Test Sequences

The testbench includes both directed and random sequences.

### 1. Reset Sequence

```text
fifo_reset_seq
```

This sequence verifies reset behavior.

It checks that after reset:

```text
count = 0
empty = 1
full  = 0
```

---

### 2. Write Full Sequence

```text
fifo_write_full_seq
```

This sequence writes 16 entries into the FIFO and fills it completely.

It verifies:

```text
count reaches 16
full becomes 1
almost_full becomes 1 when count = 15
```

It also attempts one extra write when FIFO is full to verify overflow protection.

---

### 3. Read Empty Sequence

```text
fifo_read_empty_seq
```

This sequence reads all FIFO entries until the FIFO becomes empty.

It verifies:

```text
count reaches 0
empty becomes 1
almost_empty becomes 1 when count = 1
```

It also attempts one extra read when FIFO is empty to verify underflow protection.

---

### 4. Simultaneous Read/Write Sequence

```text
fifo_simrw_seq
```

This sequence verifies simultaneous read and write operation.

Expected behavior:

```text
wr_en = 1
rd_en = 1
full  = 0
empty = 0
```

The FIFO should perform both read and write in the same cycle, and the count should remain unchanged.

---

### 5. Boundary Data Sequence

```text
fifo_boundary_data_seq
```

This sequence writes boundary data values:

```text
0x00
0xFF
```

It verifies that the FIFO can store and read boundary values correctly.

---

### 6. Flag Idle Coverage Sequence

```text
fifo_flag_idle_cov_seq
```

This sequence targets idle conditions when FIFO is full and empty.

It helps improve coverage for flag-related scenarios.

---

### 7. Cross Coverage Sequence

```text
fifo_cross_cov_seq
```

This sequence targets operation and flag cross coverage.

It includes cases such as:

- Write while FIFO is empty
- Simultaneous read/write while FIFO is empty
- Read while FIFO is full
- Simultaneous read/write while FIFO is full

---

### 8. Random Sequence

```text
fifo_rand_seq
```

This sequence generates random FIFO operations.

The operation distribution includes:

| Operation | Encoding | Weight |
|---|---:|---:|
| Write only | 2'b10 | 30 |
| Read only | 2'b01 | 30 |
| Simultaneous read/write | 2'b11 | 25 |
| Idle | 2'b00 | 15 |

---

## Scoreboard

The scoreboard uses a software queue as the reference model.

```systemverilog
logic [7:0] ref_queue[$];
```

The scoreboard checks:

- Reset behavior
- Count value
- Empty flag
- Full flag
- Almost full flag
- Almost empty flag
- Overflow protection
- Underflow protection
- FIFO ordering

---

## Scoreboard Checking Method

The scoreboard calculates valid operations using:

```systemverilog
bit wr_valid = item.wr_en && !item.full;
bit rd_valid = item.rd_en && !item.empty;
```

This matches the DUT behavior.

### Overflow Handling

If:

```text
wr_en = 1
full  = 1
```

then:

```text
wr_valid = 0
```

So the write is blocked.

### Underflow Handling

If:

```text
rd_en = 1
empty = 1
```

then:

```text
rd_valid = 0
```

So the read is blocked.

---

## SystemVerilog Assertions

The interface contains assertions to verify important FIFO properties.

Assertions include:

1. FIFO must become empty after reset
2. FIFO must not be full after reset
3. Count must be zero after reset
4. Full and empty should never be high at the same time
5. Count should never exceed FIFO depth
6. Full should assert when count equals depth
7. Empty should assert when count equals zero
8. Write to full FIFO should not change count
9. Read from empty FIFO should not change count
10. Almost full should assert when count equals depth - 1
11. Almost empty should assert when count equals 1
12. Simultaneous read/write should keep count stable
13. Write should increment count
14. Read should decrement count

---

## Functional Coverage

The testbench includes 8 functional coverage groups.

| Covergroup | Description |
|---|---|
| cg_operations | Covers write, read, simultaneous read/write, and idle operations |
| cg_rst | Covers reset active and inactive states |
| cg_full | Covers full and not-full conditions |
| cg_empty | Covers empty and not-empty conditions |
| cg_boundary_flags | Covers almost_full and almost_empty |
| cg_overflow_underflow | Covers overflow and underflow attempts |
| cg_data_values | Covers write/read data values including 0x00 and 0xFF |
| cg_ops_x_flags | Cross coverage of operation type with full and empty flags |

---

## Simulation Result

The simulation completed successfully.

### Scoreboard Summary

```text
PASS               : 2372
FAIL               : 0
RESETS             : 10
OVERFLOW ATTEMPTS  : 2
UNDERFLOW ATTEMPTS : 16
```

The scoreboard reported:

```text
*** ALL CHECKS PASSED ***
```

---

## Functional Coverage Result

```text
cg_operations         : 100.00%
cg_rst                : 100.00%
cg_full               : 100.00%
cg_empty              : 100.00%
cg_boundary_flags     : 100.00%
cg_overflow_underflow : 100.00%
cg_data_values        : 100.00%
cg_ops_x_flags        : 100.00%
```

Overall functional coverage achieved:

```text
100%
```

---

## UVM Report Summary

```text
UVM_INFO    : 55
UVM_WARNING : 0
UVM_ERROR   : 0
UVM_FATAL   : 0
```

The simulation completed without any UVM errors or fatal messages.

---

## Waveform Analysis

The waveform confirms correct synchronous FIFO behavior.

### Write Operation

During write operation:

```text
wr_en = 1
rd_en = 0
full  = 0
```

Observed behavior:

```text
count increments from 0 to 16
wr_ptr increments from 0 to 15 and wraps to 0
empty deasserts after first write
almost_full asserts at count = 15
full asserts at count = 16
```

This confirms that write operation and full flag generation are working correctly.

---

### Full Condition

When the FIFO becomes full:

```text
count = 16
full  = 1
```

At this point, `wr_en` may remain high for one extra cycle due to stimulus, but the internal write condition becomes invalid:

```systemverilog
wr_valid = wr_en && !full;
```

So when `full = 1`:

```text
wr_valid = 0
```

This prevents overflow.

Expected behavior observed:

```text
full becomes high
wr_valid becomes low
wr_en may stay high for one extra cycle
count does not exceed 16
wr_ptr does not increment further
```

This is correct FIFO behavior.

---

### Read Operation

During read operation:

```text
rd_en = 1
wr_en = 0
empty = 0
```

Observed behavior:

```text
count decrements
rd_ptr increments
rd_data comes out in the same order as written
```

This confirms FIFO ordering.

---

### Empty Condition

When FIFO becomes empty:

```text
count = 0
empty = 1
```

At this point, `rd_en` may remain high for one extra cycle due to stimulus, but the internal read condition becomes invalid:

```systemverilog
rd_valid = rd_en && !empty;
```

So when `empty = 1`:

```text
rd_valid = 0
```

This prevents underflow.

Expected behavior observed:

```text
empty becomes high
rd_valid becomes low
rd_en may stay high for one extra cycle
rd_ptr remains stable
rd_data holds the last valid read value
count does not go below 0
```

This is correct FIFO behavior.

---

### Read Data Hold Behavior

When the FIFO is empty and `rd_valid = 0`, the design does not update `rd_data`.

Therefore, `rd_data` holds the last valid read value.

This is valid registered-output FIFO behavior.

---

## Key Verification Scenarios Covered

| Scenario | Status |
|---|---|
| Reset behavior | Passed |
| Write operation | Passed |
| Read operation | Passed |
| FIFO full condition | Passed |
| FIFO empty condition | Passed |
| Almost full condition | Passed |
| Almost empty condition | Passed |
| Overflow attempt | Passed |
| Underflow attempt | Passed |
| Simultaneous read/write | Passed |
| Boundary data 0x00 | Passed |
| Boundary data 0xFF | Passed |
| Random operations | Passed |
| Functional coverage | 100% |
| UVM errors | 0 |
| UVM fatal errors | 0 |

---

## Tools Used

- SystemVerilog
- UVM
- EDA Playground
- EPWave
- Simulator with UVM 1800.2-2020 support

---

## Files in this Project

```text
design.sv      - RTL design of synchronous FIFO
testbench.sv   - Complete UVM testbench
README.md      - Project documentation
```

Optional generated files:

```text
fifo_tb.vcd    - Waveform dump file
fcover.acdb    - Functional coverage database
```

---

## How to Run

1. Open the project in EDA Playground.
2. Add the RTL code in `design.sv`.
3. Add the UVM testbench code in `testbench.sv`.
4. Select a simulator that supports SystemVerilog and UVM.
5. Enable waveform dumping.
6. Run the simulation.
7. Open EPWave to view the waveform.

---

## Expected Output

The expected simulation output should show:

```text
*** ALL CHECKS PASSED ***
```

and:

```text
UVM_ERROR : 0
UVM_FATAL : 0
```

The expected functional coverage should be:

```text
100%
```

---

## Conclusion

This project successfully verifies a parameterized synchronous FIFO using UVM.

The RTL design correctly supports:

- Write operation
- Read operation
- Full condition
- Empty condition
- Almost full condition
- Almost empty condition
- Overflow protection
- Underflow protection
- Simultaneous read/write operation
- FIFO data ordering

The UVM testbench verifies the design using directed sequences, random stimulus, assertions, scoreboard checks, and functional coverage.

Final result:

```text
Scoreboard Failures : 0
Functional Coverage : 100%
UVM Errors          : 0
UVM Fatal Errors    : 0
```

Therefore, the synchronous FIFO design is functionally verified successfully.

---

## Author

**Ahalya S Kumar**

GitHub: [ASK1209](https://github.com/ASK1209)
