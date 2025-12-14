// Verilog (IEEE 1364-2001) implementation of the Level-Sensitive Interrupt Gateway.
// This module implements the holding state required for PLIC gateways:
// 1. Assert upon active interrupt signal (int_sig).
// 2. Hold the asserted state even if int_sig deasserts.
// 3. Clear only after 'complete_in' is received AND int_sig is currently low.

module level_sensitive_gateway (
    input clk, rst, int_sig, complete_in, 
    output reg update_pending, 
    output gateway_out   
);

reg waiting_flag;

always @(posedge clk or posedge rst) 
begin
    update_pending              <= 1'b0;
        if (rst) 
        begin 
            waiting_flag        <= 1'b0;
            update_pending      <= 1'b0;
        end else 
        begin
            if (int_sig && !waiting_flag) 
            begin
                waiting_flag         <= 1'b1;
                update_pending       <= 1'b1;
            end 
            if (complete_in) 
            begin
                waiting_flag         <= 1'b0;
                if(int_sig)
                begin
                    waiting_flag     <= 1'b1;
                    update_pending   <= 1'b1;
                end 
            end
        end
end

assign gateway_out = waiting_flag;

endmodule