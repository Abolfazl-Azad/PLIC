#include "plic.h"

// Global function, not inline
void machine_external_interrupt_handler(void) __attribute__((interrupt("machine")));

void machine_external_interrupt_handler(void)
{
    uint32_t claim = plic_claim();
    if (claim) {
        plic_set_priority(claim, (uint8_t)(0x00000000));
        plic_complete(claim);
    }
}

int main() 
{
    plic_enable_all_sources();
    plic_set_threshold(0);

    // Enable global & external interrupts
    asm volatile("csrs mie, %0" :: "r"(0x00000800));
    asm volatile("csrs mstatus, %0" :: "r"(0x00000008));

    while(1) {
        // CPU waits for interrupts
    }
    return 0;
}




