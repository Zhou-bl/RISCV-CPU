`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module fetcher(
    input       clk_in,
    input       rst_in,
    input       rdy_in,

    //instruction from memCtrl:
    input input_signal,
    input [31:0] mem_instr,

    //signal for instruction
    output reg read_signal,
    output reg[31:0] read_mem_pc
);

reg [31:0] pc;
reg is_jump;
parameter JALR = 7'b1100111;
parameter B_TYPE = 7'b1100011;

always @(posedge clk_in) begin
    if(rst_in == 1'b1) begin
      pc <= 32'b0;
    end else begin
      if(input_signal == 1'b1) begin
        is_jump <= (mem_instr[6:0] == JALR | mem_instr[6:0] == B_TYPE);
      end
    end
end

endmodule