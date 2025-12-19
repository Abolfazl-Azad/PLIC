module PLIC_WITH_WRAPPER 
(
    input clk,
    input rst,
    input mem_read,
    input mem_write,
    input [31:0] mem_addr,
    input [7:0] mem_data,
    input [30 : 0] int_sig,
    output int_notif,
    output [7:0] int_ID,
    output memReady
);

wire [31:0]int_ID_plic;
wire [31:0]mem_addr_plic;
wire [31:0]mem_data_plic;
wire mem_write_plic;

plic plic 
(
    .clk(clk),
    .rst(rst),
    .mem_read(mem_read),
    .mem_write(mem_write_plic),
    .mem_data(mem_data_plic),
    .mem_addr(mem_addr_plic),
    .int_sig(int_sig),
    .int_notif(int_notif),
    .int_ID(int_ID_plic)
);

Input_wrapper Input_wrapper
(
    .clk(clk),
    .rst(rst),
    .memWrite(mem_write),
    .address_PLIC(mem_addr),
    .dataIn(mem_data),
    .mem_addr(mem_addr_plic),
    .mem_data(mem_data_plic),
    .mem_write(mem_write_plic)
);

Output_wrapper Output_wrapper
(
    .clk(clk),
    .rst(rst),
    .memRead(mem_read),
    .address_PLIC(mem_addr),
    .intrupt_ID(int_ID_plic),
    .dataout_Output_wrapper(int_ID),
    .memReady(memReady)
);

endmodule