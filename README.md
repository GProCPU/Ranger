# GPro 2 (Ranger) RISC-V CPU

![Status](https://img.shields.io/badge/status-initial_design-blue)
<!-- ![Sim](https://img.shields.io/badge/simulation-passing-green) -->
<!-- ![FPGA](https://img.shields.io/badge/FPGA-failing-red) -->


The GPro 2 (Ranger) is the second generation of RISC-V processors designed by
[Gerber Prototyping](https://g-proto.com). Intended both FPGA implementation and
physical design. Ranger adds a 5-stage pipeline to the previous generation
GPro 1 (Lexington). This processor is currently in the initial design phase as
the focus of a Graduate Independent Study course.

## Features

- RV32IM instruction set
- Modified-Harvard architecture
- 4k instruction and data caches
- Machine-mode and User-mode
- 5-stage pipeline
  - data forwarding
  - speculative execution
  - Low-overhead exception handling

## Pipeline

The pipeline design can be found in [docs/Pipeline.md](./docs/Pipeline.md).
