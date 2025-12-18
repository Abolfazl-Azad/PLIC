CC := riscv32-unknown-elf-gcc -march=rv32i_zicsr -mabi=ilp32 -nostartfiles 

all: calculator.out

calculator.out: calculator.o
	$(CC) calculator.o -T ./baseFiles/link.common.ld ./baseFiles/crt0.boot_M.S -o calculator.out

calculator.o: calculator.c
	$(CC) -c calculator.c -o calculator.o


clean:  
	rm calculator.o 

hex: 
	riscv32-unknown-elf-objdump -d calculator.out > calculator.s 
	riscv32-unknown-elf-objdump -d -j .rodata calculator.out >> calculator.s 
	riscv32-unknown-elf-objcopy -O srec calculator.out calculator.srec
	
