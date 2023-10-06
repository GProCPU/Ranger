# Pipeline Control

This section specifies the pipeline control behavior, including hazards detection,
data forwarding, branching, and traps.

A typical 5-stage pipeline is implemented.
1. Fetch
2. Decode
3. Execute
4. Memory/CSR
5. Write Back

![Pipeline\label{pipeline}](./figures/Pipeline.drawio.svg) \
**Figure 1.** Ranger Pipeline

<br>

When analyzing the pipeline, this document uses the term *cycle* to refer to the
number cycles not stalled by other factors such as hazards of other instructions
or memory operation latency.

<br>

## Pipeline Registers

The registers separating each pipeline stage are listed below. Additionally, the
following registers are present between all* stages:
- `bubble` asserted if no valid instruction is being executed
- `pc[XLEN-1:0]` current program counter
- `priv[1:0]` current privilege mode
- `mem_priv[1:0]` *effective* privilege mode for data memory access
- `endianness` *effective* data memory endianness

\* only the `bubble` register is required for the MEM/WB

### IF/ID
- `inst[31:0]` instruction bits

### ID/EX
- `src1[XLEN-1:0]` left side operator
- `src2[XLEN-1:0]` right side operator
- `alt_data[XLEN-1:0]` alternate data for store or CSR write
- `csr_addr[11:0]` address for CSR write
- `dest[4:0]` destination register
- `mem_en` asserted if instruction is load or store
- `csr_wr` asserted if instruction is a CSR write
- `alu_forward[1:0]` data forwarding (see [Data Forwarding](./Control.md#data-forwarding) under Control Unit)
- `load_forward_alu[1:0]` data forwarding (see [Data Forwarding](./Control.md#data-forwarding) under Control Unit)
- `load_forward_mem` data forwarding (see [Data Forwarding](./Control.md#data-forwarding) under Control Unit)

### EX/MEM
- `alu_result[XLEN-1:0]` result from ALU
- `alt_data[XLEN-1:0]` alternate data for store or CSR write
- `csr_addr[11:0]`  address for CSR write
- `dest[4:0]` destination register
- `mem_en` asserted if instruction is a load or store
- `csr_wr` asserted if instruction is a CSR write
- `load_forward_mem` data forwarding (see [Data Forwarding](./Control.md#data-forwarding) under Control Unit)

### MEM/WB
- `dest_data[XLEN-1:0]` result for ALU or load data
- `dest[4:0]` destination register

<br>

## Data Hazards

As this is an in-order pipeline, only read-after-write (RAW) data hazards occur.
Both General Purpose Registers (GPR) and Control and Status Registers (CSR)
support writing and reading to/from the same destination in the same cycle. The
value read is the same as the value written.

### GPR Raw Hazards

0-2 cycle delay

GPR RAW hazards can occur any time a GPR read occurs within 2 cycles of a
matching GPR write. Forwarding is used when possible to increase performance.

The [Hazard Map](./Control.md#hazard-map) contains details about each class of instruction,
including: if one or more GPR read is required, if a GPR write occurs, and
when in the pipeline the GPR read data is actually needed. This map helps to
determine the forwarding logic. See [Data Forwarding](./Control.md#data-forwarding)
under the Control Unit for details.

### CSR RAW Hazards

0-1 cycle delay

CSR RAW hazards can occur any time a *Scratch* CSR read occurs within 1 cycle
of a matching CSR write. Forwarding is NOT used for CSR hazards and the pipeline
always stalls until the *Scratch* CSR write reaches the Mem/CSR stage. The result
is a maximum delay of 1 cycle.

This includes implicit read of trap related Scratch CSR during execution of an
`xRET` instruction. More specifically, `xRET` instructions are stalled for 1 cycle
in the decode stage if immediately preceded by a trap related Scratch CSR write.

*Atomic* CSR RAW hazards do not occur as Atomic CSR writes require the pipeline
to stall until the write is complete
(see [CSR Writes to *Atomic* Register](#csr-writes-to-atomic-registers)).

#### Memory RAW hazards

Memory RAW hazards do not occur as all memory access happens in the Memory stage.
A store after load hazard still exists but is a GPR RAW hazard
(see [GPR RAW Hazards](#gpr-raw-hazards)).

<br>

## Control Hazards

There are several groups of instructions that cause control hazards within the
pipeline.

### Jump `JAL`, `JALR`

1 cycle delay

Jump address is calculated in Decode stage with dedicated adder (`pc`+`imm` or `rs1`+`imm`).
Link address (`pc`+4) is forwarded from the Fetch stage.

### Branch `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`

0-1 cycle delay (0: not taken, 1: taken)

Branch address calculated in Decode stage with dedicated adder (`pc`+`imm`).
Branch condition evaluated in Decode Stage with dedicated logic.

### CSR Writes to *Atomic* Registers

Writes to *Atomic* CSRs can affect the execution environment. Thus, the pipeline
must be flushed until the Atomic CSR write has been committed. This is called an
Atomic CSR flush, and stalls for a total of 3 cycles (the Fetch stage must be
squashed).

### Traps

For the purposes of this pipeline, an `xRET` instruction is treated as a unique
synchronous exceptions.

When a synchronous exception occurs, the stage at which the exception is encountered
and all previous stages are squashed. Traps do not require the pipeline to be
flushed and can be executed speculatively. See [Trap Insertion](./Control.md#trap-insertion)
under Control Unit for details.
