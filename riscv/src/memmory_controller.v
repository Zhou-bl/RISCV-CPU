module memory_controller(
    input clk_in,
    input rst_in,
    input rdy_in,

    //from IF:
    input mem_signal,
    input [31:0] mem_address,

    //to IF
    output reg IF_signal,

    //output:
    output reg [31:0] out_data
);

endmodule