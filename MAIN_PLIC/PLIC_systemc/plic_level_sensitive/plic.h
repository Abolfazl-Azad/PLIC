#pragma once

#include <systemc.h>
using namespace std;

static const int PLIC_NUM_SOURCES          = 32;                //this code needs modification for more interrupt sources
static const int MAX_PENDING_COUNT         = 16;

constexpr unsigned int PLIC_BASE_ADDR        = 0x20000000;

constexpr unsigned int PLIC_PRIORITY_START_ADDR   = PLIC_BASE_ADDR + 0x000004;

constexpr unsigned int PLIC_PRIORITY_STRIDE  = 0x4;

constexpr unsigned int PLIC_PRIORITY_END_ADDR =
    PLIC_PRIORITY_START_ADDR + (PLIC_NUM_SOURCES * PLIC_PRIORITY_STRIDE);

constexpr unsigned int PLIC_PENDING_BITS_ADDR = PLIC_BASE_ADDR + 0x001000;

constexpr unsigned int PLIC_ENABLE_ADDR = PLIC_BASE_ADDR + 0x002000;

constexpr unsigned int PLIC_THRESHOLD_ADDR = PLIC_BASE_ADDR + 0x200000;

constexpr unsigned int PLIC_CLAIM_COMPLETE_ADDR = PLIC_BASE_ADDR + 0x200004;

SC_MODULE(plic) {
    sc_in <sc_lv <PLIC_NUM_SOURCES>> int_req;
    sc_in <sc_lv <32>> memAddr, mem_data;
    sc_in <sc_logic> memread, memwrite, clk, rst;
    sc_out <sc_logic> int_notif;
    sc_out <sc_lv <32>> int_ID;

    sc_lv <PLIC_NUM_SOURCES> int_pending_bits;
    sc_uint<32> int_source_priority[PLIC_NUM_SOURCES];
    sc_lv <32> int_source_enable;
    sc_lv <32> threshold;
    sc_lv <32> claim_complete;

    sc_uint<32> ppri, pid;
    sc_uint<1> notif_status;

    sc_signal<sc_logic> complete;                  //assuming all completes are valid from the cpu since the written device id is actually in service
    sc_lv <PLIC_NUM_SOURCES>  complete_array;

    sc_lv <PLIC_NUM_SOURCES> current_int_req;
    sc_lv <PLIC_NUM_SOURCES> waiting_flag;
    sc_signal<sc_lv <PLIC_NUM_SOURCES>> gateway_out;



    SC_CTOR(plic)
    
    {
        ppri = 0;
        pid = 0;
        notif_status = 0;
        current_int_req = 0;
        gateway_out = 0;
        waiting_flag = 0;

        SC_THREAD (operation);
        sensitive << clk.pos() << rst.pos();
        SC_THREAD (eval_conf);
        sensitive << clk.pos();
        SC_THREAD (gateway_operation);             //level-sensitive gateway implementation
        sensitive <<  clk.pos() << rst.pos();
        SC_METHOD(raise_claim);
        sensitive << clk.pos();
        SC_METHOD (raise_complete);
        sensitive << clk.pos();
        
    }
    void operation();
    void eval_conf();
    void gateway_operation();
    void raise_claim();     
    void raise_complete();
    void debug();
};
