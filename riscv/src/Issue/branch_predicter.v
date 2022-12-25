`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
//返回给 IF 一个是否为跳转的 bool 类型和经符号位拓展的立即数
module branch_predicter(
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with IF
    input wire [`ADDR_TYPE] input_pc,//pc 的作用是获取指令所在位置,在bht中选择,下面的 rob_pc 同理
    input wire [`INST_TYPE] input_inst,
    output wire is_jump_flag,
    output wire [`ADDR_TYPE] output_imm, //输出到 IF 的立即数

    //update BHT:
    input wire is_update_flag,//是否是更新bht的信号;
    input wire jumped_flag, //计算出来  跳转：1; 不跳转：0
    input wire [`ADDR_TYPE] rob_pc
);

localparam BHT_SIZE = 256, BIT = 2;
localparam STRONG_T = 2'b11, WEAK_T = 2'b10, WEAK_NT = 2'b01, STRONG_NT = 2'b00;

reg [BIT - 1 : 0] branch_history_table [BHT_SIZE - 1 : 0];

wire [`DATA_TYPE] J_type_imm = {{12{input_inst[31]}}, input_inst[19:12], input_inst[20], input_inst[30:21], 1'b0};
wire [`DATA_TYPE] B_type_imm = {{20{input_inst[31]}}, input_inst[7:7], input_inst[30:25], input_inst[11:8], 1'b0};

//jal 一定跳,但是jalr我们无法预测出它跳到哪里
assign is_jump_flag = input_inst[`OPCODE_RANGE] == `OPCODE_JAL ? `TRUE : 
(input_inst[`OPCODE_RANGE] == `OPCODE_BR ? branch_history_table[input_pc[`ADDR_CUT_BP]][1] : `FALSE);

assign output_imm = input_inst[`OPCODE_RANGE] == `OPCODE_JAL ? J_type_imm : B_type_imm;

integer i;

always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i < BHT_SIZE; i = i + 1) begin
            branch_history_table[i] = WEAK_NT;
        end
    end
    else if(is_update_flag) begin //update BHT:
        if(jumped_flag) begin
        
            if(branch_history_table[rob_pc[`ADDR_CUT_BP]] == WEAK_T) begin
                branch_history_table[rob_pc[`ADDR_CUT_BP]] <= STRONG_T;
            end 
            else if(branch_history_table[rob_pc[`ADDR_CUT_BP]] == WEAK_NT) begin
                branch_history_table[rob_pc[`ADDR_CUT_BP]] <= WEAK_T;
            end 
            else if(branch_history_table[rob_pc[`ADDR_CUT_BP]] == STRONG_NT) begin
                branch_history_table[rob_pc[`ADDR_CUT_BP]] <= WEAK_NT;
            end
        end 
        else begin
            if(branch_history_table[rob_pc[`ADDR_CUT_BP]] == WEAK_NT) begin
                branch_history_table[rob_pc[`ADDR_CUT_BP]] <= STRONG_NT;
            end 
            else if(branch_history_table[rob_pc[`ADDR_CUT_BP]] == WEAK_T) begin
                branch_history_table[rob_pc[`ADDR_CUT_BP]] <= WEAK_NT;
            end 
            else if(branch_history_table[rob_pc[`ADDR_CUT_BP]] == STRONG_T) begin
                branch_history_table[rob_pc[`ADDR_CUT_BP]] <= WEAK_T;
            end
        end
        
        /*
        branch_history_table[rob_pc[`ADDR_CUT_BP]] <= branch_history_table[rob_pc[`ADDR_CUT_BP]]
        + ((jumped_flag) ? (branch_history_table[rob_pc[`ADDR_CUT_BP]] == STRONG_T ? 0 : 1) : 
        (branch_history_table[rob_pc[`ADDR_CUT_BP]] == STRONG_NT ? 0 : -1));
        */
     end
end
endmodule