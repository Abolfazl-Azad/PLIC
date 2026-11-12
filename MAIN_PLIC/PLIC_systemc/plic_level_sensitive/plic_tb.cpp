#include "plic_tb.h"
#include <iostream>

using namespace sc_core;
using namespace sc_dt;


    // Clock Generator
void plic_tb::clk_gen() 
{
    clk.write(SC_LOGIC_0);
    while (true) 
    {
        wait(5, SC_NS);
        clk.write(clk.read().to_bool() ? SC_LOGIC_0 : SC_LOGIC_1);
    }
}
//------------------------------------------------------------------------
void plic_tb::wait_cycles(int n) {
    for (int i = 0; i < n; i++)
        wait(10, SC_NS); // assuming 10ns clock period
}
//------------------------------------------------------------------------
// Simulate a claim operation
void plic_tb::claim_cycle() {
    memAddr.write(PLIC_CLAIM_COMPLETE_ADDR);
    memread.write(SC_LOGIC_1);
    wait_cycles(1);
    memread.write(SC_LOGIC_0);
    memAddr.write(0);
}
//----------------------------------------------------------------------
// Simulate a complete operation
void plic_tb::complete_cycle(sc_lv<32> id_value) {
    memAddr.write(PLIC_CLAIM_COMPLETE_ADDR);
    mem_data.write(id_value);
    memwrite.write(SC_LOGIC_1);
    wait_cycles(2);
    memwrite.write(SC_LOGIC_0);
    memAddr.write(0);
}

//----------------------------------------------------------------------
void plic_tb::scenario_overlap_interrupts() {
    std::cout << "\n--- Scenario: Overlapping Interrupts ---" << std::endl;

    // Step 1: Interrupt 1 comes
    std::cout << sc_time_stamp() << " Interrupt 1 arrives (source 32)" << std::endl;
    int_req.write(0b10000000000000000000000000000000); // e.g. source 32
    wait_cycles(3);

    // Step 2: Claim
    claim_cycle();

    // Step 3: Before complete, another interrupt arrives
    std::cout << sc_time_stamp() << " Interrupt 2 arrives before complete (source 31, 30)" << std::endl;
    int_req.write(0b01100000000000000000000000000000); // source 31, 30
    wait_cycles(2);

    // Step 4: Complete first
    std::cout << sc_time_stamp() << " First complete" << std::endl;
    complete_cycle(0b00000000000000000000000000100000);
    wait_cycles(2);

    // Step 5: Claim again for the new interrupt
    claim_cycle();

    // Step 6: Complete again
    std::cout << sc_time_stamp() << " Second complete" << std::endl;
    int_req.write (0b00100000000000000000000000000000);
    complete_cycle(0b00000000000000000000000000011111);


    cout << sc_time_stamp() <<" gateway out is "<<dut->gateway_out.read()<<endl;
    cout << sc_time_stamp() <<" claim complete is "<<dut->claim_complete.to_uint()<<endl;

    int_req.write(0); // Clear all requests
    wait_cycles(4);

    std::cout << "\n--- End of overlap Scenario ---\n" << std::endl;
}
//------------------------------------------------------------------------
void plic_tb::scenario_masked_threshold() {
    std::cout << "\n--- Scenario: Masked Interrupt and higher threshold---" << std::endl;

    // Clear all
    int_req.write(0b00000000000000000000000000000000); 
    wait_cycles(2);

    // Enable all sources except source 32 (mask it)
    memAddr.write(PLIC_ENABLE_ADDR);
    mem_data.write(0x7FFFFFFF); 
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    

    //  Raise masked interrupt (source 1)
    int_req.write(0b10000000000000000000000000000000); //  source 32
    wait_cycles(2);

    // Check: int_notif should remain 0
    if (dut->int_notif.read() == SC_LOGIC_0) {
        std::cout << sc_time_stamp() << ": PASS - Masked interrupt did NOT trigger notification." << std::endl;
    } else {
        std::cout << sc_time_stamp() << ": FAIL - Masked interrupt incorrectly triggered notification!" << std::endl;
    }

    // Enable all sources 
    memAddr.write(PLIC_ENABLE_ADDR);
    mem_data.write(0xFFFFFFFF); 
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    //  Set threshold = 32
    memAddr.write(PLIC_THRESHOLD_ADDR);
    mem_data.write(0b00000000000000000000000000100000);
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    // Check: int_notif should remain 0
    if (dut->int_notif.read() == SC_LOGIC_0) {
        std::cout << sc_time_stamp() << ": PASS - Interrupt with Lower priority than threshold did not trigger notification." << std::endl;
    } else {
        std::cout << sc_time_stamp() << ": FAIL - Interrupt with Lower priority than threshold incorrectly triggered notification!" << std::endl;
    }

    // Clear all
    int_req.write(0b00000000000000000000000000000000); 
    wait_cycles(2);

    std::cout << "--- Scenario Complete ---\n" << std::endl;
}
//------------------------------------------------------------------------
void plic_tb::scenario_same_priority() {
    std::cout << "\n--- Scenario: Same Priority Tie ---" << std::endl;

    // Configure priorities: source 32 = 32, source 31 = 32
    memAddr.write(PLIC_PRIORITY_START_ADDR + 31 * PLIC_PRIORITY_STRIDE); // source 32
    mem_data.write(32);
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    memAddr.write(PLIC_PRIORITY_START_ADDR + 30 * PLIC_PRIORITY_STRIDE); // source 31
    mem_data.write(32);
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    //  Raise both interrupts (sources 31 and 32)
    int_req.write(0b11000000000000000000000000000000); // MSB=source32, next MSB=source31
    wait_cycles(2);

    // First claim
    claim_cycle();

    unsigned int id = dut->int_ID.read().to_uint();
    if (id == 31)
    {
        std::cout << sc_time_stamp() << ": PASS - First ID = 31 (source with lower id)" << std::endl;
    }else
    {
        std::cout << sc_time_stamp() << ": FAIL - First ID expected 31, got :  " << id << std::endl;
    }

    // first complete
    int_req.write(0b10000000000000000000000000000000); 
    complete_cycle(0b00000000000000000000000000011111);
    wait_cycles(1);

    // Second claim 
    claim_cycle();

    id = dut->int_ID.read().to_uint();
    if (id == 32)
    {
        std::cout << sc_time_stamp() << ": PASS - Second ID = 32 (source with higher id)" << std::endl;
    }else
    {
        std::cout << sc_time_stamp() << ": FAIL - Second ID expected 32, got :  " << id << std::endl;
    }

    // second complete
    int_req.write(0b00000000000000000000000000000000); 
    complete_cycle(0b00000000000000000000000000100000);

    // Clear all
    int_req.write(0);
    wait_cycles(5);

    std::cout << "--- Scenario Complete ---\n" << std::endl;
}
//-----------------------------------------------------------------------
void plic_tb::scenario_no_pending_interrupt() {
    std::cout << "\n--- Scenario: No Pending Interrupt ---" << std::endl;

    //  Ensure no interrupt requests
    int_req.write(0);
    wait_cycles(2);

    //  Perform claim
    claim_cycle();

    //  Check ID
    unsigned int id = dut->int_ID.read().to_uint();
    if (id == 0) {
        std::cout << sc_time_stamp() << ": PASS - No pending interrupt, ID = 0" << std::endl;
    } else {
        std::cout << sc_time_stamp() << ": FAIL - Expected ID = 0, got " << id << std::endl;
    }

    std::cout << "--- Scenario Complete ---\n" << std::endl;
}
//------------------------------------------------------------------------
void plic_tb::scenario_simultaneous_req_complete() {
    std::cout << "\n--- Scenario: simultaneous request and complete to the gateway ---" << std::endl;

    //  Ensure no interrupt requests
    int_req.write(0);
    wait_cycles(2);

    int_req.write(0b11100000000000000000000000000000);
    wait_cycles(2);
    claim_cycle();
    int_req.write(0b01100000000000000000000000000000);
    wait_cycles(2);
    int_req.write(0b11100000000000000000000000000000);
    complete_cycle(0b00000000000000000000000000100000);
    claim_cycle();

    //  Check ID
    unsigned int id = dut->int_ID.read().to_uint();
    if (id == 32) {
        std::cout << sc_time_stamp() << ": PASS - got the new req" << std::endl;
    } else {
        std::cout << sc_time_stamp() << ": FAIL - Expected ID = 32, got " << id << std::endl;
    }

    std::cout << "--- Scenario Complete ---\n" << std::endl;
}
//------------------------------------------------------------------------
void plic_tb::scenario_dynamic_priority_default() {
    std::cout << "\n--- Scenario: Dynamic Priority Change Before Claim (Default Priorities) ---" << std::endl;

    // Ensure no other interrupts
    int_req.write(0);
    wait_cycles(2);

    // Raise interrupts for sources 32, 31, 30
    int_req.write(0b11100000000000000000000000000000);
    wait_cycles(2);

    // Before claim, change priority of source 32 to 10
    memAddr.write(PLIC_PRIORITY_START_ADDR + 31 * PLIC_PRIORITY_STRIDE); // source 32
    mem_data.write(10);
    memwrite.write(SC_LOGIC_1); wait_cycles(1); memwrite.write(SC_LOGIC_0); wait_cycles(1);

    //  Claim cycle
    claim_cycle();

    // Check claimed ID
    unsigned int id = dut->int_ID.read().to_uint();
    if (id == 31) {
        std::cout << sc_time_stamp() << ": PASS - Interrupt ID with higher priority  = 31" << std::endl;
    } else {
        std::cout << sc_time_stamp() << ": FAIL - Expected ID = 31, got " << id << std::endl;
    }

    // Clear all
    int_req.write(0);
    wait_cycles(5);

    std::cout << "--- Scenario Complete ---\n" << std::endl;
}

//------------------------------------------------------------------------
void plic_tb::config_scenario() {
    std::cout << "\n--- Starting Configuration Scenario ---" << std::endl;

    // Initialize signals
    rst.write(SC_LOGIC_0);
    memread.write(SC_LOGIC_0);
    memwrite.write(SC_LOGIC_0);
    memAddr.write(0);
    int_req.write(0);
    wait_cycles(5);

    // Reset everything first
    rst.write(SC_LOGIC_1);
    wait_cycles(2);
    rst.write(SC_LOGIC_0);
    wait_cycles(2);

    // 1. Write all priorities (1 to 32)
    for (int i = 0; i < PLIC_NUM_SOURCES; i++) {
        sc_uint<32> addr = PLIC_PRIORITY_START_ADDR + i * PLIC_PRIORITY_STRIDE;
        memAddr.write(addr);
        mem_data.write(i + 1);        // priority = i+1
        memwrite.write(SC_LOGIC_1);
        wait_cycles(1);
        memwrite.write(SC_LOGIC_0);
        wait_cycles(1);
    }

    // 2. Write enable register (all 1’s)
    memAddr.write(PLIC_ENABLE_ADDR);
    mem_data.write(0xFFFFFFFF); // all sources enabled
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    // 3. Write threshold = 0
    memAddr.write(PLIC_THRESHOLD_ADDR);
    mem_data.write(0);
    memwrite.write(SC_LOGIC_1);
    wait_cycles(1);
    memwrite.write(SC_LOGIC_0);
    wait_cycles(1);

    // Return to idle state
    memAddr.write(0);
    mem_data.write(0);
    memread.write(SC_LOGIC_0);
    memwrite.write(SC_LOGIC_0);

    std::cout << "--- Configuration Done ---\n" << std::endl;
}
//--------------------------------------------------------------

//test scenario
void plic_tb::test_scenario() {
    std::cout << "\n--- Starting PLIC Test Scenario ---\n" << std::endl;

    config_scenario();
    dut -> debug();
    scenario_no_pending_interrupt();
    scenario_masked_threshold();
    config_scenario();
    scenario_dynamic_priority_default(); 
    config_scenario();
    scenario_same_priority();
    config_scenario();
    scenario_overlap_interrupts();
    config_scenario();
    scenario_simultaneous_req_complete();


    std::cout << "\n--- Finished. ---" << std::endl;
}


// --- sc_main ---
int sc_main(int argc, char* argv[])
{

    // Instantiate testbench
    plic_tb  *tb = new plic_tb("plic_tb");

    // Create VCD file
    sc_trace_file* tf = sc_create_vcd_trace_file("plic_tb_trace");

    // Trace signals
    sc_trace(tf, tb->clk, "clk");
    sc_trace(tf, tb->rst, "rst");
    sc_trace(tf, tb->memread, "memread");
    sc_trace(tf, tb->memwrite, "memwrite");
    sc_trace(tf, tb->memAddr, "memAddr");
    sc_trace(tf, tb->int_req, "int_req");
    sc_trace(tf, tb->int_notif, "int_notif");
    sc_trace(tf, tb->int_ID, "int_ID");
    //sc_trace(tf, tb->dut->claim_complete, "claim_complete");
    //sc_trace(tf, tb->dut->ppri, "ppri");
    //sc_trace(tf, tb->dut->pid, "pid");
    //sc_trace(tf, tb->dut->notif_status, "notif_status");
    //sc_trace(tf, tb->dut->int_pending_bits, "int_pending_bits");
    //sc_trace(tf, tb->dut->complete, "plic_tb.dut.complete");
   // sc_trace(tf, tb->dut->gateway_out, "plic_tb.dut.gateway_out");
    //sc_trace(tf, tb.dut->complete_array, "complete_array");

    // Start simulation
    sc_start(15000, SC_NS);

    return 0;
}
