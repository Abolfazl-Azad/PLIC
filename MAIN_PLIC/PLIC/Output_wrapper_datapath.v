`timescale 1ns/1ns

module Output_wrapper_datapth #(
    parameter dataBusOut = 8,
    parameter dataIn = 32
) (
    input clk,
    input rst,
    input [dataIn -1 : 0] intrupt_ID,
    input iniCnt,
    input incCnt,
    input [1:0]initValue,

    output co,
    output [dataBusOut -1 : 0] dataout_Output_wrapper
);


wire [1:0] out_cnt;

wrapper_mux4to1 #(8) muc4to1(
    .i0(intrupt_ID[7 : 0]),
    .i1(intrupt_ID[15 : 8]),
    .i2(intrupt_ID[23 : 16]),
    .i3(intrupt_ID[31 : 24]),
    .sel(out_cnt),
    .dataOut(dataout_Output_wrapper)
);

wrapper_counter #(2) counter(
    .clk(clk),
    .rst(rst),
    .incCnt(incCnt),
    .iniCnt(iniCnt),
    .zero(1'b0),
    .initValue(initValue),
    .dataOut(out_cnt),
    .co(co)
);

    
endmodule