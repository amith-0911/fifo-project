# FIFO Design and Verification

A parameterized synchronous FIFO written in SystemVerilog, with a testbench that checks normal reads and writes, simultaneous operations, full and empty status, and overflow and underflow protection.

## Project files

- `design.sv` — FIFO hardware design
- `testbench.sv` — simulation testbench and checks
- `fifo_wf.gtkw` — saved GTKWave signal layout

## Requirements

- Icarus Verilog
- GTKWave (optional, for viewing waveforms)

## Run the simulation

Open a terminal in this project folder and compile the design and testbench:

```powershell
iverilog -g2012 -o fifo_sim design.sv testbench.sv
```

Run the simulation:

```powershell
vvp fifo_sim
```

The testbench prints the results and creates `dump.vcd`.

## View the waveform

Open the waveform in GTKWave:

```powershell
gtkwave dump.vcd
```

To load the saved signal layout, open `fifo_wf.gtkw` in GTKWave.

## Simulation result

The testbench completed with `ALL CHECKS PASSED`.