module Wrapper_shift_register #(
    parameter IN_WIDTH  = 8,   
    parameter OUT_WIDTH = 32   
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    load,  
    input  wire [IN_WIDTH-1:0]     data_in, 
    output reg  [OUT_WIDTH-1:0]    data_out   
);

    always @(posedge clk or posedge rst) begin
        if (rst)
            data_out <= {OUT_WIDTH{1'b0}};
        else if (load)
            data_out <= {data_in, data_out[OUT_WIDTH - 1 : IN_WIDTH]};
    end

endmodule