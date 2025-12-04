`timescale 1ns / 1ps

module gateway_tb;

    localparam CLK_PERIOD = 10ns;
    localparam MAX_PENDING_COUNT = 3; 
    logic clk; 
    logic rst; 
    logic gateway_complete_in;
    logic int_sig;
    logic gateway_out;

    integer clk_count = 0;
    
    edge_triggered_gateway #(.MAX_PENDING_COUNT(MAX_PENDING_COUNT)) dut (
        .clk(clk),
        .rst(rst),
        .gateway_complete_in(gateway_complete_in),
        .int_sig(int_sig),
        .gateway_out(gateway_out)
    );

    logic request_in_flight;
    logic [$clog2(MAX_PENDING_COUNT + 1) - 1:0] int_count;

    assign request_in_flight = dut.request_in_flight;
    assign int_count = dut.int_count;


    //---------------------------------------------------------
    initial begin
        clk = 0;
        forever begin
            #(CLK_PERIOD/2) clk = ~clk;
        end
    end
    
    always @(posedge clk) begin
        clk_count++;
    end

    //---------------------------------------------------------
    initial 
    begin
        $display("----------------------------------------------------------------------------------------------------------------------");
        $display("| Time (ns) | CLK | rst | int_sig | complete_in | gateway_out | request_in_flight | int_count | Comment");
        $display("----------------------------------------------------------------------------------------------------------------------");
        $monitor("| %9t | %3b | %3b | %7b | %11b | %11b | %11b | %9d | %s",
                 $time, clk, rst, int_sig, gateway_complete_in, gateway_out, request_in_flight, int_count, " ");
    end


    //---------------------------------------------------------
    initial 
    begin
        rst = 1;
        int_sig = 0;
        gateway_complete_in = 0;
        @(posedge clk);
        $display("\n[TEST START] Performing Reset.");
        rst = 0;
        
        // 4.2. سناریو 1: Single Edge & Completion (حالت IDLE)
        @(posedge clk); 
        $display("\n[SCENARIO 1] Single Edge (PLIC IDLE). Expected: gateway_out=1 (pulse), request_in_flight=1, int_count=0");
        
        // ایجاد لبه صعودی
        #(CLK_PERIOD/2) int_sig = 1; 
        @(posedge clk); // زمان 25000ns
        int_sig = 0; 
        #1ns; // **FIX 1: رفع Race Condition**
        
        // Assertions
        assert(gateway_out == 1) else $error("[FAIL] S1: gateway_out must be 1. (Pulse check)");
        assert(request_in_flight == 1) else $error("[FAIL] S1: request_in_flight must be 1.");
        assert(int_count == 0) else $error("[FAIL] S1: int_count must be 0.");
        
        // انتظار برای پردازش و اتمام پالس
        repeat (3) @(posedge clk); // پالس باید در 35000ns به 0 برگشته باشد.
        
        // تکمیل وقفه
        $display("\n[SCENARIO 1] Interrupt Completion. Expected: gateway_out=0, request_in_flight=0, int_count=0");
        gateway_complete_in = 1;
        @(posedge clk); // زمان 65000ns
        gateway_complete_in = 0; 
        #1ns; // **FIX 2: رفع Race Condition**
        
        // Assertions
        assert(gateway_out == 0) else $error("[FAIL] S1: After completion, gateway_out must be 0.");
        assert(request_in_flight == 0) else $error("[FAIL] S1: After completion, request_in_flight must be 0.");
        assert(int_count == 0) else $error("[FAIL] S1: int_count must be 0.");


        // 4.3. سناریو 2: Burst & Queueing (صف‌بندی)
        @(posedge clk);
        $display("\n[SCENARIO 2] Burst Edges (Queueing). Expected: request_in_flight=1, int_count=3");

        // وقفه اول (ارسال فوری)
        #(CLK_PERIOD/2) int_sig = 1; @(posedge clk); int_sig = 0; #1ns; 
        assert(request_in_flight == 1 && int_count == 0) else $error("[FAIL] S2-1: First edge failed.");
        @(posedge clk);
        
        // وقفه دوم (صف 1)
        #(CLK_PERIOD/2) int_sig = 1; @(posedge clk); int_sig = 0; #1ns; 
        assert(request_in_flight == 1 && int_count == 1) else $error("[FAIL] S2-2: Second edge failed to queue.");
        @(posedge clk);

        // وقفه سوم (صف 2)
        #(CLK_PERIOD/2) int_sig = 1; @(posedge clk); int_sig = 0; #1ns;
        assert(request_in_flight == 1 && int_count == 2) else $error("[FAIL] S2-3: Third edge failed to queue.");
        @(posedge clk);
        
        // وقفه چهارم (صف 3 - MAX_PENDING_COUNT)
        #(CLK_PERIOD/2) int_sig = 1; @(posedge clk); int_sig = 0; #1ns;
        assert(request_in_flight == 1 && int_count == 3) else $error("[FAIL] S2-4: Fourth edge failed to queue (Expected count 3).");
        @(posedge clk);
        
        // 4.4. سناریو 3: Queue Overflow (اشباع صف)
        $display("\n[SCENARIO 3] Queue Overflow. Expected: int_count to remain at 3");
        
        // وقفه پنجم (باید نادیده گرفته شود)
        #(CLK_PERIOD/2) int_sig = 1; @(posedge clk); int_sig = 0; #1ns;
        assert(request_in_flight == 1 && int_count == 3) else $error("[FAIL] S3: Overflow check failed. int_count must be 3.");
        @(posedge clk);


        // 4.5. سناریو 4: Completion with Queue (تخلیه صف)
        $display("\n[SCENARIO 4] Completion with Queue. Expected: gateway_out pulse and int_count decrement");
        
        // Completion 1 (تخلیه صف 3 -> 2)
        gateway_complete_in = 1;
        @(posedge clk);
        gateway_complete_in = 0;
        #1ns; // **FIX 3: رفع Race Condition**
        assert(gateway_out == 1 && int_count == 2) else $error("[FAIL] S4-1: Completion/Dequeue failed.");
        @(posedge clk);

        // Completion 2 (تخلیه صف 2 -> 1)
        gateway_complete_in = 1;
        @(posedge clk);
        gateway_complete_in = 0;
        #1ns;
        assert(gateway_out == 1 && int_count == 1) else $error("[FAIL] S4-2: Completion/Dequeue failed.");
        @(posedge clk);
        
        // Completion 3 (تخلیه صف 1 -> 0)
        gateway_complete_in = 1;
        @(posedge clk);
        gateway_complete_in = 0;
        #1ns;
        assert(gateway_out == 1 && int_count == 0) else $error("[FAIL] S4-3: Completion/Dequeue failed.");
        @(posedge clk);
        
        // Completion 4 (تخلیه صف 0 -> IDLE)
        gateway_complete_in = 1;
        @(posedge clk);
        gateway_complete_in = 0;
        #1ns;
        assert(gateway_out == 0 && request_in_flight == 0) else $error("[FAIL] S4-4: Completion/IDLE failed.");
        @(posedge clk);


        // 4.6. سناریو 5: Simultaneous Edge and Completion
        @(posedge clk);
        $display("\n[SCENARIO 5] Simultaneous Edge and Completion. Expected: gateway_out=1, int_count=0, request_in_flight=1");

        // وقفه اول (ارسال فوری)
        @(posedge clk); int_sig = 1; @(posedge clk); int_sig = 0; #1ns;
        assert(request_in_flight == 1) else $error("[FAIL] S5: Setup failed.");
        @(posedge clk);

        // وقفه دوم و Completion همزمان
        @(posedge clk); int_sig = 1;
        gateway_complete_in = 1;
        @(posedge clk); // زمان 295000ns
        int_sig = 0;
        gateway_complete_in = 0;
        #1ns; // **FIX 4: رفع Race Condition**
        
        // انتظار: وقفه اول تکمیل می‌شود، وقفه دوم بلافاصله ارسال می‌شود.
        assert(gateway_out == 1) else $error("[FAIL] S5: Simultaneous: gateway_out must be 1.");
        assert(request_in_flight == 1) else $error("[FAIL] S5: Simultaneous: request_in_flight must remain 1.");
        assert(int_count == 0) else $error("[FAIL] S5: Simultaneous: int_count must be 0 (dequeued).");
        @(posedge clk);
        
        // Completion نهایی (برای Idle کردن)
        gateway_complete_in = 1;
        @(posedge clk);
        gateway_complete_in = 0;


        // پایان تست
        $display("\n----------------------------------------------------------------------------------------------------------------------");
        $display("[TEST END] All Scenarios Tested. Check output for [FAIL] messages.");
        #100 $finish;
    end
    
endmodule