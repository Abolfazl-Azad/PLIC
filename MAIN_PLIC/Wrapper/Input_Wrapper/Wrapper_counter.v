
`timescale 1ns/1ns

module wrapper_counter #(parameter size = 32) (
    input clk,
    input rst,
    input incCnt,
    input iniCnt,
    input zero,
    input [size-1:0] initValue,
    output reg [size-1:0] dataOut,
    output co
);

    always @(posedge clk, posedge rst) begin
        if(rst)
            dataOut <= {(size){1'b0}};
        else if(zero)
            dataOut <= {(size){1'b0}};
        else if(iniCnt)
            dataOut <= initValue;
        else if(incCnt)
            dataOut <= dataOut + 1;
        else
            dataOut <= dataOut;
    end

    assign co = &{dataOut};

endmodule
