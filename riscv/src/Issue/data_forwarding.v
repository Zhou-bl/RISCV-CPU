`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module data_forwarding(
    //Q:
    //data from rs:
    input wire valid_from_rs_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_rs_cdb,
    input wire [`DATA_TYPE] result_from_rs_cdb,
    //data from ls:
    input wire valid_from_ls_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_ls_cdb,
    input wire [`DATA_TYPE] result_from_ls_cdb,
    //data from rob:
    input wire Q1_ready_from_rob,
    input wire Q2_ready_from_rob,
    input wire [`DATA_TYPE] V1_result_from_rob,
    input wire [`DATA_TYPE] V2_result_from_rob,
    //data from regfile: 
    input wire [`ROB_ID_TYPE] Q1_from_reg,
    input wire [`ROB_ID_TYPE] Q2_from_reg,
    input wire [`DATA_TYPE] V1_from_reg,
    input wire [`DATA_TYPE] V2_from_reg,

    output wire [`ROB_ID_TYPE] Q1_to_dispatch,
    output wire [`ROB_ID_TYPE] Q2_to_dispatch,
    output wire [`DATA_TYPE] V1_to_dispatch,
    output wire [`DATA_TYPE] V2_to_dispatch
);

//计算运算数的Q,V:依次从alu\lsu\rob\reg中寻找
assign Q1 = (valid_from_rs_cdb && Q1_from_reg == rob_id_from_rs_cdb) ? 
`ZERO_ROB : ((valid_from_ls_cdb && Q1_from_reg == rob_id_from_ls_cdb) ? 
`ZERO_ROB : (Q1_ready_from_rob ? 
`ZERO_ROB : (Q1_from_reg)));

assign Q2 = (valid_from_rs_cdb && Q2_from_reg == rob_id_from_rs_cdb) ?
`ZERO_ROB : ((valid_from_ls_cdb && Q2_from_reg == rob_id_from_ls_cdb) ? 
`ZERO_ROB : (Q2_ready_from_rob ? 
`ZERO_ROB : (Q2_from_reg)));

assign V1 = (valid_from_rs_cdb && Q1_from_reg == rob_id_from_rs_cdb) ?
result_from_rs_cdb : ((valid_from_ls_cdb && Q1_from_reg == rob_id_from_ls_cdb) ? 
result_from_ls_cdb : ((Q1_ready_from_rob ? 
V1_result_from_rob : V1_from_reg)));

assign V2 = (valid_from_ls_cdb && Q2_from_reg == rob_id_from_rs_cdb) ?
result_from_rs_cdb : ((valid_from_ls_cdb && Q2_from_reg == rob_id_from_ls_cdb) ?
result_from_ls_cdb : ((Q2_ready_from_rob ?
V2_result_from_rob : V2_from_reg)));

endmodule