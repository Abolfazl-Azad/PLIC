`timescale 1ns/1ns

module Input_wrapper #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_IN_WIDTH = 8,
    parameter DATA_OUT_WIDTH = 32
)(
    input clk,
    input rst,

    input memWrite,
    input [ADDR_WIDTH-1:0] address_PLIC,
    input [DATA_IN_WIDTH-1:0] dataIn,

    output [ADDR_WIDTH-1:0] mem_addr,
    output [DATA_OUT_WIDTH-1:0] mem_data,
    output mem_write
);

    wire En;
    wire iniCnt;
    wire [2:0] initValue;
    wire incCnt;
    wire zero;
    wire correct_address;
    wire co;

    Input_wrapper_controller controller (
        .clk(clk),
        .rst(rst),
        .co(co),
        .correct_address(correct_address),
        .address_PLIC(address_PLIC),
        .memWrite(memWrite),
        .En(En),
        .iniCnt(iniCnt),
        .initValue(initValue),
        .incCnt(incCnt),
        .zero(zero),
        .Valid_Data(mem_write),
        .mem_addr(mem_addr)
    );

    Input_wrapper_datapath datapath (
        .clk(clk),
        .rst(rst),
        .memWrite(memWrite),
        .address_PLIC(address_PLIC),
        .dataIn(dataIn),
        .iniCnt(iniCnt),
        .incCnt(incCnt),
        .initValue(initValue),
        .En(En),
        .zero(zero),
        .co(co),
        .dataout_Input_wrapper(mem_data),
        .correct_address(correct_address)
    );

endmodule
