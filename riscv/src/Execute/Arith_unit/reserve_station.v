`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module reserve_station(
    input wire clk,
    input wire rst,
    input wire rdy,
    //port with dispatcher:
    input wire enable_signal_from_dispatcher,
    input wire [`OPENUM_TYPE] openum_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q1_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q2_from_dispatcher,
    input wire [`DATA_TYPE] V1_from_dispatcher,
    input wire [`DATA_TYPE] V2_from_dispatcher,
    input wire [`ADDR_TYPE] pc_from_dispatcher,
    input wire [`DATA_TYPE] imm_from_dispatcher,
    input wire [`ROB_ID_TYPE] rob_id_from_dispatcher,

    //port with alu:
    output reg [`OPENUM_TYPE] openum_to_alu,
    output reg [`DATA_TYPE] V1_to_alu,
    output reg [`DATA_TYPE] V2_to_alu,
    output reg [`DATA_TYPE] imm_to_alu,
    output reg [`DATA_TYPE] pc_to_alu
);
endmodule