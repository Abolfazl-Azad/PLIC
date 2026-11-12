#include "plic.h"
#include <iostream>

using namespace sc_core;
using namespace sc_dt;

SC_MODULE(plic_tb)
{
    
    sc_signal <sc_lv <PLIC_NUM_SOURCES>> int_req;
    sc_signal <sc_lv <32>> memAddr, mem_data;
    sc_signal <sc_logic> memread, memwrite, clk, rst;
    sc_signal <sc_logic> int_notif;
    sc_signal <sc_lv <32>> int_ID;

    plic* dut;

    SC_CTOR(plic_tb)
    {
        dut = new plic("plic_dut");

        dut->int_req(int_req);
        dut->memAddr(memAddr);
        dut->memread(memread);
        dut->mem_data(mem_data);
        dut->memwrite(memwrite);
        dut->clk(clk);
        dut->rst(rst);
        dut->int_notif(int_notif);
        dut->int_ID(int_ID);

        
        SC_THREAD(clk_gen);
        SC_THREAD(test_scenario);
    }

    void clk_gen();
    void test_scenario();
    void config_scenario();
    void scenario_overlap_interrupts();
    void complete_cycle(sc_lv<32> id_value);
    void claim_cycle();
    void wait_cycles(int n);
    void scenario_masked_threshold();
    void scenario_same_priority();
    void scenario_no_pending_interrupt();
    void scenario_dynamic_priority_default();
    void scenario_simultaneous_req_complete();
};