`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Issue/decoder.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Issue/data_forwarding.v"
//nmodule 作用：数据分发中心,接受各方数据并且在cdb总线上进行广播
module dispatcher(
    //system clock:
    input wire clk,
    input wire rst,
    input wire rdy,

    //from fetcher:
    input wire rdy_flag_from_if,
    input wire [`INST_TYPE] inst_from_if,
    input wire [`ADDR_TYPE] pc_from_if,
    input wire predicted_jump_flag_from_if,

    //port with rob
    output wire [`ROB_ID_TYPE] Q1_to_rob,
    output wire [`ROB_ID_TYPE] Q2_to_rob,
    input wire Q1_ready_from_rob,
    input wire Q2_ready_from_rob,
    input wire [`DATA_TYPE] V1_result_from_rob,
    input wire [`DATA_TYPE] V2_result_from_rob,

    output reg ena_to_rob,
    output reg [`REG_POS_TYPE] rd_to_rob,
    output reg is_jump_signal_to_rob,
    output reg is_store_signal_to_rob,
    output reg predicted_jump_result_to_rob,
    output reg [`ADDR_TYPE] pc_to_rob,
    input wire [`ROB_ID_TYPE] rob_id_from_rob,

    //port with regfile:
    //query and return
    output wire [`REG_POS_TYPE] rs1_to_reg,
    output wire [`REG_POS_TYPE] rs2_to_reg, 
    input wire [`DATA_TYPE] V1_from_reg,
    input wire [`DATA_TYPE] V2_from_reg,
    input wire [`ROB_ID_TYPE] Q1_from_reg,
    input wire [`ROB_ID_TYPE] Q2_from_reg,
    //result
    output reg ena_to_reg, 
    output reg [`REG_POS_TYPE] rd_to_reg,
    output wire [`ROB_ID_TYPE] Q_to_reg,

    //port with rs
    output reg ena_to_rs,
    output reg [`OPENUM_TYPE] openum_to_rs,
    output reg [`DATA_TYPE] V1_to_rs,
    output reg [`DATA_TYPE] V2_to_rs,
    output reg [`ROB_ID_TYPE] Q1_to_rs,
    output reg [`ROB_ID_TYPE] Q2_to_rs,
    output reg [`ADDR_TYPE] pc_to_rs,
    output reg [`DATA_TYPE] imm_to_rs,
    output wire [`ROB_ID_TYPE] rob_id_to_rs,

    //port with ls
    output reg ena_to_lsb,
    output reg [`OPENUM_TYPE] openum_to_lsb,
    output reg [`DATA_TYPE] V1_to_lsb,
    output reg [`DATA_TYPE] V2_to_lsb,
    output reg [`ROB_ID_TYPE] Q1_to_lsb,
    output reg [`ROB_ID_TYPE] Q2_to_lsb,
    output reg [`DATA_TYPE] imm_to_lsb,
    output wire [`ROB_ID_TYPE] rob_id_to_lsb,

    //port with rs cdb
    //接受来自cdb的rs信息
    input wire valid_from_Arith_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_Arith_unit_cdb,
    input wire [`DATA_TYPE] result_from_Arith_unit_cdb,

    //port with ls cdb
    //接受来自cdb的ls信息
    input wire valid_from_LS_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_LS_unit_cdb,
    input wire [`DATA_TYPE] result_from_LS_unit_cdb
);
//internal data:
wire [`OPENUM_TYPE] openum_from_decoder;
wire [`REG_POS_TYPE] rs1_from_decoder;
wire [`REG_POS_TYPE] rs2_from_decoder;
wire [`REG_POS_TYPE] rd_from_decoder;
wire [`DATA_TYPE] imm_from_decoder;
wire is_jump_from_decoder;
wire is_store_from_decoder;
wire [`ROB_ID_TYPE] Q1, Q2;
wire [`DATA_TYPE] V1, V2;

decoder internal_decoder(
    .input_inst(inst_from_if),
    .is_jump(is_jump_from_decoder),
    .is_store(is_store_from_decoder),
    .openum(openum_from_decoder),
    .rd(rd_from_decoder),
    .rs1(rs1_from_decoder),
    .rs2(rs2_from_decoder),
    .imm(imm_from_decoder)
);

data_forwarding internal_data_forwarding(
    .valid_from_Arith_unit_cdb(valid_from_Arith_unit_cdb),
    .rob_id_from_Arith_unit_cdb(rob_id_from_Arith_unit_cdb),
    .result_from_Arith_unit_cdb(result_from_Arith_unit_cdb),

    .valid_from_LS_unit_cdb(valid_from_LS_unit_cdb),
    .rob_id_from_LS_unit_cdb(rob_id_from_LS_unit_cdb),
    .result_from_LS_unit_cdb(result_from_LS_unit_cdb),

    .Q1_ready_from_rob(Q1_ready_from_rob),
    .Q2_ready_from_rob(Q2_ready_from_rob),
    .V1_result_from_rob(V1_result_from_rob),
    .V2_result_from_rob(V2_result_from_rob),

    .Q1_from_reg(Q1_from_reg),
    .Q2_from_reg(Q2_from_reg),
    .V1_from_reg(V1_from_reg),
    .V2_from_reg(V2_from_reg),

    .Q1_to_dispatch(Q1),
    .Q2_to_dispatch(Q2),
    .V1_to_dispatch(V1),
    .V2_to_dispatch(V2)
);

assign Q1_to_rob = Q1_from_reg;
assign Q2_to_rob = Q2_from_reg;

assign rs1_to_reg = rs1_from_decoder;
assign rs2_to_reg = rs2_from_decoder;

assign Q_to_reg = rob_id_from_rob;
assign rob_id_to_rs = rob_id_from_rob;
assign rob_id_to_lsb = rob_id_from_rob;

always @(posedge clk) begin
    if(rst) begin
        ena_to_lsb <= `FALSE;
        ena_to_rs <= `FALSE;
        ena_to_reg <= `FALSE;
        ena_to_rob <= `FALSE;
    end
    else if(~rdy) begin
    end
    else if(openum_from_decoder == `OPENUM_NOP || !rdy_flag_from_if) begin
        ena_to_lsb <= `FALSE;
        ena_to_reg <= `FALSE;
        ena_to_rob <= `FALSE;
        ena_to_rs <= `FALSE;
    end
    else if(rdy_flag_from_if) begin
        ena_to_rob <= `TRUE;
        ena_to_reg <= `TRUE;
        rd_to_rob <= rd_from_decoder;
        rd_to_reg <= rd_from_decoder;
        pc_to_rob <= pc_from_if;
        is_jump_signal_to_rob <= is_jump_from_decoder;
        is_store_signal_to_rob <= is_store_from_decoder;
        predicted_jump_result_to_rob <= predicted_jump_flag_from_if;
        if(openum_from_decoder >= `OPENUM_LB && openum_from_decoder <= `OPENUM_SW) begin
            ena_to_lsb <= `TRUE;
            ena_to_rs <= `FALSE;

            openum_to_lsb <= openum_from_decoder;
            Q1_to_lsb <= Q1;
            Q2_to_lsb <= Q2;
            V1_to_lsb <= V1;
            V2_to_lsb <= V2;
            imm_to_lsb <= imm_from_decoder;

            //消除latch:
            openum_to_rs <= `OPENUM_NOP;
            Q1_to_rs <= `ZERO_ROB;
            Q2_to_rs <= `ZERO_ROB;
            V1_to_rs <= `ZERO_WORD;
            V2_to_rs <= `ZERO_WORD;
            pc_to_rs <= `ZERO_ADDR;
            imm_to_rs <= `ZERO_WORD;
        end
        else begin
            ena_to_rs <= `TRUE;
            ena_to_lsb <= `FALSE;

            openum_to_rs <= openum_from_decoder;
            Q1_to_rs <= Q1;
            Q2_to_rs <= Q2;
            V1_to_rs <= V1;
            V2_to_rs <= V2;
            pc_to_rs <= pc_from_if;
            imm_to_rs <= imm_from_decoder;
            
            //消除latch:
            openum_to_lsb <= `OPENUM_NOP;
            Q1_to_lsb <= `ZERO_ROB;
            Q2_to_lsb <= `ZERO_ROB;
            V1_to_lsb <= `ZERO_WORD;
            V2_to_lsb <= `ZERO_WORD;
            imm_to_lsb <= `ZERO_WORD;
        end
    end else begin
        //消除latch:
        ena_to_lsb <= `FALSE;
        ena_to_reg <= `FALSE;
        ena_to_rob <= `FALSE;
        ena_to_rs <= `FALSE;
        rd_to_reg <= `ZERO_REG;
        rd_to_rob <= `ZERO_REG;
        pc_to_rob <= `ZERO_ADDR;
        is_jump_signal_to_rob <= `FALSE;
        is_store_signal_to_rob <= `FALSE;
        predicted_jump_result_to_rob <= `FALSE;
        openum_to_rs <= `OPENUM_NOP;
        openum_to_lsb <= `OPENUM_NOP;
        Q1_to_lsb <= `ZERO_ROB;
        Q2_to_lsb <= `ZERO_ROB;
        Q1_to_rs <= `ZERO_ROB;
        Q2_to_rs <= `ZERO_ROB;
        V1_to_lsb <= `ZERO_WORD;
        V2_to_lsb <= `ZERO_WORD;
        V1_to_rs <= `ZERO_WORD;
        V2_to_rs <= `ZERO_WORD;
        pc_to_rs <= `ZERO_ADDR;
        imm_to_lsb <= `ZERO_WORD;
        imm_to_rs <= `ZERO_WORD;
    end
end

endmodule