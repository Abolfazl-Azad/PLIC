`timescale 1ns/1ns

module Input_wrapper_datapath #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_IN_WIDTH = 8,
    parameter DATA_OUT_WIDTH = 32
)(
    input clk,
    input rst,
    input memWrite,

    input [ADDR_WIDTH-1:0]          address_PLIC,
    input [DATA_IN_WIDTH-1:0]       dataIn,

    input                           iniCnt,
    input                           incCnt,
    input [2:0]                     initValue,
    input                           En,
    input                           zero,

    output                          co,
    output wire[DATA_OUT_WIDTH-1:0] dataout_Input_wrapper,
    output reg                      correct_address
);

    localparam NUM_SOURCES                  = 32;
    localparam NUM_WORDS                    = (NUM_SOURCES + 31) / 32;
    localparam PRIORITY_INDEX_WIDTH         = $clog2 (NUM_SOURCES + 1);
    localparam ENABLE_INDEX_WIDTH           = $clog2 (NUM_WORDS);
    localparam NUM_EXTENSION                = (NUM_SOURCES + 1) % 32;

    localparam PLIC_BASE_ADDR               = 32'h20000000;
    localparam PLIC_PRIORITY_START_ADDR     = PLIC_BASE_ADDR + 32'h00000004;
    localparam PLIC_PRIORITY_STRIDE         = 32'h00000004;
    localparam PLIC_PRIORITY_END_ADDR       = 
    PLIC_PRIORITY_START_ADDR + (NUM_SOURCES * PLIC_PRIORITY_STRIDE);
    localparam PLIC_PENDING_START_ADDR      = PLIC_BASE_ADDR + 32'h00001000;
    localparam PLIC_PENDING_END_ADDR        = PLIC_BASE_ADDR + 32'h0000107C;
    localparam PLIC_ENABLE_START_ADDR       = PLIC_BASE_ADDR + 32'h00002000;
    localparam PLIC_ENABLE_END_ADDR         = PLIC_BASE_ADDR + 32'h0000207F;
    localparam PLIC_THRESHOLD_ADDR          = PLIC_BASE_ADDR + 32'h00200000;
    localparam PLIC_CLAIM_COMPLETE_ADDR     = PLIC_BASE_ADDR + 32'h00200004;

    wire [2:0] out_cnt;
    wire En_datapath;
    assign En_datapath = (correct_address && memWrite)  || En;
 

    Wrapper_shift_register #(.IN_WIDTH(8),.OUT_WIDTH(32)) shift_reg
    (
        .clk(clk),
        .rst(rst),
        .load(En_datapath),
        .data_in(dataIn),
        .data_out(dataout_Input_wrapper)
    );

    wrapper_counter #(3) counter (
        .clk(clk),
        .rst(rst),
        .incCnt(incCnt),
        .iniCnt(iniCnt),
        .initValue(3'b100),
        .dataOut(out_cnt),
        .co(co),
        .zero(zero)
    );

    always @(*) begin
        if ( ((address_PLIC >= PLIC_PRIORITY_START_ADDR) && (address_PLIC <  PLIC_PRIORITY_END_ADDR))||
            ((address_PLIC >= PLIC_ENABLE_START_ADDR) && (address_PLIC <= PLIC_ENABLE_END_ADDR)) ||
            (address_PLIC == PLIC_THRESHOLD_ADDR) || (address_PLIC == PLIC_CLAIM_COMPLETE_ADDR))
        begin
            correct_address = 1'b1;
        end
        else
            correct_address = 1'b0;
    end

endmodule

