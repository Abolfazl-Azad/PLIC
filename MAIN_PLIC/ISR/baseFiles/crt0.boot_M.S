#define EXCEPTION_STACK_SIZE 72

.section .text
reset_handler:
  /* MSTATUS:0x00001800, MTVEC :0x00000011 */
  addi x1, x0, 0x180  
  slli x1, x1, 4
  csrrw x1, mstatus, x1 
  csrrwi x1, mtvec, 0x11
  
  /* Set all registers to zero */
  mv x1, x0
  mv x2, x1
  /*... Repeat for all other registers ...*/
  mv x31, x1

  /* Stack initialization */
  la x2, _stack_start

.global _start
_start:
  /* Clear BSS */
  la x26, _bss_start
  la x27, _bss_end

  bge x26, x27, zero_loop_end

zero_loop:
  sw x0, 0(x26)
  addi x26, x26, 4
  ble x26, x27, zero_loop
zero_loop_end:

main_entry:
  /* Jump to main program entry point (argc = argv = 0) */
  addi x10, x0, 0
  addi x11, x0, 0
  /* Enable all external interrupt */
  addi x7, x0, 0
  lui x7, 0xffff0
  csrrs x7, mie, x7
  addi x7, x0, 8
  csrrs x7, mstatus, x7
  addi x7, x0, 0

  jal x1, main

_end:
  /* When returning from main, infinite loop here */
  jal x0, _end

// Saves all caller-saved registers (except return address)
store_regs:
  sw x3, 0x00(x2)  // gp
  /*... Repeat for all other caller-saved registers ...*/
  sw x31, 0x40(x2)
  jalr x0, x1

// Load back registers from stack
end_except:
  lw x3, 0x00(x2)
  /*... Repeat for all other caller-saved registers ...*/
  lw x31, 0x40(x2)
  lw x1, 0x44(x2)
  addi x2, x2, EXCEPTION_STACK_SIZE
  mret

/* Exception codes with custom behavior */

/* Instruction Address Misaligned Handler */
instruction_address_misaligned_default_handler:
  j instruction_address_misaligned_handler

/* Illegal Instruction Handler */
illegal_insn_default_handler:
  j illegal_insn_handler

/* Machine Software Interrupt Handler */
machine_software_interrupt_default_handler:
  j machine_software_interrupt_handler

/* Load Address Misaligned Handler */
load_address_misaligned_default_handler:
  j load_address_misaligned_handler

/* Store Address Misaligned Handler */
store_address_misaligned_default_handler:
  j store_address_misaligned_handler

/* Machine Timer Interrupt Handler */
machine_timer_interrupt_default_handler:
  j machine_timer_interrupt_handler

/* Machine External Interrupt Handler */
machine_external_interrupt_default_handler:
  j machine_external_interrupt_handler

/* External Interrupt Signal Handler */
external_interrupt_signal_handler:
  addi x2, x2, -EXCEPTION_STACK_SIZE
  sw x1, 0x44(x2)
  jal x1, store_regs
  // TODO: handle interrupts here
  j end_except

default_exc_handler:  
  j default_exc_handler  // Infinite loop

/* Exception Vectors */
.section .vectors, "ax"
.option norvc

  .org 0x00
  jal x0, reset_handler
  .org 0x04
  jal x0, instruction_address_misaligned_default_handler
  .org 0x08
  jal x0, default_exc_handler
  .org 0x0C
  jal x0, illegal_insn_default_handler
  .org 0x10
  jal x0, default_exc_handler
  .org 0x14
  jal x0, load_address_misaligned_default_handler
  .org 0x18
  jal x0, default_exc_handler
  .org 0x1c
  jal x0, store_address_misaligned_default_handler
  .org 0x20
  jal x0, default_exc_handler 
  .org 0x24
  jal x0, default_exc_handler
  .org 0x28
  jal x0, default_exc_handler     
  .org 0x2c
  jal x0, default_exc_handler
  .org 0x30
  jal x0, default_exc_handler      
  .org 0x34
  jal x0, default_exc_handler 
  .org 0x38
  jal x0, default_exc_handler 
  .org 0x3c
  jal x0, default_exc_handler 
  .org 0x40
  jal x0, default_exc_handler 
  .org 0x44
  jal x0, default_exc_handler 
  .org 0x48
  jal x0, default_exc_handler 
  .org 0x4c
  jal x0, default_exc_handler 
  .org 0x50
  jal x0, default_exc_handler 
  .org 0x54
  jal x0, default_exc_handler 
  .org 0x58
  jal x0, default_exc_handler 
  .org 0x5c
  jal x0, default_exc_handler 
  .org 0x60
  jal x0, default_exc_handler 
  .org 0x64
  jal x0, default_exc_handler 
  .org 0x68
  jal x0, default_exc_handler 
  .org 0x6c
  jal x0, default_exc_handler 
  .org 0x70
  jal x0, default_exc_handler 
  .org 0x74
  jal x0, default_exc_handler 
  .org 0x78
  jal x0, default_exc_handler 
  .org 0x7c
  jal x0, default_exc_handler 
  .org 0x80
  jal x0, default_exc_handler 
  .org 0x84
  jal x0, default_exc_handler 
  .org 0x88
  jal x0, default_exc_handler 
  .org 0x8c
  jal x0, default_exc_handler 
  .org 0x90
  jal x0, machine_software_interrupt_default_handler
  .org 0x94
  jal x0, external_interrupt_signal_handler
  .org 0x98
  jal x0, external_interrupt_signal_handler
  .org 0x9c
  jal x0, external_interrupt_signal_handler
  .org 0xa0
  jal x0, machine_timer_interrupt_default_handler
  .org 0xa4
  jal x0, external_interrupt_signal_handler
  .org 0xa8
  jal x0, external_interrupt_signal_handler
  .org 0xac
  jal x0, external_interrupt_signal_handler
  .org 0xb0
  jal x0, machine_external_interrupt_default_handler
  .org 0xb4
  jal x0, external_interrupt_signal_handler
  .org 0xb8
  jal x0, external_interrupt_signal_handler
  .org 0xbc
  jal x0, external_interrupt_signal_handler
  .org 0xc0
  jal x0, external_interrupt_signal_handler
  .org 0xC4
  jal x0, external_interrupt_signal_handler
  .org 0xC8
  jal x0, external_interrupt_signal_handler
  .org 0xCC
  jal x0, external_interrupt_signal_handler
  .org 0xD0
  jal x0, external_interrupt_signal_handler
  .org 0xD4
  jal x0, external_interrupt_signal_handler
  .org 0xD8
  jal x0, external_interrupt_signal_handler
  .org 0xDC
  jal x0, external_interrupt_signal_handler
  .org 0xE0
  jal x0, external_interrupt_signal_handler
  .org 0xE4
  jal x0, external_interrupt_signal_handler
  .org 0xE8
  jal x0, external_interrupt_signal_handler
  .org 0xEC
  jal x0, external_interrupt_signal_handler
  .org 0xF0
  jal x0, external_interrupt_signal_handler
  .org 0xF4
  jal x0, external_interrupt_signal_handler
  .org 0xF8
  jal x0, external_interrupt_signal_handler
  .org 0xFC
  jal x0, external_interrupt_signal_handler
  .org 0x100
  jal x0, external_interrupt_signal_handler

    