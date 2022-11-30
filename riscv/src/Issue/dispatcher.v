`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Issue/decoder.v"
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
    input wire [`DATA_TYPE] ready_data1_from_rob,
    input wire [`DATA_TYPE] ready_data2_from_rob,

    output reg ena_to_rob,
    output reg [`REG_POS_TYPE] rd_to_rob,
    output reg is_jump_to_rob,
    output reg is_store_to_rob,
    output reg predicted_jump_to_rob,
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
    input wire valid_from_rs_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_rs_cdb,
    input wire [`DATA_TYPE] result_from_rs_cdb,

    //port with ls cdb
    //接受来自cdb的ls信息
    input wire valid_from_ls_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_ls_cdb,
    input wire [`DATA_TYPE] result_from_ls_cdb
);
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
wire [`OPENUM_TYPE] openum_from_decoder;
wire [`REG_POS_TYPE] rs1_from_decoder;
wire [`REG_POS_TYPE] rs2_from_decoder;
wire [`REG_POS_TYPE] rd_from_decoder;
wire [`DATA_TYPE] imm_from_decoder;
wire is_jump_from_decoder;
wire is_store_from_decoder;
assign Q1_to_rob = Q1_from_reg, Q2_to_rob = Q2_from_reg;
assign rs1_to_reg = rs1_from_decoder, rs2_to_reg = rs2_from_decoder;
assign Q_to_reg = rob_id_from_rob, rob_id_to_rs = rob_id_from_rob, rob_id_to_lsb = rob_id_from_rob;

endmodule