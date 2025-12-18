#include <stdint.h>

#define SIZE 3
#define SYSTEM_CORE_CLK 3570000 // Hz

const char operatorMsg[] = "Enter an operator (+(1), -(2), *(3), /(4), %(5)): \n";
const char operandsMsg[] = "Enter two operands: \n";
const char divBy0[] = "Error! Division by zero is not allowed.\n";
const char wrongOperator[] = "Error! Operator is not correct.\n";
const char space = ' ';
const char plus = '+';
const char minus = '-';
const char mult = '*';
const char div = '/';
const char rem = '%';
const char eq = '=';
const char newline = '\n';

uint8_t rx_flag = 0;
uint32_t systick_cnt = 0;
#define USART_BAUD_RATE_REG1_ADDR ((uint8_t *)(0x1A10FFD8))
#define USART_BAUD_RATE_REG2_ADDR ((uint8_t *)(0x1A10FFD9))
#define USART_BAUD_RATE_REG3_ADDR ((uint8_t *)(0x1A10FFDA))
#define USART_BAUD_RATE_REG4_ADDR ((uint8_t *)(0x1A10FFDB))
#define USART_RX_DATA_REG_ADDR ((uint8_t *)(0x1A10FFDC))
#define USART_CONFIGURATION_REG_ADDR ((uint8_t *)(0x1A10FFE4))
#define USART_TX_DATA_REG_ADDR ((uint8_t *)(0x1A10FFE0))

void usart_init(uint32_t baud_rate)
{
  *USART_BAUD_RATE_REG1_ADDR = (uint8_t)((baud_rate >> 0) & 0xFF);
  *USART_BAUD_RATE_REG2_ADDR = (uint8_t)((baud_rate >> 8) & 0xFF);
  *USART_BAUD_RATE_REG3_ADDR = (uint8_t)((baud_rate >> 16) & 0xFF);
  *USART_BAUD_RATE_REG4_ADDR = (uint8_t)((baud_rate >> 24) & 0xFF);

  *USART_CONFIGURATION_REG_ADDR = 0b00000001; // reset
  *USART_CONFIGURATION_REG_ADDR = 0b00001100; // Rx Interrupt
}

void wait_until_send(void)
{
    while (1)
    {
        uint8_t conf_reg = *USART_CONFIGURATION_REG_ADDR;
        conf_reg >>= 6;
        conf_reg &= 0x01;
        if (conf_reg == 1)
            break;
    }
}

void usart_send_data(uint8_t val)
{
    *USART_TX_DATA_REG_ADDR = val;
    *USART_CONFIGURATION_REG_ADDR = 0b00011100; 
}

uint8_t str_len(const char* arr)
{
    uint8_t len = 0;
    while(arr[len] != '\0')
        len++;
    return len;
}

void print(const char* arr)
{
    uint8_t len = str_len(arr);
    for (uint8_t i = 0; i < len; i++) {
        usart_send_data(arr[i]);
        wait_until_send();
    }
}

void print2(uint8_t arr)
{
    usart_send_data(arr);
    wait_until_send();
}

void scan(uint8_t *in) {
    *USART_CONFIGURATION_REG_ADDR = 0b00000100; // Rx Interrupt
    while (rx_flag == 0) {}
    rx_flag = 0;
    *in = *USART_RX_DATA_REG_ADDR;
}

void print_digits(uint8_t number) {
    uint8_t divisor = 1;
    while (number / divisor >= 10) {
        divisor *= 10;
    }

    while (divisor > 0) {
        uint8_t digit = number / divisor;
        digit = digit + 0x30;
        print2(digit);
        number %= divisor;
        divisor /= 10;
    }
}

int main() {
    // Enable machine timer/software/external interrupt in the mie register
    asm volatile("csrs mie, %0" :: "r"(0x00000888));
    // Enable global interrupts in the mstatus register
    asm volatile("csrs mstatus, %0" :: "r"(0x00000008));
    usart_init(372);
    uint8_t operator;
    uint8_t first, second;
    uint8_t reslut;
    
    while (1) {
        print(operatorMsg);
        scan(&operator);
        
        print(operandsMsg);
        scan(&first);
        scan(&second);
        
        switch (operator) {
            case 1:
                reslut = first + second;
                print_digits(first);
                print2(space);
                print2(plus);
                print2(space);
                print_digits(second);
                print2(space);
                print2(eq);
                print2(space);
                print_digits(reslut);
                print2(newline);
                break;
            case 2:
                reslut = first - second;
                print_digits(first);
                print2(space);
                print2(minus);
                print2(space);
                print_digits(second);
                print2(space);
                print2(eq);
                print2(space);
                print_digits(reslut);
                print2(newline);
                break;
            case 3:
                reslut = first * second;
                print_digits(first);
                print2(space);
                print2(mult);
                print2(space);
                print_digits(second);
                print2(space);
                print2(eq);
                print2(space);
                print_digits(reslut);
                print2(newline);
                break;
            case 4:
                if (second != 0) {
                    reslut = first / second;
                    print_digits(first);
                    print2(space);
                    print2(div);
                    print2(space);
                    print_digits(second);
                    print2(space);
                    print2(eq);
                    print2(space);
                    print_digits(reslut);
                    print2(newline);
                } else {
                    print(divBy0);
                }
                break;
            case 5:
                if ((int)second != 0) {
                    reslut = first % second;
                    print_digits(first);
                    print2(space);
                    print2(rem);
                    print2(space);
                    print_digits(second);
                    print2(space);
                    print2(eq);
                    print2(space);
                    print_digits(reslut);
                    print2(newline);
                } else {
                    print(divBy0);
                }
                break;
            default:
                print(wrongOperator);
                break;
        }
    }
    
    return 0;
}

void machine_software_interrupt_handler(void) __attribute__((interrupt("machine")));
void machine_software_interrupt_handler()
{
    uint8_t reg = *USART_CONFIGURATION_REG_ADDR;
    reg &= 0b01111011;
    *USART_CONFIGURATION_REG_ADDR = reg;
    rx_flag = 1;
}

void machine_external_interrupt_handler()
{

}

void instruction_address_misaligned_handler()
{

}

void illegal_insn_handler()
{

}

void load_address_misaligned_handler()
{

}

void store_address_misaligned_handler()
{

}

void default_exc_handler()
{

}

void machine_timer_interrupt_handler()
{

}

void external_interrupt_signal_handler()
{

}