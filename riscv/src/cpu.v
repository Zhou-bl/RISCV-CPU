// RISCV32I CPU top module
// port modification allowed for debugging purposes

`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
//Issue:
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Issue/instruction_fetcher.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Issue/dispatcher.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Issue/branch_predicter.v"
//Execute:
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Execute/Arith_unit/reserve_station.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Execute/Arith_unit/alu.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Execute/LS_unit/LS_buffer.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Execute/LS_unit/lsu.v"
//Commit:
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Commit/reorder_buffer.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Commit/register_file.v"
`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/Commit/memory_controller.v"

module cpu(
  input  wire                 clk_in,			// system clock signal
  input  wire                 rst_in,			// reset signal
	input  wire					        rdy_in,			// ready signal, pause cpu when low

  input  wire [ 7:0]          mem_din,		// data input bus
  output wire [ 7:0]          mem_dout,		// data output bus
  output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
  output wire                 mem_wr,			// write/read signal (1 for write)
	
	input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

// implementation goes here

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

wire RS_full_signal, LSB_full_signal, ROB_full_signal;
wire global_full_signal = (RS_full_signal || LSB_full_signal || ROB_full_signal);

wire finish_query_signal_between_if_and_memctrl;
wire [`INST_TYPE] queried_inst_between_if_and_memctrl;
wire start_query_signal_between_if_and_memctrl;
wire [`ADDR_TYPE] query_pc_between_if_and_memctrl;
wire is_jump_flag_between_if_and_bp;
wire [`ADDR_TYPE] imm_between_if_and_bp;
wire [`ADDR_TYPE] pc_between_if_and_bp;
wire [`INST_TYPE] inst_between_if_and_bp;
wire ok_signal_between_if_and_dispatcher;
wire [`INST_TYPE] inst_between_if_and_dispatcher;
wire [`ADDR_TYPE] pc_between_if_and_dispatcher;
wire predicted_jump_flag_between_if_and_dispatcher;
fetcher CPU_fetcher(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  //full signal:
  .global_full_signal(global_full_signal),

  //port with memCtrl:
  .finish_query_signal(finish_query_signal_between_if_and_memctrl),
  .queried_inst(queried_inst_between_if_and_memctrl),
  .start_query_signal(start_query_signal_between_if_and_memctrl),
  .query_pc(query_pc_between_if_and_memctrl),

  //port with branch_predicter:
  .predicted_jump_flag_from_bp(is_jump_flag_between_if_and_bp),
  .predicted_imm_from_bp(imm_between_if_and_bp),
  .pc_to_bp(pc_between_if_and_bp),
  .inst_to_bp(inst_between_if_and_bp),
  
  //port with dispatcher:
  .ok_to_dsp_signal(ok_signal_between_if_and_dispatcher),
  .inst_to_dsp(inst_between_if_and_dispatcher),
  .pc_to_dsp(pc_between_if_and_dispatcher),
  .predicted_jump_to_dsp(predicted_jump_flag_between_if_and_dispatcher)
);

wire is_update_flag_between_bp_and_ROB;
wire precise_jump_flag_between_bp_and_ROB;
wire [`ADDR_TYPE] rob_pc_between_bp_and_ROB;

branch_predicter CPU_branch_predicter(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),
  
  //port with if:
  .input_pc(pc_between_if_and_bp),
  .input_inst(inst_between_if_and_bp),
  .is_jump_flag(is_jump_flag_between_if_and_bp),
  .output_imm(imm_between_if_and_bp),

  //port with ROB:
  .is_update_flag(is_update_flag_between_bp_and_ROB),
  .jumped_flag(precise_jump_flag_between_bp_and_ROB),
  .rob_pc(rob_pc_between_bp_and_ROB)
);

//for dispatcher port with ROB:
wire [`ROB_ID_TYPE] Q1_between_dispatcher_and_ROB;
wire [`ROB_ID_TYPE] Q2_between_dispatcher_and_ROB;
wire Q1_ready_signal_between_dispatcher_and_ROB;
wire Q2_ready_signal_between_dispatcher_and_ROB;
wire [`DATA_TYPE] V1_result_between_dispatcher_and_ROB;
wire [`DATA_TYPE] V2_result_between_dispatcher_and_ROB;
wire enable_signal_between_dispatcher_and_ROB;
wire [`REG_POS_TYPE] rd_between_dispatcher_and_ROB;
wire is_jump_flag_between_dispatcher_and_ROB;
wire is_store_flag_between_dispatcher_and_ROB;
wire predicted_jump_flag_between_dispatcher_and_ROB;
wire [`ADDR_TYPE] pc_between_dispatcher_and_ROB;
wire [`ROB_ID_TYPE] rob_id_between_dispatcher_and_ROB;

//for dispatcher port with register file:
wire [`REG_POS_TYPE] rs1_between_dispatcher_and_REG;
wire [`REG_POS_TYPE] rs2_between_dispatcher_and_REG;
wire [`DATA_TYPE] V1_between_dispatcher_and_REG;
wire [`DATA_TYPE] V2_between_dispatcher_and_REG;
wire [`ROB_ID_TYPE] Q1_between_dispatcher_and_REG;
wire [`ROB_ID_TYPE] Q2_between_dispatcher_and_REG;
wire enable_signal_between_dispatcher_and_REG;
wire [`REG_POS_TYPE] rd_between_dispatcher_and_REG;
wire [`ROB_ID_TYPE] Q_between_dispatcher_and_REG;

//for dispatcher port with RS:
wire enable_signal_between_dispatcher_and_RS;
wire [`OPENUM_TYPE] openum_between_dispatcher_and_RS;
wire [`DATA_TYPE] V1_between_dispatcher_and_RS;
wire [`DATA_TYPE] V2_between_dispatcher_and_RS;
wire [`ROB_ID_TYPE] Q1_between_dispatcher_and_RS;
wire [`ROB_ID_TYPE] Q2_between_dispatcher_and_RS;
wire [`ADDR_TYPE] pc_between_dispatcher_and_RS;
wire [`DATA_TYPE] imm_between_dispatcher_and_RS;
wire [`ROB_ID_TYPE] rob_id_between_dispatcher_and_RS;

//for dispatcher port with LSB:
wire enable_signal_between_dispatcher_and_LSB;
wire [`OPENUM_TYPE] openum_between_dispatcher_and_LSB;
wire [`DATA_TYPE] V1_between_dispatcher_and_LSB;
wire [`DATA_TYPE] V2_between_dispatcher_and_LSB;
wire [`ROB_ID_TYPE] Q1_between_dispatcher_and_LSB;
wire [`ROB_ID_TYPE] Q2_between_dispatcher_and_LSB;
wire [`DATA_TYPE] imm_between_dispatcher_and_LSB;
wire [`ROB_ID_TYPE] rob_id_between_dispatcher_and_LSB;

dispatcher CPU_dispatcher(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  //port with if:
  .rdy_flag_from_if(ok_signal_between_if_and_dispatcher),
  .inst_from_if(inst_between_if_and_dispatcher),
  .pc_from_if(pc_between_if_and_dispatcher),
  .predicted_jump_flag_from_if(predicted_jump_flag_between_if_and_dispatcher),

  //port with rob:
  .Q1_to_rob(Q1_between_dispatcher_and_ROB),
  .Q2_to_rob(Q2_between_dispatcher_and_ROB),
  .Q1_ready_from_rob(Q1_ready_signal_between_dispatcher_and_ROB),
  .Q2_ready_from_rob(Q2_ready_signal_between_dispatcher_and_ROB),
  .V1_result_from_rob(V1_result_between_dispatcher_and_ROB),
  .V2_result_from_rob(V2_result_between_dispatcher_and_ROB),
  .ena_to_rob(enable_signal_between_dispatcher_and_ROB),
  .rd_to_rob(rd_between_dispatcher_and_ROB),
  .is_jump_signal_to_rob(is_jump_flag_between_dispatcher_and_ROB),
  .is_store_signal_to_rob(is_store_flag_between_dispatcher_and_ROB),
  .predicted_jump_result_to_rob(predicted_jump_flag_between_dispatcher_and_ROB),
  .pc_to_rob(pc_between_dispatcher_and_ROB),
  .rob_id_from_rob(rob_id_between_dispatcher_and_ROB),

  //port with register file:
  .rs1_to_reg(rs1_between_dispatcher_and_REG),
  .rs2_to_reg(rs2_between_dispatcher_and_REG),
  .V1_from_reg(V1_between_dispatcher_and_REG),
  .V2_from_reg(V2_between_dispatcher_and_REG),
  .Q1_from_reg(Q1_between_dispatcher_and_REG),
  .Q2_from_reg(Q2_between_dispatcher_and_REG),
  .ena_to_reg(enable_signal_between_dispatcher_and_REG),
  .rd_to_reg(rd_between_dispatcher_and_REG),
  .Q_to_reg(Q_between_dispatcher_and_REG),

  //port with rs:
  .ena_to_rs(enable_signal_between_dispatcher_and_RS),
  .openum_to_rs(openum_between_dispatcher_and_RS),
  .V1_to_rs(V1_between_dispatcher_and_RS),
  .V2_to_rs(V2_between_dispatcher_and_RS),
  .Q1_to_rs(Q1_between_dispatcher_and_RS),
  .Q2_to_rs(Q2_between_dispatcher_and_RS),
  .pc_to_rs(pc_between_dispatcher_and_RS),
  .imm_to_rs(imm_between_dispatcher_and_RS),
  .rob_id_to_rs(rob_id_between_dispatcher_and_RS),

  //port with ls:
  .ena_to_lsb(enable_signal_between_dispatcher_and_LSB),
  .openum_to_lsb(openum_between_dispatcher_and_LSB),
  .V1_to_lsb(V1_between_dispatcher_and_LSB),
  .V2_to_lsb(V2_between_dispatcher_and_LSB),
  .Q1_to_lsb(Q1_between_dispatcher_and_LSB),
  .Q2_to_lsb(Q2_between_dispatcher_and_LSB),
  .imm_to_lsb(imm_between_dispatcher_and_LSB),
  .rob_id_to_lsb(rob_id_between_dispatcher_and_LSB),

  //port with Arith_unit cdb:
  .valid_from_Arith_unit_cdb(Arith_unit_valid_signal),
  .rob_id_from_Arith_unit_cdb(Arith_unit_rob_id),
  .result_from_Arith_unit_cdb(Arith_unit_result),

  //port with LS_unit cdb:
  .valid_from_LS_unit_cdb(LS_unit_valid_signal),
  .rob_id_from_LS_unit_cdb(LS_unit_rob_id),
  .result_from_LS_unit_cdb(LS_unit_result)
);

//Arith unit cdb:
wire Arith_unit_valid_signal;
wire [`ROB_ID_TYPE] Arith_unit_rob_id;
wire [`DATA_TYPE] Arith_unit_result;
wire [`ADDR_TYPE] Arith_unit_target_pc;
wire Arith_unit_precise_jump_flag;
//LS unit cdb:
wire LS_unit_valid_signal;
wire [`ROB_ID_TYPE] LS_unit_rob_id;
wire [`DATA_TYPE] LS_unit_result;
//for RS port with alu:
wire [`OPENUM_TYPE] openum_between_RS_and_alu;
wire [`DATA_TYPE] V1_between_RS_and_alu;
wire [`DATA_TYPE] V2_between_RS_and_alu;
wire [`DATA_TYPE] imm_between_RS_and_alu;
wire [`ADDR_TYPE] pc_between_RS_and_alu;

reserve_station CPU_reserve_station(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  //port with dispatcher:
  .enable_signal_from_dispatcher(enable_signal_between_dispatcher_and_RS),
  .openum_from_dispatcher(openum_between_dispatcher_and_RS),
  .Q1_from_dispatcher(Q1_between_dispatcher_and_RS),
  .Q2_from_dispatcher(Q2_between_dispatcher_and_RS),
  .V1_from_dispatcher(V1_between_dispatcher_and_RS),
  .V2_from_dispatcher(V2_between_dispatcher_and_RS),
  .pc_from_dispatcher(pc_between_dispatcher_and_RS),
  .imm_from_dispatcher(imm_between_dispatcher_and_RS),
  .rob_id_from_dispatcher(rob_id_between_dispatcher_and_RS),

  //port with alu:
  .openum_to_alu(openum_between_RS_and_alu),
  .V1_to_alu(V1_between_RS_and_alu),
  .V2_to_alu(V2_between_RS_and_alu),
  .imm_to_alu(imm_between_RS_and_alu),
  .pc_to_alu(pc_between_RS_and_alu),

  //port with Arith_unit cdb:
  .valid_signal_from_Arith_unit_cdb(Arith_unit_valid_signal),
  .rob_id_from_Arith_unit_cdb(Arith_unit_rob_id),
  .result_from_Arith_unit_cdb(Arith_unit_result),
  .rob_id_to_Arith_unit_cdb(Arith_unit_rob_id),

  //port with LS_unit cdb:
  .valid_signal_from_LS_unit_cdb(LS_unit_valid_signal),
  .rob_id_from_LS_unit_cdb(LS_unit_rob_id),
  .result_from_LS_unit_cdb(LS_unit_result),

  .full_signal(RS_full_signal)
);

//for LSB port with lsu:
wire busy_signal_between_LSB_and_lsu;
wire enable_signal_between_LSB_and_lsu;
wire [`OPENUM_TYPE] openum_between_LSB_and_lsu;
wire [`ADDR_TYPE] mem_address_between_LSB_and_lsu;
wire [`DATA_TYPE] stored_data_between_LSB_and_lsu;

//for LSB port with rob(commit):
wire [`ROB_ID_TYPE] commit_rob_id_between_LSB_and_ROB;
wire [`ROB_ID_TYPE] io_rob_id_from_ROB_to_LSB;
wire [`ROB_ID_TYPE] io_rob_id_from_LSB_to_ROB;

LS_buffer CPU_LS_buffer(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  //port with dispatcher:
  .enable_signal_from_dispatcher(enable_signal_between_dispatcher_and_LSB),
  .openum_from_dispatcher(openum_between_dispatcher_and_LSB),
  .Q1_from_dispatcher(Q1_between_dispatcher_and_LSB),
  .Q2_from_dispatcher(Q2_between_dispatcher_and_LSB),
  .V1_from_dispatcher(V1_between_dispatcher_and_LSB),
  .V2_from_dispatcher(V2_between_dispatcher_and_LSB),
  .rob_id_from_dispatcher(rob_id_between_dispatcher_and_LSB),
  .imm_from_dispatcher(imm_between_dispatcher_and_LSB),

  //port with Arith_unit cdb:
  .valid_signal_from_Arith_unit_cdb(Arith_unit_valid_signal),
  .rob_id_from_Arith_unit_cdb(Arith_unit_rob_id),
  .result_from_Arith_unit_cdb(Arith_unit_result),

  //port with LS_unit cdb:
  .valid_signal_from_LS_unit_cdb(LS_unit_valid_signal),
  .rob_id_from_LS_unit_cdb(LS_unit_rob_id),
  .result_from_LS_unit_cdb(LS_unit_result),

  //port with lsu:
  .busy_signal_from_lsu(busy_signal_between_LSB_and_lsu),
  .enable_signal_to_lsu(enable_signal_between_LSB_and_lsu),
  .openum_to_lsu(openum_between_LSB_and_lsu),
  .mem_address_to_lsu(mem_address_between_LSB_and_lsu),
  .stored_data(stored_data_between_LSB_and_lsu),

  //port with ROB:
  .commit_signal(ROB_commit_signal_cdb),
  .commit_rob_id_from_rob(commit_rob_id_between_LSB_and_ROB),
  .io_rob_id_from_rob(io_rob_id_from_ROB_to_LSB),
  .io_rob_id_to_rob(io_rob_id_from_LSB_to_ROB),

  .full_signal(LSB_full_signal)
);

//commit cdb:
wire ROB_commit_signal_cdb;

alu CPU_alu(
  .input_openum(openum_between_RS_and_alu),
  .V1(V1_between_RS_and_alu),
  .V2(V2_between_RS_and_alu),
  .imm(imm_between_RS_and_alu),
  .input_pc(pc_between_RS_and_alu),
  .output_result(Arith_unit_result),
  .output_pc(Arith_unit_target_pc),
  .is_jump_flag(Arith_unit_precise_jump_flag),
  .valid(Arith_unit_valid_signal)
);

lsu CPU_lsu(
  .clk(clk_in),
  .rst(rst_in),
  .rdy(rdy_in),

  //port with LSB:
  .enable_signal_from_LSB(),
  .openum_from_LSB(),
  .address_from_LSB(),
  .data_from_LSB(),
  .busy_signal_to_LSB(),

  //port with memctrl:
  .finish_flag_from_memctrl(),
  .data_from_memctrl(),
  .enable_signal_to_memctrl(),
  .read_or_write_flag_to_memctrl(),
  .size_to_memctrl(),
  .address_to_memctrl(),
  .data_to_memctrl(),
  
  //port with LS_unit cdb:
  .valid_signal_to_cdb(),
  .result_to_cdb()
);

endmodule