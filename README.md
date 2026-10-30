# Design and Verification of a 5-Stage Pipelined RISC-V RV32I Processor

## Overview

This project implements a 5-stage pipelined RISC-V RV32I processor using SystemVerilog in AMD Vivado. It demonstrates fundamental processor architecture concepts, including instruction execution, pipelining, data forwarding, hazard handling, and control-flow operations.

## Features

- Five-stage pipeline: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write Back (WB).
- RV32I instruction support for selected arithmetic, logical, memory, branch, and jump operations.
- Arithmetic and logical operations: ADD, SUB, AND, OR, XOR.
- Immediate arithmetic using ADDI.
- Memory operations using LW and SW.
- Conditional branches using BEQ and BNE.
- Jump operation using JAL.
- Register forwarding to reduce data hazards.
- Load-use hazard detection and pipeline stalling.
- Branch and jump redirection with pipeline flushing.
- Register x0 hardwired to zero.
- Separate instruction and data memories.

## Technologies Used

- SystemVerilog
- AMD Vivado
- Vivado XSim behavioral simulator

## Project Structure

- `riscv_processor.sv` — Processor RTL implementation.
- `riscv_processor_tb.sv` — Testbench for functional verification.

## Verification

The processor was tested using a SystemVerilog testbench in Vivado.

The test program checks:

- Arithmetic and logical instruction execution.
- Register updates and the x0 constraint.
- Store and load operations.
- Data forwarding and load-use hazard handling.
- Conditional branch behavior.
- Jump execution and skipped instructions.
- Final register and memory values.

**Verification result:** All programmed testbench checks passed with zero errors.

## How to Run

- Open AMD Vivado.
- Create or open a project and add `riscv_processor.sv` under Design Sources.
- Add `riscv_processor_tb.sv` under Simulation Sources.
- Set `riscv_processor_tb` as the simulation top module.
- Run Behavioral Simulation.
- Check the simulation log for the test results.
- Inspect the waveform to observe processor execution and pipeline behavior.

## Learning Outcomes

- Understanding a pipelined processor datapath.
- Implementing instruction decoding and ALU control.
- Understanding pipeline registers and write-back logic.
- Handling data hazards using forwarding and stalling.
- Managing control hazards caused by branches and jumps.
- Verifying RTL designs using simulation and testbenches.

## Scope and Limitations

- Implements a selected subset of RV32I instructions, not the complete RV32I ISA.
- Does not currently include multiplication/division instructions, caches, interrupts, or branch prediction.
- Functional simulation has passed the implemented test cases; synthesis, timing analysis, and FPGA hardware validation are separate steps.

## Author
SAI BHANU TEJASWINI
Developed as an academic project to explore RISC-V processor architecture, pipelined RTL design, and SystemVerilog verification.
