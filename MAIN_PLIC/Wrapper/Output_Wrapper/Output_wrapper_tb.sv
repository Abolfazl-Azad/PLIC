`timescale 1ns/1ns

module Output_wrapper_SV_tb;

    // Parameters (تعریف پارامترها)
    parameter ADDR_WIDTH     = 32;
    parameter DATA_IN_WIDTH  = 32;
    parameter DATA_OUT_WIDTH = 8;
    
    // Test Control Variables (متغیرهای کنترل تست)
    integer passed_tests = 0;
    integer failed_tests = 0;

    // PLIC Address Constants (برگرفته از کنترلر)
    localparam PLIC_BASE_ADDR           = 32'h20000000;
    localparam PLIC_CLAIM_COMPLETE_ADDR = 32'h20200004;
    localparam PLIC_PENDING_START_ADDR  = 32'h20001000;
    localparam PLIC_PENDING_END_ADDR    = 32'h2000107C;
    localparam PLIC_THRESHOLD_ADDR      = 32'h20200000;
    localparam PLIC_PRIORITY_START_ADDR = 32'h20000004;
    // بر اساس NUM_SOURCES=32
    localparam PLIC_PRIORITY_END_ADDR   = 32'h20000084; 

    // DUT Signals (سیگنال‌های DUT)
    reg  clk;
    reg  rst;
    reg  mem_Read;
    reg  [ADDR_WIDTH-1:0] address_PLIC;
    reg  [DATA_IN_WIDTH-1:0] intrupt_ID;

    wire mem_read;
    wire [ADDR_WIDTH-1:0]mem_addr;
    wire [DATA_OUT_WIDTH-1:0] dataout_Output_wrapper;

    // Clock Generation (تولید کلاک)
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Cycle time = 10ns
    end

    // Instance of the DUT (نمونه‌سازی ماژول مورد تست)
    Output_wrapper #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_IN_WIDTH(DATA_IN_WIDTH),
        .DATA_OUT_WIDTH(DATA_OUT_WIDTH)
    ) DUT (
        .clk(clk),
        .rst(rst),
        .memRead(mem_Read),
        .address_PLIC(address_PLIC),
        .intrupt_ID(intrupt_ID),
        .mem_addr(mem_addr),
        .dataout_Output_wrapper(dataout_Output_wrapper)
    );

    // ==========================================================
    // Tasks for Test Simplification (تعریف تسک‌ها)
    // ==========================================================

    task automatic reset_dut;
        $display("----------------------------------------");
        $display("   Task: Resetting DUT");
        rst = 1;
        mem_Read = 0;
        address_PLIC = 0;
        intrupt_ID = 0;
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        $display("   Reset complete.");
    endtask: reset_dut

    // Task for a full 4-byte read cycle
    task automatic run_read_cycle (input string test_name, 
                                   input [ADDR_WIDTH-1:0] addr, 
                                   input [DATA_IN_WIDTH-1:0] data_in,
                                   input [DATA_OUT_WIDTH-1:0] expected_bytes [0:3]);
        
        reg test_status = 1; // 1 = PASS, 0 = FAIL
        $display("----------------------------------------");
        $display("Starting Test: %0s (Address: %h, Data: %h)", test_name, addr, data_in);

        // 1. Setup Phase
        address_PLIC = addr;
        intrupt_ID = data_in;
        mem_Read = 1;
        
        // 2. Cycle 1: mem_Read=1, FSM: IDLE -> WAIT_FOR_PLIC
        @(posedge clk);
        #1; // **************** اصلاح: جلوگیری از Race Condition ****************
        mem_Read = 0; 
        
        // چک کردن سیگنال‌ها در فاز پایدار بعد از کلاک
        if (mem_addr !== addr) begin
            $error("ERROR [%0s]: mem_addr is incorrect after Cycle 1. Expected %h, Got %h", test_name, addr, mem_addr);
            test_status = 0;
        end
        if (mem_read !== 1'b1) begin
             $error("ERROR [%0s]: mem_read did not activate after Cycle 1 (State: WAIT_FOR_PLIC).", test_name);
             test_status = 0;
        end

        // 3. Cycles 2-5: 4-byte Data Transfer (State: Send_Data)
        for (int i = 0; i < 4; i++) begin
            @(posedge clk);
            #1; // **************** اصلاح: خواندن خروجی ترکیبی پایدار ****************
            if (dataout_Output_wrapper !== expected_bytes[i]) begin
                $error("ERROR [%0s]: Data mismatch on byte %0d. Expected %h, Got %h", test_name, i, expected_bytes[i], dataout_Output_wrapper);
                test_status = 0;
            end else begin
                $display("PASS [%0s]: Byte %0d output correct: %h", test_name, i, dataout_Output_wrapper);
            end
        end

        // 4. Verification of IDLE state return
        @(posedge clk);
        // Allow one extra cycle for FSM to settle in IDLE

        if (mem_read !== 1'b0) begin
            $error("ERROR [%0s]: mem_read failed to de-assert after transfer.", test_name);
            test_status = 0;
        end
        
        // Final Reporting for the task
        if (test_status) begin
            $display("Test PASSED: %0s", test_name);
            passed_tests++;
        end else begin
            $display("Test FAILED: %0s", test_name);
            failed_tests++;
        end
        
    endtask: run_read_cycle

    // Task to verify no action happens on invalid address
    task automatic test_invalid_address(input string test_name, 
                                        input [ADDR_WIDTH-1:0] addr);
        reg test_status = 1;
        $display("----------------------------------------");
        $display("Starting Invalid Address Test: %0s (Address: %h)", test_name, addr);

        // 1. Setup Phase
        address_PLIC = addr;
        mem_Read = 1;

        // 2. Check FSM behavior after two cycles
        @(posedge clk);
        // Cycle 1
        @(posedge clk);
        // Cycle 2

        if (mem_read !== 1'b0) begin
            $error("ERROR [%0s]: mem_read activated on invalid address. Expected 0, Got %b.", test_name, mem_read);
            test_status = 0;
        end
        if (mem_addr !== addr) begin
            // mem_addr همیشه آدرس ورودی است، اما mem_read باید صفر بماند.
            $display("INFO [%0s]: mem_addr is set, but mem_read is correctly inactive.", test_name);
        end
        
        mem_Read = 0;
        // De-assert for next test
        
        // Final Reporting for the task
        if (test_status) begin
            $display("Test PASSED: %0s", test_name);
            passed_tests++;
        end else begin
            $display("Test FAILED: %0s", test_name);
            failed_tests++;
        end

    endtask: test_invalid_address

    // ==========================================================
    // Main Test Sequence (دنباله اصلی تست)
    // ==========================================================

    initial begin
        
        // Declaration of local variables (تعریف متغیرهای محلی قبل از اولین دستور)
        logic data_change_status;

        // Initial Reset
        reset_dut;

        // ------------------------------------------------------
        // 1. Invalid Address Tests (تست آدرس‌های نامعتبر)
        // ------------------------------------------------------
        
        // An address outside the entire PLIC range
        test_invalid_address("Invalid_1_Out_of_Range", 32'h00000000);
        // An address between PLIC sections 
        test_invalid_address("Invalid_2_Mid_Range", 32'h20000100);
        // An address just outside the valid range
        test_invalid_address("Invalid_3_Boundary_High", PLIC_PRIORITY_END_ADDR);
        // PLIC_BASE_ADDR فقط برای رجیسترهای reserved است و در شرط آدرس‌های معتبر نیست.
        test_invalid_address("Invalid_4_Boundary_Low", PLIC_BASE_ADDR);

        // ------------------------------------------------------
        // 2. Valid Address Tests (تست انتقال کامل)
        // ------------------------------------------------------

        // Test Case 2a: PLIC_CLAIM_COMPLETE_ADDR (آدرس بسیار رایج)
        run_read_cycle("Valid_1_Claim_Complete", 
                       PLIC_CLAIM_COMPLETE_ADDR, 
                       32'hA1B2C3D4, 
                       {8'hD4, 8'hC3, 8'hB2, 8'hA1});

        // Test Case 2b: PLIC_PENDING_START_ADDR (آدرس مرزی)
        run_read_cycle("Valid_2_Pending_Start", 
                       PLIC_PENDING_START_ADDR, 
                       32'h11223344, 
                       {8'h44, 8'h33, 8'h22, 8'h11});

        // Test Case 2c: PLIC_PRIORITY_ADDR (آدرس داخلی)
        run_read_cycle("Valid_3_Priority_Mid", 
                       PLIC_PRIORITY_START_ADDR + 32'h20, // Example: Priority for source 8
                       32'hFF00FF00, 
                       {8'h00, 8'hFF, 8'h00, 8'hFF});

        // Test Case 2d: PLIC_THRESHOLD_ADDR (آدرس رایج)
        run_read_cycle("Valid_4_Threshold", 
                       PLIC_THRESHOLD_ADDR, 
                       32'h08070605, 
                       {8'h05, 8'h06, 8'h07, 8'h08});

        // ------------------------------------------------------
        // 3. Re-trigger Test (خواندن پشت سر هم)
        // ------------------------------------------------------
        
        $display("----------------------------------------");
        $display("Starting Re-trigger Test: (4 bytes then another 4 bytes)");
        
        // انتقال اول 
        run_read_cycle("Re-Trigger_A_First", 
                       PLIC_CLAIM_COMPLETE_ADDR, 
                       32'hAAAAFFFF, 
                       {8'hFF, 8'hFF, 8'hAA, 8'hAA});

        // انتقال دوم بلافاصله پس از تکمیل انتقال اول
        run_read_cycle("Re-Trigger_B_Second", 
                       PLIC_CLAIM_COMPLETE_ADDR, 
                       32'h55555555, 
                       {8'h55, 8'h55, 8'h55, 8'h55});

        // ------------------------------------------------------
        // 4. Data Change During Transfer Test (تغییر داده حین انتقال)
        // ------------------------------------------------------
        
        $display("----------------------------------------");
        $display("Starting Data Change Test (Data changes after 2nd byte is read)");
        
        address_PLIC = PLIC_CLAIM_COMPLETE_ADDR;
        mem_Read = 1;
        intrupt_ID = 32'h11223344;
        // داده اولیه: 44, 33, 22, 11 (از LSB به MSB)
        data_change_status = 1;

        @(posedge clk); // Cycle 1: IDLE -> WAIT_FOR_PLIC
        #1;             // **************** اصلاح: جلوگیری از Race Condition ****************
        mem_Read = 0;
        
        @(posedge clk); // Cycle 2: Read Byte 0 (44)
        #1;             // **************** اصلاح: خواندن خروجی ترکیبی پایدار ****************
        if (dataout_Output_wrapper !== 8'h44) data_change_status = 0;

        @(posedge clk); // Cycle 3: Read Byte 1 (33)
        #1;             // **************** اصلاح: خواندن خروجی ترکیبی پایدار ****************
        if (dataout_Output_wrapper !== 8'h33) data_change_status = 0;

        // **Data Change here**
        intrupt_ID = 32'hAABBCCDD;
        // داده جدید: DD, CC, BB, AA (از LSB به MSB)
        
        @(posedge clk); // Cycle 4: Read Byte 2. انتظار: بایت 2 از داده جدید (BB)
        #1;             // **************** اصلاح: خواندن خروجی ترکیبی پایدار ****************
        if (dataout_Output_wrapper !== 8'hBB) begin 
            $error("ERROR [Data_Change]: Expected byte 2 from NEW data (BB), Got %h", dataout_Output_wrapper);
            data_change_status = 0;
        end
        
        @(posedge clk); // Cycle 5: Read Byte 3. انتظار: بایت 3 از داده جدید (AA)
        #1;             // **************** اصلاح: خواندن خروجی ترکیبی پایدار ****************
        if (dataout_Output_wrapper !== 8'hAA) begin
            $error("ERROR [Data_Change]: Expected byte 3 from NEW data (AA), Got %h", dataout_Output_wrapper);
            data_change_status = 0;
        end
        
        if (data_change_status) begin
            $display("Test PASSED: Data_Change_Test (DUT correctly reflects immediate data change)");
            passed_tests++;
        end else begin
            $display("Test FAILED: Data_Change_Test");
            failed_tests++;
        end
        
        @(posedge clk); // Settle

        // ------------------------------------------------------
        // Final Summary (خلاصه نهایی)
        // ------------------------------------------------------
        
        $display("========================================");
        if (failed_tests == 0) begin
            $display("✅ All %0d tests PASSED successfully!", passed_tests);
        end else begin
            $error("❌ %0d tests FAILED. %0d tests PASSED.", failed_tests, passed_tests);
        end
        $display("========================================");
        
        $finish;
    end

endmodule: Output_wrapper_SV_tb