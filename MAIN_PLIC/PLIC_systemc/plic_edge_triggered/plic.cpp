#include "plic.h"

void plic::operation (){
    while (true)
    {
        wait(); 
        if (rst.read() == 1) 
        {
            claim_complete = 0;
            ppri = 0;
            pid = 0;
            notif_status = 0;
        } 
        else 
        {
            ppri = 0;
            pid = 0;
            for (int i = 0; i < PLIC_NUM_SOURCES ; i++)
            {
                if (int_pending_bits [i] == sc_logic_1)
                {   
                    if ((int_source_priority [i] > ppri)  &&  int_source_enable [i] == sc_logic_1)
                    {
                        ppri = int_source_priority [i];
                        pid = i + 1;
                    }
                }
            }

            if (ppri > threshold.to_uint())
            {
                int_notif.write(sc_logic_1);
                notif_status = 1;
            }else 
            {
                int_notif.write(sc_logic_0);
            }
            claim_complete = pid;
        }
    }
}


void plic:: eval_conf()
{
    while (true)
    {
        wait();
        sc_uint<32> addr = memAddr.read().to_uint();
        if (memwrite.read() == sc_logic_1)
        {
             if (addr == PLIC_ENABLE_ADDR)
            {
                int_source_enable = mem_data.read();

            }else if (addr == PLIC_THRESHOLD_ADDR)
            {
                threshold =  mem_data.read();
                
            }else if (addr >= PLIC_PRIORITY_START_ADDR && addr < PLIC_PRIORITY_END_ADDR)
            {
                sc_uint<5> source_addr = (addr - PLIC_PRIORITY_START_ADDR) / PLIC_PRIORITY_STRIDE;
                int_source_priority[source_addr] = mem_data.read();
            }

        }else if (memread.read() == sc_logic_1)
        {
            if (addr == PLIC_PENDING_BITS_ADDR)
            {
                int_ID.write (int_pending_bits);

            }else if (addr == PLIC_CLAIM_COMPLETE_ADDR)
            {
                int_ID.write (claim_complete);
            }

        }
    }
}
//--------------------------------------------------------------------------------------------------------------------------
void plic::debug() 
{
    cout << "----------------------------------" << endl;
    cout << "PLIC DEBUG @ " << sc_time_stamp() << endl;
    cout << "Pending bits: " << int_pending_bits.to_string() << endl;
    cout << "Enable bits:  " << int_source_enable.to_string() << endl;
    cout << "Threshold:    " << threshold.to_uint() << endl;
    cout << "Priorities: " << endl;

    for (int i = 0; i < PLIC_NUM_SOURCES; i++) {
        cout << "  Source[" << i + 1 << "] = " << int_source_priority[i] << endl;
    }

    cout << "----------------------------------" << endl;
}
//----------------------------------------------------------------------------------------------------------------------------
void plic:: gateway_operation()
{
    if(rst.read() == sc_logic_1)
    {
        int_pending_bits = 0;
        prev_int_req = 0;
        current_int_req = 0;
        gateway_out = 0;
        in_flight = 0;
        for (int i = 0; i<PLIC_NUM_SOURCES; i++)
        {
            gateway_count[i] = 0;
        }
    }
    current_int_req = int_req.read();
    for (int i = 0; i<PLIC_NUM_SOURCES; i++)
    {
        if((complete_array[i] == sc_logic_1) && (current_int_req[i] == sc_logic_1  && prev_int_req[i] == sc_logic_0))
        {
            in_flight[i] = sc_logic_1;

        }else if (current_int_req[i] == sc_logic_1  && prev_int_req[i] == sc_logic_0)
        {
            in_flight[i] = sc_logic_1;

            if(gateway_count[i] == 0)
            {
                int_pending_bits[i] = in_flight[i];
            }

            if(gateway_count[i] < MAX_PENDING_COUNT)
            {
                gateway_count[i] = gateway_count[i] + 1;
            }

        }else if (complete_array[i] == sc_logic_1)
        {
            gateway_count[i] = gateway_count[i] - 1;
            if (gateway_count[i] == 0)
            {
                in_flight[i] = sc_logic_0;
            }
            int_pending_bits[i] = in_flight[i];
        }      
    }
    gateway_out.write(in_flight);
    prev_int_req = current_int_req;

}
//----------------------------------------------------------------------------------------------------------------------------
void plic :: raise_claim()
{
    if ((memAddr.read()== PLIC_CLAIM_COMPLETE_ADDR) && memread.read() == sc_logic_1)
    {
        int_pending_bits[pid - 1] = SC_LOGIC_0;
    }
}
//------------------------------------------------------------------------------------------------------------------------------
void plic :: raise_complete()
{
    complete.write(sc_logic_0);
    complete_array = 0;
    if ((memAddr.read()== PLIC_CLAIM_COMPLETE_ADDR) && (memwrite.read() == sc_logic_1) && (mem_data.read().to_uint() != 0))
    {
        claim_complete = mem_data.read();
        complete_array[mem_data.read().to_uint() - 1] = sc_logic_1;
        complete.write(sc_logic_1);
    }
}