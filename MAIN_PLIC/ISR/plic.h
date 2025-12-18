#ifndef PLIC_H
#define PLIC_H

#include <stdint.h>

// ---------------------------
// Base address and ranges
// ---------------------------
#define PLIC_BASE_ADDR               0x20000000UL

#define PLIC_PRIORITY_START_ADDR     (PLIC_BASE_ADDR + 0x00000004)
#define PLIC_PRIORITY_STRIDE         0x4
#define PLIC_PRIORITY_END_ADDR       (PLIC_PRIORITY_START_ADDR + (32 * PLIC_PRIORITY_STRIDE))  // NUM_SOURCES=32

#define PLIC_PENDING_START_ADDR      (PLIC_BASE_ADDR + 0x00001000)
#define PLIC_PENDING_END_ADDR        (PLIC_BASE_ADDR + 0x0000107C)

#define PLIC_ENABLE_START_ADDR       (PLIC_BASE_ADDR + 0x00002000)
#define PLIC_ENABLE_END_ADDR         (PLIC_ENABLE_START_ADDR + 0x7F)

#define PLIC_THRESHOLD_ADDR          (PLIC_BASE_ADDR + 0x00200000)
#define PLIC_CLAIM_COMPLETE_ADDR     (PLIC_BASE_ADDR + 0x00200004)

// ---------------------------
// Register access macros
// ---------------------------

// Priority registers: each source has 32-bit priority
#define PLIC_PRIORITY_REG(i)  (*(volatile uint32_t *)(PLIC_PRIORITY_START_ADDR + ((i) * PLIC_PRIORITY_STRIDE)))

// Enable registers: 1 word enables 32 sources
#define PLIC_ENABLE_REG(i)    (*(volatile uint32_t *)(PLIC_ENABLE_START_ADDR + ((i) * 4)))

// Threshold register
#define PLIC_THRESHOLD_REG    (*(volatile uint32_t *)(PLIC_THRESHOLD_ADDR))

// Claim/complete register
#define PLIC_CLAIM_COMPLETE_REG (*(volatile uint32_t *)(PLIC_CLAIM_COMPLETE_ADDR))

// ---------------------------
// Helper functions (optional)
// ---------------------------

// Enable a source in enable register (external interrupts)
static inline void plic_enable_source(uint32_t source_id)
{
    uint32_t word_index = source_id / 32;
    uint32_t bit_index  = source_id % 32;
    PLIC_ENABLE_REG(word_index) |= (1U << bit_index);
}

// Set priority for a source (1..7 valid)
static inline void plic_set_priority(uint32_t source_id, uint32_t priority)
{
    PLIC_PRIORITY_REG(source_id) = priority;
}

// Set threshold
static inline void plic_set_threshold(uint32_t threshold)
{
    PLIC_THRESHOLD_REG = threshold;
}

// Claim an interrupt
static inline uint32_t plic_claim(void)
{
    return PLIC_CLAIM_COMPLETE_REG;
}

// Complete an interrupt
static inline void plic_complete(uint32_t claim)
{
    PLIC_CLAIM_COMPLETE_REG = claim;
}

// ---------------------------
// Enable all sources and assign priorities 1..31
// ---------------------------
static inline void plic_enable_all_sources(void)
{
    for (uint32_t i = 0; i < 31; i++)  // sources 0..30
    {
        plic_enable_source(i);
        plic_set_priority(i, i + 1);  // priority 1..31
    }
}


#endif // PLIC_H
