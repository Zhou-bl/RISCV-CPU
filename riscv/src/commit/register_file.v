`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

module register_file(
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with dispatcher:
    input wire alloc_signal_from_dispatcher,
    input wire [`REG_POS_TYPE] rs1_from_dispatcher,
    input wire [`REG_POS_TYPE] rs2_from_dispatcher,
    input wire [`REG_POS_TYPE] rd_from_dispatcher,
    input wire [`ROB_ID_TYPE] rob_id_for_rd_from_dispatcher,
    output wire [`ROB_ID_TYPE] Q1_to_dispatcher,
    output wire [`ROB_ID_TYPE] Q2_to_dispatcher,
    output wire [`DATA_TYPE] V1_to_dispatcher,
    output wire [`DATA_TYPE] V2_to_dispatcher,

    //port with ROB:
    input wire input_commit_flag,
    input wire rollback_flag,//clear REG_Q;
    input wire [`REG_POS_TYPE] rd_from_ROB,
    input wire [`ROB_ID_TYPE] Q_from_ROB,
    input wire [`DATA_TYPE] V_from_ROB
);

reg [`ROB_ID_TYPE] REG_Q [`REG_SIZE - 1 : 0];
reg [`DATA_TYPE] REG_V[`REG_SIZE - 1 : 0];

assign Q1_to_dispatcher = REG_Q[rs1_from_dispatcher];
assign Q2_to_dispatcher = REG_Q[rs2_from_dispatcher];
assign V1_to_dispatcher = REG_V[rs1_from_dispatcher];
assign V2_to_dispatcher = REG_V[rs2_from_dispatcher];

integer i;

always @(*) begin
    if(rst) begin
        for(i = 0; i < `REG_SIZE; i = i + 1) begin
            REG_Q[i] = `ZERO_ROB;
            REG_V[i] = `ZERO_WORD;
        end
    end
    else if(!rdy) begin
    end
    else begin
        if(input_commit_flag) begin
            for(i = 0; i < `REG_SIZE; i = i + 1) begin
                REG_Q[i] = `ZERO_ROB;
            end
        end
        if(alloc_signal_from_dispatcher) begin
            if(rd_from_dispatcher != `ZERO_REG) begin
                REG_Q[rd_from_dispatcher] = rob_id_for_rd_from_dispatcher;
            end 
        end
        if(input_commit_flag) begin
            if(rd_from_ROB != `ZERO_REG) begin
                REG_V[rd_from_ROB] = V_from_ROB;
            end
            if(REG_Q[rd_from_ROB] == Q_from_ROB) begin
                REG_Q[rd_from_ROB] = `ZERO_ROB;
            end
        end
    end
end

endmodule