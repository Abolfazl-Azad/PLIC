`timescale 1ns/1ns

`define IDLE      2'b00
// `define WAIT_FOR_PLIC 2'b01
`define Send_Data 2'b01

module Output_wrapper_controller #(
    parameter address     = 32)
    (
    input clk,
    input rst,
    input mem_Read,
    input co,
    input [address-1 : 0] address_PLIC,

    output reg iniCnt,
    output reg incCnt,
    output reg [address-1 : 0] mem_addr
);
    //===========================
    // PLIC memory map parameters
    //===========================
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

    reg [1:0] p_state, n_state;
    reg correct_address;

    always @(*) 
        begin
            if((address_PLIC == PLIC_CLAIM_COMPLETE_ADDR) ||
                ((address_PLIC >= PLIC_PENDING_START_ADDR) && (address_PLIC <= PLIC_PENDING_END_ADDR)) || 
                (address_PLIC == PLIC_THRESHOLD_ADDR) || 
                ((address_PLIC >= PLIC_PRIORITY_START_ADDR)  && (address_PLIC < PLIC_PRIORITY_END_ADDR)))
        
                correct_address = 1'b1;
            else 
                correct_address = 1'b0;
        end
    
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
                if(mem_Read & correct_address)
                    n_state = `Send_Data;
                else 
                    n_state = `IDLE;          
            end 

            `Send_Data: begin
                if(co) 
                    n_state = `IDLE;          
                else 
                    n_state = `Send_Data;     
            end
            default: n_state = `IDLE;         
        endcase
    end

    always @(*) begin
        {iniCnt, incCnt} = 3'b000;
        case (p_state)
            `IDLE: begin
                    iniCnt = 1'b1;  
            end 

            `Send_Data: begin
                if (co) begin
                    incCnt = 1'b0;
                end else begin
                    incCnt = 1'b1;
                end
            end
        endcase
    end

endmodule