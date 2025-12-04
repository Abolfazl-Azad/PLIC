`timescale 1ns / 1ps


module plic_tb ();

    localparam NUM_SOURCES                   = 31;
    localparam NUM_WORDS                    = (NUM_SOURCES + 31) / 32; 
    localparam PRIORITY_INDEX_WIDTH         = $clog2 (NUM_SOURCES + 1);    //0 is reserved
    localparam ENABLE_INDEX_WIDTH           = $clog2 (NUM_WORDS);

    localparam PLIC_BASE_ADDR               = 32'h20000000;
    localparam PLIC_PRIORITY_START_ADDR     = PLIC_BASE_ADDR + 32'h00000004;
    localparam PLIC_PRIORITY_STRIDE         = 32'h00000004;
    localparam PLIC_PRIORITY_END_ADDR       = PLIC_PRIORITY_START_ADDR + (NUM_SOURCES * PLIC_PRIORITY_STRIDE);
    localparam PLIC_PENDING_START_ADDR      = PLIC_BASE_ADDR + 32'h00001000;
    localparam PLIC_PENDING_END_ADDR        = PLIC_BASE_ADDR + 32'h0000107C;
    localparam PLIC_ENABLE_START_ADDR       = PLIC_BASE_ADDR + 32'h00002000;
    localparam PLIC_ENABLE_END_ADDR         = PLIC_BASE_ADDR + 32'h0000207F;
    localparam PLIC_THRESHOLD_ADDR          = PLIC_BASE_ADDR + 32'h00200000;
    localparam PLIC_CLAIM_COMPLETE_ADDR     = PLIC_BASE_ADDR + 32'h00200004;


    reg [31:0] mem_addr, mem_data;
    reg mem_read, mem_write, clk, rst;
    reg [NUM_SOURCES - 1 : 0] int_sig;
    wire int_notif;
    wire [31:0] int_ID;

    plic uut (
        .mem_addr(mem_addr),
        .mem_data(mem_data),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .clk(clk),
        .rst(rst),
        .int_sig(int_sig),
        .int_notif(int_notif),
        .int_ID(int_ID)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;   // 100 MHz clock

    // -------------------------------------------------------------------------
    task write_reg(input [31:0] addr, input [31:0] data);
    begin
        @(posedge clk);
        mem_addr  = addr;
        mem_data  = data;
        mem_write = 1;
        mem_read  = 0;
        @(posedge clk);
        mem_write = 0;
    end
    endtask

    // -------------------------------------------------------------------------
    task configure_plic;
        integer i;
        reg [31:0] addr;
    begin
        // Set all priorities
        for (i = 1; i <= NUM_SOURCES; i = i + 1) begin
            addr = PLIC_PRIORITY_START_ADDR + (i - 1) * 4;
            write_reg(addr, i);
        end

        // Enable all interrupts
        for (i = 0; i < NUM_WORDS; i = i + 1) begin
            addr = PLIC_ENABLE_START_ADDR + (i * 4);
            write_reg(addr, 32'hFFFFFFFF);
        end

        // Set threshold
        write_reg(PLIC_THRESHOLD_ADDR, 32'd0);
    end
    endtask

    // -------------------------------------------------------------------------
    task display_config;
        integer i;
    begin
        $display("\n================== PLIC CONFIGURATION ==================");
        $display("Threshold: %0d", uut.threshold);

        $display("\nPriorities:");
        for (i = 0; i <= NUM_SOURCES; i = i + 1)
            $display("  int_priority[%0d] = %0d", i, uut.int_priority[i]);

        $display("\nEnable Bits:");
        for (i = 0; i < NUM_WORDS; i = i + 1)
            $display("  enable_bits[%0d] = %h", i, uut.enable_bits[i]);
    end
    endtask
    //---------------------------------------------------------------

    task claim;
        begin
            mem_addr  = PLIC_CLAIM_COMPLETE_ADDR;
            mem_read  = 1'b1;
           @(posedge clk);                   // wait for one clock cycle (adjust as needed)
            mem_read  = 1'b0;
            mem_addr  = 32'd0;
        end
    endtask

    // ---------------------------------------------------------------
    task complete(input [31:0] complete_id);
        begin
        mem_addr  = PLIC_CLAIM_COMPLETE_ADDR;
        mem_data  = complete_id;
        mem_write = 1'b1;
        @(posedge clk);                    // wait for one clock cycle
        mem_write = 1'b0;
        mem_addr  = 32'd0;
        end
    endtask

    //-----------------------------------------------------------------
    task set_priority(input [31:0] source_id, input [31:0] prio);
    begin
        mem_addr  = PLIC_PRIORITY_START_ADDR + ((source_id - 1) << 2);
        mem_data  = prio;
        mem_write = 1'b1;
        @(posedge clk);
        mem_write = 1'b0;
        mem_addr  = 32'd0;
    end
    endtask
    //----------------------------------------------------------------
    task test_priority_change;
        begin
        $display("\n==================  change priorities test ==================");

        int_sig = 31'b0000000000000000000000000000000; 
        #20;
        int_sig = 31'b1100000000000000000000000000000; 
        #10;
        $display("Source 31 , 30 with priorities 31 , 30, asserted interrupt request");
        set_priority(31, 10);
        $display("Priority of source 31 changed to 10");
        repeat (2) @(posedge clk);  

        claim();
        @(posedge clk);

        if (int_ID == 32'd30)
            $display("  *** time = %0t\n  PASS: Correctly claimed source 30 after priority change\n", $time);
        else
            $display("  *** time = %0t\n  FAIL: Claimed %0d instead of 30\n",$time, int_ID);

        @(posedge clk);
        complete(int_ID);
        @(posedge clk);
        set_priority(31, 31);
        @(posedge clk);
        end
    endtask

    //----------------------------------------------------------------
    task same_priorities;
    begin
        $display("\n================== test same priorities ==================");
        set_priority(31, 30);
        $display("Source number 31, 30, have same priority values (30).");
        int_sig = 31'b0000000000000000000000000000000; 
        #20;
        int_sig = 31'b1100000000000000000000000000000; 
        #20;
        $display("Source 31 , 30 asserted interrupt requests.");
        claim();
        @(posedge clk);

        if (int_ID == 32'd30)
            $display("  *** time : %0t\n  PASS: Correctly claimed source 30", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claimed %0d instead of 30", $time, int_ID);
        claim();
        @(posedge clk);

        if (int_ID == 32'd31)
            $display("  *** time : %0t\n  PASS: Correctly claimed source 31", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claimed %0d instead of 31", $time, int_ID);
        set_priority(31, 31);
    end
    endtask

    //----------------------------------------------------------------

    task simultaneous_req_complete;
    begin
        $display("\n================== test simultaneous request and complete to the gateway ==================");

        int_sig = 31'b0000000000000000000000000000000; 
        #20;
        int_sig = 31'b1100000000000000000000000000000; //source 31,30
        #20;
        claim();
        @(posedge clk);
        $display("Source 31 asserted interrupt request and cpu marked it as claimed");
        int_sig = 31'b0000000000000000000000000000000; 
        #20;
        int_sig = 31'b1100000000000000000000000000000;
        complete(32'b00000000000000000000000000011111);
        #20;
        $display("new interrupt request from source 31 and complete signal for it's previous request asserted simultaneously");
        claim();        
        $display("cpu claimed. ");
        @(posedge clk);

        if (int_ID == 32'd31)
            $display("  *** time : %0t\n  PASS: Correctly claimed source 31", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claimed %0d instead of 31", $time, int_ID);
        
    end
    endtask

    //----------------------------------------------------------------
    task set_threshold(input [31:0] threshold_value);
        begin
            mem_addr  = PLIC_THRESHOLD_ADDR;
            mem_data  = threshold_value;
            mem_write = 1'b1;
            @(posedge clk);
            mem_write = 1'b0;
            mem_addr  = 32'd0;
        end
    endtask

    //----------------------------------------------------------------

    //----------------------------------------------------------------
        task test_threshold_enable;
        begin
        integer i;
        reg [31:0] addr;
        $display("\n================== threshold & enable test ==================");

        int_sig = 31'b0000000000000000000000000000000;
        #20;

        set_threshold(10);
        $display("Threshold set to 10 (higher than source 5 priority which is 5)");

        int_sig[5] = 1'b1;
        #20;

        claim();
        @(posedge clk);
        if (int_ID == 32'd0)
            $display("  *** time : %0t\n  PASS: Threshold correctly blocked interrupt 5", $time);
        else
            $display("  *** time : %0t\n  FAIL: Interrupt 5 incorrectly claimed with high threshold", $time);


        set_threshold(0);
        $display("Threshold lowered to 0");

        @(posedge clk);
        for (i = 0; i < NUM_WORDS; i = i + 1) begin
            addr = PLIC_ENABLE_START_ADDR + (i * 4);
            write_reg(addr, 32'd0);
        end
        $display("All sources are disabled");

        int_sig = 31'b0000000000000000000000000000000;
        #10;
        int_sig[5] = 1'b1;
        #20;

       
        claim();
        @(posedge clk);
        if (int_ID == 32'd0)
            $display("  *** time : %0t\n  PASS: Disabled source 5 correctly not claimable", $time);
        else
            $display("  *** time : %0t\n  FAIL: Disabled source 5 was still claimed!", $time);

         @(posedge clk);
        for (i = 0; i < NUM_WORDS; i = i + 1) begin
            addr = PLIC_ENABLE_START_ADDR + (i * 4);
            write_reg(addr, 32'hFFFFFFFF);
        end
        repeat (2) @(posedge clk);
        claim();
        @(posedge clk);
        complete(int_ID);
        @(posedge clk);

        end
    endtask

    // ----------------------------------------------------------------
    task test_sequence;
        begin
        $display("\n================== simple test sequence ==================");
        int_sig = 31'b0000000000000000000000000000000; 
        #10;  // wait a bit
        // Set int_sig: only sources 32 and 31
        int_sig = 31'b1100000000000000000000000000000; 
        #10;  // wait a bit
        
        $display("Source 31, 30 asserted interrupt request.");
        $display("First claim:");
        // First claim-complete cycle
        claim();
        @(posedge clk); 
        if (int_ID == 32'd31)
            $display("  *** time : %0t\n  PASS: Correctly claimed source 31", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claimed %0d instead of 31", $time, int_ID);
        repeat (2) @(posedge clk);
        complete(int_ID);
        @(posedge clk);  
        // Second claim-complete cycle
        $display("Second claim:");
        claim();
        @(posedge clk); 
        if (int_ID == 32'd30)
            $display("  *** time : %0t\n  PASS: Correctly claimed source 30", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claimed %0d instead of 30", $time, int_ID);
        repeat (2) @(posedge clk);
        complete(int_ID);
        repeat (4) @(posedge clk);
        end
    endtask

    //--------------------------------------------------------------------------
    task check_complete_validity;
    begin
        integer i;
        reg [31:0] addr;
        $display("\n================== check complete validity test ==================");
        int_sig = 31'b0000000000000000000000000000000; 
        #20;
        int_sig = 31'b1100000000000000000000000000000; 
        #20; 
        claim();
        @(posedge clk); 
        $display("Source 31 , 30 asserted interrupt requests.");
        $display("Claimed %0d ",  int_ID);
        
        complete(32'd0);         //ID = 0 isn’t written to the claim-complete register
        @(posedge clk);
        if(uut.claim_complete != 0)
            $display("  *** time : %0t\n  PASS: The invalid complete ID = 0 has not been written to the claim/complete register.", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claim/complete register content : %0d instead of 30", $time, uut.claim_complete);  

        complete (32'b0000000000000000000000000000011);  //ID = 3 isn’t written to the claim-complete register because it is not claimed
        @(posedge clk);
        if(uut.claim_complete != 32'b0000000000000000000000000000011)
            $display("  *** time : %0t\n  PASS: The invalid complete ID = 3 (unclaimed) has not been written to the claim/complete register.", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claim/complete register content : %0d instead of 30", $time, uut.claim_complete);

        for (i = 0; i < NUM_WORDS; i = i + 1) begin
            addr = PLIC_ENABLE_START_ADDR + (i * 4);
            write_reg(addr, 32'd0);
        end
        @(posedge clk);
        $display("All sources disabled.");

        complete (32'b0000000000000000000000000011111);  //ID = 30 which is claimed, isn’t written to the claim-complete register because of being disabled
        @(posedge clk);
        if(uut.claim_complete != 32'b0000000000000000000000000011111)
            $display("  *** time : %0t\n  PASS: The invalid complete ID = 31 (claimed but disabled) has not been written to the claim/complete register.", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claim/complete register content : %0d instead of 30", $time, uut.claim_complete);

        for (i = 0; i < NUM_WORDS; i = i + 1)   //enable all again
        begin
            addr = PLIC_ENABLE_START_ADDR + (i * 4);
            write_reg(addr, 32'hFFFFFFFF);
        end
        @(posedge clk);
        $display("All sources enabled.");

        complete(32'b00000000000000000000000000011111);
        @(posedge clk);
                if(uut.claim_complete == 32'b0000000000000000000000000011111)
            $display("  *** time : %0t\n  PASS: Valid complete ID = 31 has been written to the claim/complete register.", $time);
        else
            $display("  *** time : %0t\n  FAIL: Claim/complete register content : %0d instead of 31", $time, uut.claim_complete);
    end
    endtask

    // -------------------------------------------------------------------------
    initial begin
        // Initialization
        mem_addr = 0;
        mem_data = 0;
        mem_read = 0;
        mem_write = 0;
        int_sig = 0;
        rst = 1;

        // Reset
        repeat (5) @(posedge clk);
        rst = 0;

        // Configure PLIC
        configure_plic();
        repeat (5) @(posedge clk);
        display_config();

        test_threshold_enable();
        test_sequence();
        check_complete_validity();
        test_priority_change();


        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        configure_plic();
        repeat (5) @(posedge clk);
        same_priorities();
        rst = 1;
        repeat (5) @(posedge clk);
        rst = 0;
        configure_plic();
        repeat (5) @(posedge clk);
        simultaneous_req_complete();

        // Done
        #250 $stop;
    end

endmodule
