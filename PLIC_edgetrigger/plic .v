`timescale 1ns / 1ps

// This is a test comment to push to GitHub.

module plic #(parameter NUM_SOURCES= 31)
(
    input [31:0] mem_addr, mem_data, 
    input mem_read, mem_write, clk, rst, 
    input [NUM_SOURCES - 1 : 0] int_sig, //interrupt signals from sources go through gateway
    output int_notif,
    output reg [31:0] int_ID
);
//-----------------local params----------------------------------
localparam NUM_WORDS                    = (NUM_SOURCES + 31) / 32; 
localparam PRIORITY_INDEX_WIDTH         = $clog2 (NUM_SOURCES + 1);    //0 is reserved
localparam ENABLE_INDEX_WIDTH           = $clog2 (NUM_WORDS);
localparam NUM_EXTENSION                = (NUM_SOURCES + 1) % 32;

localparam PLIC_BASE_ADDR               = 32'h20000000;
localparam PLIC_PRIORITY_START_ADDR     = PLIC_BASE_ADDR + 32'h00000004;
localparam PLIC_PRIORITY_STRIDE         = 32'h00000004;
localparam PLIC_PRIORITY_END_ADDR       =
    PLIC_PRIORITY_START_ADDR + (NUM_SOURCES * PLIC_PRIORITY_STRIDE);
localparam PLIC_PENDING_START_ADDR      = PLIC_BASE_ADDR + 32'h00001000;
localparam PLIC_PENDING_END_ADDR        = PLIC_BASE_ADDR + 32'h0000107C;
localparam PLIC_ENABLE_START_ADDR       = PLIC_BASE_ADDR + 32'h00002000;
localparam PLIC_ENABLE_END_ADDR         = PLIC_BASE_ADDR + 32'h0000207F;
localparam PLIC_THRESHOLD_ADDR          = PLIC_BASE_ADDR + 32'h00200000;
localparam PLIC_CLAIM_COMPLETE_ADDR     = PLIC_BASE_ADDR + 32'h00200004;
//----------------internal signals--------------------------------
reg [31:0] claim_complete;
wire [31:0] ppri [0 : NUM_SOURCES + 1] ;
wire [31:0] pid [0 : NUM_SOURCES + 1] ;
reg claim, complete;
wire [NUM_SOURCES + NUM_EXTENSION : 0] gateway_out;
wire [NUM_SOURCES : 1] gw_req_bus;        // Requests from gateways
reg [NUM_SOURCES : 0] gw_complete_bus;   // Completion signals to gateways
wire [NUM_SOURCES + NUM_EXTENSION : 0] pending_bits_update_status; 
wire [NUM_SOURCES - 1 : 0] gateway_pending_update;

assign gateway_out                  = { {(NUM_EXTENSION){1'b0}}, gw_req_bus, {1'b0}};
assign pending_bits_update_status   = { {(NUM_EXTENSION){1'b0}}, gateway_pending_update, {1'b0}};

genvar k;
generate
    for (k = 1; k <= NUM_SOURCES; k = k + 1) 
    begin : GATEWAY_GEN
        edge_triggered_gateway #(.MAX_PENDING_COUNT(16)) 
        u_gateway (
            .clk(clk),
            .rst(rst),
            .gateway_complete_in(gw_complete_bus[k]),
            .int_sig(int_sig[k-1]),     // Connect corresponding source input
            .gateway_out(gw_req_bus[k]), // Output pulse goes to bus
            .update_pending(gateway_pending_update[k - 1])
        );
    end
endgenerate
//----------------memory mapped interface-------------------------
reg [31:0] pending_bits [0 : NUM_WORDS-1];
reg [31:0] enable_bits [0 : NUM_WORDS-1];
reg [31:0] threshold;
reg [31:0] int_priority [0 : NUM_SOURCES]; //0 is reserved for priority = 0 (no interrupt)

wire [PRIORITY_INDEX_WIDTH - 1 : 0] priority_index;
assign priority_index = ((mem_addr - PLIC_PRIORITY_START_ADDR) >> 2 ) + 1;    //start from index = 1 because of reserved priority 0

wire [ENABLE_INDEX_WIDTH - 1 : 0] enable_index;
assign enable_index = ((mem_addr - PLIC_ENABLE_START_ADDR) >> 2 ) ;  

always @(posedge clk or posedge rst)
begin 
    if (rst)
    begin 
        claim_complete <= 32'd0;
    end
    else if (mem_write) begin 
        if (mem_addr == PLIC_THRESHOLD_ADDR)begin
            threshold <= mem_data;
        end
        else if ((mem_addr >= PLIC_ENABLE_START_ADDR)  && (mem_addr <= PLIC_ENABLE_END_ADDR))begin
            enable_bits [enable_index] <= mem_data;
        end
        else if ((mem_addr >= PLIC_PRIORITY_START_ADDR)  && (mem_addr < PLIC_PRIORITY_END_ADDR))begin
            int_priority [priority_index] <= mem_data;
        end
    end
    else if (mem_read)begin 
        //we should complete this part later
    end
end
//----------------------claim complete logic----------------------------------
reg [31:0] in_service [0 : NUM_WORDS-1];
reg [31:0] temp_claim_complete;
integer j, h;  
always @(posedge clk)
begin 
    claim               <= 1'b0;
    complete            <= 1'b0;
    gw_complete_bus     <= {(NUM_SOURCES + 1){1'b0}};

    if (mem_read && (mem_addr == PLIC_CLAIM_COMPLETE_ADDR))
    begin
        int_ID <= claim_complete;
        claim <= 1'b1;
    end
    else if (mem_write && (mem_addr == PLIC_CLAIM_COMPLETE_ADDR))
    begin
        if ((in_service[mem_data >> 5][mem_data  & 5'h1F] == 1'b1) && (mem_data != 32'd0) && (enable_bits[mem_data >> 5][mem_data  & 5'h1F] == 1'b1))
        begin
            gw_complete_bus[mem_data] <= 1'b1;
            complete <= 1'b1;
        end
    end
end

always @(*)
begin 
    if(rst)
    begin
        for (j = 0; j < NUM_WORDS; j = j + 1)
            in_service[j] = 32'd0;
        temp_claim_complete =  32'd0;
    end
    else if (claim)
    begin
        in_service[claim_complete >> 5][claim_complete  & 5'h1F] = 1'b1;  // mark as claimed
        pending_bits[claim_complete >> 5][claim_complete  & 5'h1F] = 1'b0;  // mark as claimed
    end
    else if (complete)
    begin
        temp_claim_complete = mem_data;
        claim_complete = temp_claim_complete;
        in_service[temp_claim_complete >> 5][temp_claim_complete  & 5'h1F] = 1'b0;
    end
    else 
    begin 
        claim_complete = (ppri[NUM_SOURCES + 1] > threshold) ? pid[NUM_SOURCES + 1] : 32'd0;
    end
end

always @(*)
begin
    if(rst)
    begin
        for (j = 0; j < NUM_WORDS; j = j + 1) 
        begin
            pending_bits[j] = 32'd0;
        end 
    end else 
    begin
        for (j = 0; j < NUM_WORDS; j = j + 1) 
        begin
            for (h= 0; h <32; h = h + 1)
            begin
                if(pending_bits_update_status[(j*32) + h])
                begin
                    pending_bits[j][h] <= gateway_out[(j*32) + h ];
                end
            end
        end
    end
end
//-----------------------prioritizing core--------------------------------------

assign ppri[0]          = 32'd0;
assign pid[0]           = 32'd0;
assign int_priority[0]  = 32'd0;

genvar i;
generate
    for (i = 0; i < NUM_SOURCES + 1 ; i = i + 1) begin : PRIORITY_CHAIN
       prioritization_core p_core (.ppri(ppri[i]), .pid(pid[i]), .priority(int_priority[i]), .id(i), .en(enable_bits[i >> 5][i & 5'h1F]),
                                   .ip(pending_bits[i >> 5][i & 5'h1F]), .npri(ppri[i+1]), .nid(pid[i+1]));
    end
endgenerate
//------------------------output signals-------------------------------------------
assign int_notif = ((pid[NUM_SOURCES + 1] == 32'd0) || (ppri[NUM_SOURCES + 1] < threshold)) ? 1'b0 : 1'b1;

endmodule

