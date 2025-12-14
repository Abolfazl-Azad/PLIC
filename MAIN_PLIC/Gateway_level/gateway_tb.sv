// Testbench for the level_sensitive_gateway module
// Checks the three main scenarios for level-sensitive interrupt handling.
`timescale 1ns / 1ps

module level_sensitive_gateway_tb;

    
    localparam CLOCK_PERIOD = 10; // 10ns clock period

    // Signals
    reg  CLK;
    reg  rst;
    reg  int_sig;
    reg  complete_in;

    wire update_pending;
    wire gateway_out;

    // Instantiate the Device Under Test (DUT)
    level_sensitive_gateway dut (
        .clk(CLK),
        .rst(rst),
        .int_sig(int_sig),
        .complete_in(complete_in),
        .update_pending(update_pending),
        .gateway_out(gateway_out)
    );

    // Clock Generation
    initial begin
        CLK = 0;
        forever #(CLOCK_PERIOD / 2) CLK = ~CLK;
    end

    // Helper task to advance one clock cycle
    task automatic clock_cycle;
        repeat (1) @(posedge CLK);
    endtask

    // Helper task to check and report status
    task automatic check_status (
        input string scenario_name,
        input string check_id,
        input bit expected_gateway_out
    );
        @(posedge CLK);
        #1ps; // Check after a small delay

        if (gateway_out !== expected_gateway_out) begin
            $display("time = %0t    [FAIL] %s: Gateway failed to assert/clear. Expected %b, got %b.", 
                   $time, check_id, expected_gateway_out, gateway_out);
        end else begin
            $display("time = %0t    [PASS] %s: Gateway output matched expected value %b.", 
                     $time, check_id, expected_gateway_out);
        end
    endtask

    // Main Test Sequence
    initial begin
        // Initialize Inputs
        rst         = 1;
        int_sig     = 0;
        complete_in = 0;

        $display("\n--------------------------------------------------------------------------------");
        $display("[TEST START] Performing Reset.");
        
        @(negedge CLK) rst = 0;
        clock_cycle; 
        
        // Ensure initial state is cleared
        check_status("Reset Check", "RST-1", 0);


        // ----------------------------------------------------------------
        // [SCENARIO 1] Basic Level-Sensitive Interrupt Flow
        // ----------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("[SCENARIO 1] Assert Level-Sensitive Interrupt.");
        
        @(negedge CLK) int_sig = 1; // Assert source signal
        
        clock_cycle; 
        check_status("S1-1", "S1-1: Assert", 1); 

        $display("[SCENARIO 1] Source deasserts. gateway_out should remain HIGH.");
        @(negedge CLK) int_sig = 0; // Deassert source signal
        
        clock_cycle; 
        check_status("S1-2", "S1-2: Hold", 1); 

        $display("[SCENARIO 1] Receive Completion. gateway_out should go LOW.");
        @(negedge CLK) complete_in = 1; // Assert completion signal
        
        clock_cycle;
        check_status("S1-3", "S1-3: Clear", 0); 
        
        @(negedge CLK) complete_in = 0; // Deassert completion
        clock_cycle;
        
        // ----------------------------------------------------------------
        // [SCENARIO 2] Completion WHILE Source is Active (Ignored Completion)
        // ----------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("[SCENARIO 2] Completion WHILE Source is Active.");
        
        @(negedge CLK) int_sig = 1; // Assert source
        clock_cycle;
        check_status("S2-1", "S2-1: Assert", 1);
        
        $display("[SCENARIO 2] Assert Completion (Should be ignored). gateway_out must remain HIGH.");
        @(negedge CLK) complete_in = 1; 
        
        clock_cycle; 
        check_status("S2-2", "S2-2: Ignore Comp", 1);
        
        $display("[SCENARIO 2] Source deasserts. gateway_out remains HIGH (waiting for new completion).");
        @(negedge CLK) begin
            int_sig = 0;     
            complete_in = 0; 
        end
        
        clock_cycle;
        check_status("S2-3", "S2-3: Hold after deassert", 1);

        $display("[SCENARIO 2] Send second Completion. gateway_out should go LOW.");
        @(negedge CLK) complete_in = 1; 
        
        clock_cycle; 
        check_status("S2-4", "S2-4: Final Clear", 0);
        
        @(negedge CLK) complete_in = 0;
        clock_cycle;

        // ----------------------------------------------------------------
        // [SCENARIO 3] Assert & Clear in the same cycle (Simultaneous)
        // ----------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("[SCENARIO 3] Assert, then simultaneously Clear Source and Send Completion.");
        
        @(negedge CLK) int_sig = 1; // Assert source
        clock_cycle; 
        check_status("S3-1", "S3-1: Assert", 1);
        
        $display("[SCENARIO 3] int_sig low and completion high simultaneously.");
        // Simultaneous transition in the next half cycle
        @(negedge CLK) begin
            int_sig = 0;     // Source goes low
            complete_in = 1; // Completion goes high
        end
        
        clock_cycle; 
        // Expected: gateway_out clears immediately because int_sig is low when complete_in is high.
        check_status("S3-2", "S3-2: Simultaneous Clear", 0);
        
        @(negedge CLK) complete_in = 0;
        clock_cycle;

        // ----------------------------------------------------------------
        $display("\n--------------------------------------------------------------------------------");
        $display("[TEST END] All Scenarios Tested.");
        $display("--------------------------------------------------------------------------------\n");
        $stop;
    end

endmodule