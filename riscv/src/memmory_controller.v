`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module memory_controller(
    input clk_in,
    input rst_in,
    input rdy_in,

    //interface with instruction_fetcher
    input if_in_signal,//read:1 write:0
    input [31:0] mem_address,
    output reg if_out_signal,
    output reg [31:0] out_data
);

endmodule