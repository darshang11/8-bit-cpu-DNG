# DNG-8

An 8-bit multi-cycle von Neumann CPU, designed and written from scratch in Verilog.

**Status:** in progress. The ALU is complete and verified; the register file is next.

## Architecture

| Spec | Value |
|---|---|
| Data width | 8 bits |
| Instructions | 16 bits, 16 opcodes |
| Memory | 256 bytes, shared by program and data (von Neumann) |
| Registers | 4 general purpose (R0–R3) |
| Flags | Z (zero), N (negative), C (carry/borrow) |
| Execution | 4 cycles per instruction: fetch, decode, execute, writeback |
| Target | Basys 3 (Artix-7 xc7a35t), Vivado 2025.2 |

## Instruction set

| Opcode | Instruction | Operation |
|---|---|---|
| `0x0` | `NOP` | Do nothing |
| `0x1` | `LDI rd, imm` | rd ← imm |
| `0x2` | `LD rd, addr` | rd ← MEM[addr] |
| `0x3` | `ST rd, addr` | MEM[addr] ← rd |
| `0x4` | `MOV rd, rs` | rd ← rs |
| `0x5` | `ADD rd, rs, rt` | rd ← rs + rt |
| `0x6` | `SUB rd, rs, rt` | rd ← rs − rt |
| `0x7` | `AND rd, rs, rt` | rd ← rs & rt |
| `0x8` | `OR rd, rs, rt` | rd ← rs \| rt |
| `0x9` | `XOR rd, rs, rt` | rd ← rs ^ rt |
| `0xA` | `SHL rd, rs` | rd ← rs << 1 |
| `0xB` | `SHR rd, rs` | rd ← rs >> 1 |
| `0xC` | `CMP rs, rt` | Set flags from rs − rt |
| `0xD` | `JMP addr` | PC ← addr |
| `0xE` | `JZ / JNZ / JN / JC addr` | PC ← addr if the condition holds |
| `0xF` | `HLT` | Stop |

## Progress

- [x] ALU: 8 operations with zero, negative, and carry flags
- [ ] Register file
- [ ] Memory
- [ ] Control unit
- [ ] Top-level CPU integration
- [ ] Test program: sum 1 through 10, store 55 to memory
- [ ] Full verification suite
- [ ] Synthesis and Basys 3 deployment

## Verification

| Module | Testbench | Result |
|---|---|---|
| ALU | `alu_tb.v`: 22 directed cases covering every operation and flag, plus an exhaustive ADD sweep | 278 / 278 pass |

## Running the tests

**Vivado:** add `alu.v` and `alu_tb.v`, set `alu_tb` as the simulation top, and run behavioral simulation. Results print in the Tcl Console.

## Files

| File | Description |
|---|---|
| `alu.v` | Arithmetic logic unit |
| `alu_tb.v` | Self-checking ALU testbench |

## References

- [Dive Into Systems, Chapter 5](https://diveintosystems.org/book/C5-Arch/index.html): the architecture this design follows

## How this was built

All Verilog in this repository is written by me using Vivado 2025.2.
