# \# DNG-8

# 

# An 8-bit multi-cycle von Neumann CPU, written from scratch in Verilog.

# Built as an independent project following Dive Into Systems

# 

# Status: in progress. The ALU is complete and verified; the rest of

# the datapath and control unit are being built.

# 

# \## Architecture

# 

# | | |

# |---|---|

# | Data width | 8 bits |

# | Instructions | 16 bits, 16 opcodes |

# | Memory | 256 bytes, shared by program and data (von Neumann) |

# | Registers | 4 general purpose (R0–R3) |

# | Flags | Z (zero), N (negative), C (carry/borrow) |

# | Execution | 4 cycles per instruction: fetch, decode, execute, writeback |

# | Target | Basys 3 (Artix-7 xc7a35t), Vivado 2025.2 |

# 

# \## Progress

# 

# | Module | Status | Verification |

# |---|---|---|

# | ALU (`alu.v`) | Done | `alu\_tb`: 278 tests, 0 failures |

# | Register file | In progress | |

# | Memory | Not started | |

# | Control unit | Not started | |

# | CPU top level | Not started | |

# 

# \## Running the tests

# 

# In Vivado: add `alu.v` as a design source and `alu\_tb.v` as a

# simulation source, set `alu\_tb` as top, and run behavioral simulation.

# Results print to the Tcl Console.

# 

# \## About

# 

# All Verilog in this repo is my own. The purpose of this project is to learn. 



# Architecture reference: \[Dive Into Systems, Chapter 5](https://diveintosystems.org/book/C5-Arch/index.html)

