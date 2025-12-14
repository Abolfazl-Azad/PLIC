`timescale 1ns / 1ps

module prioritization_core                        //we check from source 1 to source NUM_SOURCES
(
    input [31:0] ppri, pid, priority, id,
    input en, ip,
    output reg [31:0] npri, nid
);

always @(*)
begin
    if (en && ip) begin
        if (priority > ppri) begin
            npri = priority;
            nid = id;
        end
        else begin
            nid = pid;
            npri = ppri;
        end
    end
    else begin
        nid = pid;
        npri = ppri;
    end
end


endmodule