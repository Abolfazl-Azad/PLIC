`timescale 1ns / 1ps
//-----------------------------------------------------------------------------
// Module: edge_triggered_gateway
//
// Purpose:
// This module implements an edge-triggered interrupt gateway for the RISC-V
// PLIC. It is responsible for:
//
// 1. Detecting a *rising edge* on the external interrupt line (`int_sig`).
// 2. Queuing these edges if the PLIC is already busy with a previous
//    interrupt from this source.
// 3. Forwarding *one* interrupt request (`gateway_out`) to the PLIC core.
// 4. Waiting for a 'completion' signal (`gateway_complete_in`) before
//    forwarding the *next* queued interrupt.
//
//-----------------------------------------------------------------------------

module edge_triggered_gateway #(parameter MAX_PENDING_COUNT = 16)
(
    input  clk, 
    input  rst, 
    input  gateway_complete_in,
    input  int_sig,
    output reg gateway_out,
    output reg update_pending
);

    localparam COUNTER_WIDTH = $clog2(MAX_PENDING_COUNT + 1);
    // `int_count`: Tracks the number of *queued* edges that have arrived
    reg [COUNTER_WIDTH - 1:0] int_count;
    reg prev_int_sig;
    reg request_in_flight; 
    wire rising_edge;

    assign rising_edge = (int_sig == 1'b1) && (prev_int_sig == 1'b0);

    always @(posedge clk or posedge rst) 
    begin
        if (rst) 
        begin
            gateway_out       <= 1'b0;
            int_count         <= {COUNTER_WIDTH{1'b0}};
            prev_int_sig      <= 1'b0;
            request_in_flight <= 1'b0;
            update_pending    <= 1'b0;
        end
        else 
        begin

            prev_int_sig        <= int_sig;
            update_pending      <= 1'b0;
            //-------------------------------------------------
            // 1. int_sig is recive 
            //-------------------------------------------------
            if (rising_edge) 
            begin
                if (!request_in_flight) 
                begin 
                    update_pending    <= 1'b1;
                    gateway_out       <= 1'b1;
                    request_in_flight <= 1'b1;
                end 
                else 
                begin
                    if (int_count < MAX_PENDING_COUNT) 
                    begin
                        if(!gateway_complete_in)
                            int_count <= int_count + 1;
                    end
                    // else: int_count is full, the edge is dropped.
                end
            end
            //-------------------------------------------------
            // 2. the intrupt is handled
            //-------------------------------------------------
            if (gateway_complete_in) 
            begin
                update_pending      <= 1'b1;
                if (int_count > 0) 
                begin
                    if(!rising_edge)
                        int_count <= int_count - 1;     
                    gateway_out <= 1'b1;  
                    request_in_flight <= 1'b1;    
                end 
                else 
                begin
                    if (rising_edge)
                    begin
                        gateway_out <= 1'b1;
                        request_in_flight <= 1'b1;
                    end
                    else
                    begin
                        gateway_out <= 1'b0;
                        request_in_flight <= 1'b0;
                    end     
                end
            end
        end
    end

endmodule