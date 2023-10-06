#ifndef __RANGER_H
#define __RANGER_H

#ifdef __cplusplus
extern "C" {
#endif


// Standard libraries
#include <stdint.h>
#include <inttypes.h>
#include <limits.h>
#include <unistd.h>
#include <stdlib.h>


// I/O and peripherals
#include "csr.h"
#include "trap.h"
#include "time.h"
#include "gpio.h"


// Endianness
#define MSTATUSH_MBE        5
inline uint32_t get_endianness() { return 0b1 & (csrr(CSR_MSTATUSH) >> MSTATUSH_MBE); }
inline void set_big_endian() { asm volatile inline ("csrsi mstatush, 0x20"); }
inline void set_little_endian() { asm volatile inline ("csrci mstatush, 0x20"); }

// Memory Fence
inline void fence() { asm volatile inline ("fence"); }
inline void fence_i() { asm volatile inline ("fence.i"); }

// System Instructions
inline void ecall() { asm volatile inline ("ecall"); }
inline void ebreak() { asm volatile inline ("ebreak"); }
inline void wfi() { asm volatile inline ("wfi"); }


#ifdef __cplusplus
}
#endif

#endif //__RANGER_H