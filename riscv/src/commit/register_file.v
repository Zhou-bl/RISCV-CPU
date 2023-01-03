`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

module register_file (
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with dispatcher
    input wire [`REG_POS_TYPE] rs1_from_dispatcher,
    input wire [`REG_POS_TYPE] rs2_from_dispatcher,
    input wire alloc_signal_from_dispatcher,
    input wire [`REG_POS_TYPE] rd_from_dispatcher,
    input wire [`ROB_ID_TYPE] rob_id_for_rd_from_dispatcher,
    output wire [`DATA_TYPE] V1_to_dispatcher,
    output wire [`DATA_TYPE] V2_to_dispatcher,
    output wire [`ROB_ID_TYPE] Q1_to_dispatcher,
    output wire [`ROB_ID_TYPE] Q2_to_dispatcher,

    //port with ROB:
    input wire input_commit_flag,
    input wire rollback_flag,
    input wire [`REG_POS_TYPE] rd_from_ROB,
    input wire [`ROB_ID_TYPE] Q_from_ROB,
    input wire [`DATA_TYPE] V_from_ROB
);


reg [`ROB_ID_TYPE] Q [`REG_SIZE - 1 : 0];
reg [`DATA_TYPE] V [`REG_SIZE - 1 : 0];


reg output_jump_flag_from_ROB, output_commit_Q_elim; 
reg [`ROB_ID_TYPE] output_rob_id_for_rd_from_dispatcher;
reg [`REG_POS_TYPE] output_rd_from_dispatcher, output_rd_from_ROB;
reg [`DATA_TYPE] output_V_from_ROB;

assign Q1_to_dispatcher = 
(output_rd_from_ROB == rs1_from_dispatcher && output_commit_Q_elim) ? 
`ZERO_ROB : (output_rd_from_dispatcher == rs1_from_dispatcher ? 
output_rob_id_for_rd_from_dispatcher : (output_jump_flag_from_ROB ? 
`ZERO_ROB : Q[rs1_from_dispatcher]));

assign Q2_to_dispatcher =
(output_rd_from_ROB == rs2_from_dispatcher && output_commit_Q_elim) ? 
`ZERO_ROB : (output_rd_from_dispatcher == rs2_from_dispatcher ? 
output_rob_id_for_rd_from_dispatcher : (output_jump_flag_from_ROB ? 
`ZERO_ROB : Q[rs2_from_dispatcher]));

assign V1_to_dispatcher = 
(output_rd_from_ROB == rs1_from_dispatcher) ? 
output_V_from_ROB : V[rs1_from_dispatcher];
assign V2_to_dispatcher = 
(output_rd_from_ROB == rs2_from_dispatcher) ? 
output_V_from_ROB : V[rs2_from_dispatcher];

integer i;

always @(*) begin
    output_jump_flag_from_ROB = `FALSE;
    output_rd_from_dispatcher = `ZERO_REG;
    output_rob_id_for_rd_from_dispatcher = `ZERO_ROB;
    output_rd_from_ROB = `ZERO_REG;
    output_commit_Q_elim = `FALSE;
    output_V_from_ROB = `ZERO_WORD;
    
    if (rollback_flag) begin
        output_jump_flag_from_ROB = `TRUE;
    end
    else if (alloc_signal_from_dispatcher == `TRUE && rd_from_dispatcher != `ZERO_REG) begin
        output_rd_from_dispatcher = rd_from_dispatcher;
        output_rob_id_for_rd_from_dispatcher = rob_id_for_rd_from_dispatcher;
    end
    if (input_commit_flag) begin
        if (rd_from_ROB != `ZERO_REG) begin
            //如果目的寄存器是x0那么将结果抛弃
            output_rd_from_ROB = rd_from_ROB; 
            output_V_from_ROB = V_from_ROB;
            if (alloc_signal_from_dispatcher && (rd_from_ROB == rd_from_dispatcher)) begin
                if (output_rob_id_for_rd_from_dispatcher == Q_from_ROB) output_commit_Q_elim = `TRUE;
            end
            else if (Q[rd_from_ROB] == Q_from_ROB) output_commit_Q_elim = `TRUE;
        end
    end
end

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < `REG_SIZE; i=i+1) begin
            Q[i] <= `ZERO_ROB;
            V[i] <= `ZERO_WORD;
        end
    end
    else if(!rdy) begin
    end
    else begin
        //
        if (output_rd_from_ROB != `ZERO_REG) begin
            V[output_rd_from_ROB] <= output_V_from_ROB;
            if (output_commit_Q_elim) Q[output_rd_from_ROB] <= `ZERO_ROB;
        end
        //misbranch: clear all rob id:
        if (output_jump_flag_from_ROB) begin
            for (i = 0; i < `REG_SIZE; i=i+1) begin
                Q[i] <= `ZERO_ROB;
            end
        end
        else if (output_rd_from_dispatcher != `ZERO_REG) begin
            Q[output_rd_from_dispatcher] <= output_rob_id_for_rd_from_dispatcher;
        end
    end
end   

endmodule