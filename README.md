# GPro 3 (Ranger) RISC-V CPU

![Status](https://img.shields.io/badge/status-planned-blue)
<!-- ![Sim](https://img.shields.io/badge/simulation-passing-green) -->
<!-- ![FPGA](https://img.shields.io/badge/FPGA-failing-red) -->


The GPro 3 (Ranger) is the third generation of RISC-V processors designed by
[Gerber Prototyping](https://g-proto.com).  Ranger is planned to add a 5-stage
pipeline to previous generations. This processor planned for the future.

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
