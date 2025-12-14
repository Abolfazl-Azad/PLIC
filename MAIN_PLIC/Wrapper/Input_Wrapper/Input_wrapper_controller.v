`timescale 1ns/1ns

`define IDLE      2'b00
`define FIRST_INC_CNT 2'b01
`define GET_DATA  2'b10

module Input_wrapper_controller #(parameter ADDR_WIDTH = 32)(
    input clk,
    input rst,
    input co,
    input correct_address,
    input [ADDR_WIDTH - 1 : 0] address_PLIC,
    input memWrite,

    output reg En,
    output [ADDR_WIDTH - 1 : 0] mem_addr,
    output reg iniCnt,
    output reg [2:0] initValue,
    output reg incCnt,
    output reg zero,
    output reg Valid_Data
);

    reg [1:0] p_state, n_state;
    assign mem_addr = address_PLIC;

    always @(posedge clk or posedge rst) begin
        if (rst)
            p_state <= `IDLE;
        else
            p_state <= n_state;
    end

    always @(*) begin
        n_state = `IDLE;

        case (p_state)
            `IDLE: begin
                if (correct_address & memWrite)
                    n_state = `GET_DATA;
                else
                    n_state = `IDLE;
            end

            `FIRST_INC_CNT: begin n_state <= `GET_DATA; end

            `GET_DATA: begin
                if (co)
                    n_state = `IDLE;
                else
                    n_state = `GET_DATA;
            end

            default: n_state = `IDLE;
        endcase
    end

    always @(*) begin
        iniCnt     = 1'b0;
        incCnt     = 1'b0;
        initValue  = 3'b0;
        En         = 1'b0;
        zero       = 1'b0;
        Valid_Data = 1'b0;

        case (p_state)
            `IDLE: begin
                iniCnt = 1'b1;

                if (correct_address & memWrite) 
                begin
                    En = 1'b1;
                end
            end

            `GET_DATA: begin

                if (co) begin
                    En = 1'b0;
                    incCnt = 1'b0;
                    Valid_Data = 1'b1;
                end
                else begin
                    En = 1'b1;
                    incCnt = 1'b1;
                end
            end
        endcase
    end

endmodule
