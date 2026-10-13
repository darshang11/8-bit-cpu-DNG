# DNG-8

An 8-bit multi-cycle von Neumann CPU, designed and written from scratch in Verilog.

**Status:** in progress. Every module is written and the full CPU is wired together in `cpu.v`. Next up is a full-system testbench that runs a real program, then the Basys 3.

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

### Datapath

`cpu.v` holds the registers that carry an instruction through its four cycles:

| Register | Holds |
|---|---|
| PC | Address of the next instruction. Moves +2 every fetch |
| IR | The current instruction, loaded once in fetch |
| A, B | The two ALU operands, read from the register file in decode |
| ALUOut | The ALU result, saved in execute and written back in writeback |
| Z, N, C | Flags saved by ALU instructions and CMP, read by conditional jumps |

`control.v` is a 4-state FSM (plus a halt state) that drives 11 control signals: the write enables for each of these registers, the ALU operation, the writeback mux select, the memory write enable and the PC source.

## Instruction format

Every instruction is 16 bits, stored high byte first.

| Bits | Field | Used for |
|---|---|---|
| `[15:12]` | opcode | Which instruction |
| `[11:10]` | rd | Destination register. Also the source for `ST` and the condition for jumps |
| `[9:8]` | rs | First source register |
| `[7:6]` | rt | Second source register |
| `[7:0]` | imm | Immediate (`LDI`), memory address (`LD`, `ST`) or jump target |

`rt` and `imm` overlap. The opcode decides which one applies.

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

Conditional jumps pick their condition with the rd field: `00` JZ, `01` JNZ, `10` JN, `11` JC. Only the ALU instructions and `CMP` change the flags. `MOV` doesn't.

## Progress

- [x] ALU: 8 operations with zero, negative, and carry flags
- [x] Register file: 4 × 8-bit registers, three read ports, clocked write with enable
- [x] Memory: 256 bytes shared by program and data, separate instruction and data ports, clocked write with enable
- [x] Control unit: fetch, decode, execute, writeback FSM driving every control signal
- [x] Top-level CPU integration (`cpu.v`)
- [ ] Test program: sum 1 through 10, store 55 to memory
- [ ] Full verification suite
- [ ] Synthesis and Basys 3 deployment

## Verification

Every module has a self-checking testbench that prints each failure and a final PASS/FAIL line.

| Module | Testbench | Result |
|---|---|---|
| ALU | `alu_tb.v`: 22 directed cases covering every operation and flag, plus an exhaustive ADD sweep | 278 / 278 pass |
| Register file | `regfile_tb.v`: one test per specified behavior: reset, write targeting, 8-bit storage, isolation, write enable, independent read ports, write timing, reset priority | 26 / 26 pass |
| Memory | `memory_tb.v`: startup clear of all 256 bytes, instruction byte order, FF wraparound, write timing, write enable, isolation, edge addresses, independent ports, data writes visible to instruction fetch | 272 / 272 pass |
| Control unit | `control_tb.v`: every opcode through all four states, each jump condition taken and not taken, HLT holding without reloading the IR, reset held, mid-instruction and out of halt | 114 / 114 pass |

## Running the tests

**Vivado:** add the module and its testbench (for example `regfile.v` and `regfile_tb.v`), set the testbench as the simulation top, and run behavioral simulation. Results print in the Tcl Console.

## Files

| File | Description |
|---|---|
| `alu.v` | Arithmetic logic unit |
| `alu_tb.v` | Self-checking ALU testbench |
| `regfile.v` | Register file |
| `regfile_tb.v` | Self-checking register file testbench |
| `memory.v` | 256-byte unified memory |
| `memory_tb.v` | Self-checking memory testbench |
| `control.v` | Control unit FSM |
| `control_tb.v` | Self-checking control unit testbench |
| `cpu.v` | Top level: datapath registers, writeback mux, and all four modules wired together |

## What I learned

Picturing the whole CPU before it existed was the hardest part. The ALU, register file and memory were easy to reason about on their own. The control unit only makes sense next to a datapath, and the datapath didn't exist yet. What got me through it was realizing `control.v` is just another standalone module: it reads an opcode and three flags, drives eleven control signals, and has no idea a datapath exists. So I could build and test it alone, then wire everything together in `cpu.v`. Stepping one `ADD` through fetch, decode, execute and writeback, cycle by cycle, is what made the loop click. Control drives the datapath, and the datapath feeds the opcode and flags back to control.

Test every piece alone before wiring them together. Each module has a self-checking testbench that compares against expected values and prints PASS or FAIL, so I never had to eyeball waveforms to know something worked. A few habits mattered: checking on the falling edge so checks don't race the clock, using `!==` so an X counts as a failure instead of silently passing, and testing ugly cases like pulling reset in the middle of an instruction. That way a bug at the top level can't hide in a module I already trust.

`reg` doesn't mean flip-flop. I had blocking and nonblocking assignments backwards at first. What fixed it was learning that the always block decides what you get, not the type. Anything assigned in `always @(posedge clk)` becomes a flip-flop and uses `<=`. Anything in `always @(*)` is plain logic and uses `=`. Every combinational block here either sets defaults first or ends in a default case, so no path leaves a signal unassigned and nothing infers a latch.

Every register in a multi-cycle CPU is there for a reason. I first thought the PC held the instruction. It holds the address. The IR holds the instruction because the PC moves on right after fetch and memory gets used again later in the same instruction. A and B aren't needed for correctness at all. They split "read registers" and "run the ALU" into separate cycles, which shortens the longest path so the clock can run faster.

## How I used AI

I think AI is going to be a normal part of RTL work, so I want to be clear about how I used it here. I used Claude as a tutor and a TA. I wrote every line of Verilog in this repo myself, every module and every testbench, in Vivado 2025.2.

I set that rule early. When I started, Claude handed me a finished ALU, and I told it to stop and act as a guide instead. From then on it wrote specs and answered questions, and I wrote the code. I wanted to be able to explain and debug every line, and I can't do that with code I didn't write.

What I used it for:

- **Learning Verilog.** It explained concepts in plain terms, then quizzed me until I could explain them back.
- **Seeing the design.** It broke the control unit down one state at a time when I couldn't picture how the pieces connected.
- **Testbench edge cases.** It came up with cases I couldn't, like reset in the middle of an instruction or the IR reloading while halted. I picked which ones to test and wrote the checks.
- **Code review.** It pointed out problems in what I wrote and explained the rule behind each one instead of fixing the line for me.
- **Documentation.** It helped me write this README.

I treated it like a TA. It answered my questions and thought of edge cases I couldn't, but my testbenches decided whether something actually worked.

## References

- [Dive Into Systems, Chapter 5](https://diveintosystems.org/book/C5-Arch/index.html): the von Neumann architecture and fetch, decode, execute, writeback model this design follows
