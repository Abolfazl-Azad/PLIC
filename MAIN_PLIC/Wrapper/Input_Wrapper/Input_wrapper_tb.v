`timescale 1ns/1ns

module wrapper_tb();

    reg clk;
    reg rst;
    reg memWrite;
    reg [31:0] address_PLIC;
    reg [7:0] dataIn;

    wire [31:0] mem_data;
    wire mem_write;
    wire [31:0] mem_addr;

    Input_wrapper DUT (
        .clk(clk),
        .rst(rst),
        .memWrite(memWrite),
        .address_PLIC(address_PLIC),
        .dataIn(dataIn),
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_write(mem_write)
    );

    initial clk = 0;
    always #10 clk = ~clk;

    initial begin
        $dumpfile("Input_wrapper_TB.vcd");
        $dumpvars(0, wrapper_tb);

        rst = 1;
        memWrite = 0;
        address_PLIC = 32'h0;
        dataIn = 8'h00;
        #50;
        rst = 0;

        // تست آدرس اشتباه (نباید چیزی بنویسه)
        address_PLIC = 32'h10000000;
        memWrite = 1;
        dataIn = 8'hAA;
        #40;
        memWrite = 0;
        #40;

        // تست آدرس معتبر PLIC
        address_PLIC = 32'h20000004;
        memWrite = 1;

        dataIn = 8'h11; #20;
        dataIn = 8'h22; #20;
        dataIn = 8'h33; #20;
        dataIn = 8'h44; #20;

        memWrite = 0;
        #100;

        $display("Final Output = %h", mem_data);
        $stop;
    end

endmodule

