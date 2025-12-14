`timescale 1ns/1ns

module Output_wrapper #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_IN_WIDTH = 32,
    parameter DATA_OUT_WIDTH = 8
) (
    input clk,
    input rst,
    input memRead,
    input [ADDR_WIDTH-1:0] address_PLIC,
    input [DATA_IN_WIDTH-1:0] intrupt_ID,

    output [ADDR_WIDTH-1:0] mem_addr,
    output [DATA_OUT_WIDTH-1 : 0] dataout_Output_wrapper
);

wire iniCnt;
wire incCnt;
wire co;


Output_wrapper_datapth datapath (
    .clk(clk),
    .rst(rst),
    .intrupt_ID(intrupt_ID),
    .iniCnt(iniCnt),
    .incCnt(incCnt),
    .initValue(2'b0),
    .co(co),
    .dataout_Output_wrapper(dataout_Output_wrapper)
);

Output_wrapper_controller controller (
    .clk(clk),
    .rst(rst),
    .mem_Read(memRead),
    .address_PLIC(address_PLIC),
    .co(co),
    .iniCnt(iniCnt),
    .incCnt(incCnt),
    .mem_addr(mem_addr)
);
    
endmodule