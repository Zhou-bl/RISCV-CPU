`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

module reorder_buffer (
    input wire clk, 
    input wire rst,
    input wire rdy,

    //data port with dispatcher:
    input wire [`ROB_ID_TYPE] Q1_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q2_from_dispatcher,
    output wire Q1_ready_signal_to_dispatcher,
    output wire Q2_ready_signal_to_dispatcher,
    output wire [`DATA_TYPE] V1_to_dispatcher,
    output wire [`DATA_TYPE] V2_to_dispatcher,

    //alloc rob id to dispatcher:
    input wire alloc_signal_from_dispatcher,
    input wire is_jump_flag_from_dispatcher,
    input wire is_store_flag_from_dispatcher,
    input wire [`REG_POS_TYPE] rd_from_dispatcher,
    input wire predicted_jump_result_from_dispatcher,
    input wire [`ADDR_TYPE] pc_from_dispatcher,
    input wire [`ADDR_TYPE] rollback_pc_from_dispatcher,
    output wire [`ROB_ID_TYPE] alloced_rob_id_to_dispatcher,

    //port with cdb:
        //alu:
    input wire update_signal_from_alu,
    input wire [`ROB_ID_TYPE] rob_id_from_alu,
    input wire [`DATA_TYPE] result_from_alu,
    input wire [`ADDR_TYPE] target_pc_from_alu,
    input wire precise_jump_result_from_alu,
        //lsu:
    input wire update_signal_from_lsu,
    input wire [`ROB_ID_TYPE] rob_id_from_lsu,
    input wire [`DATA_TYPE] result_from_lsu,//传入load的结果;

    //port with lsb(for IO):
    input wire [`ROB_ID_TYPE] io_ins_rob_id_from_LSB,

    //port for commit:
    output reg output_commit_flag,
    output reg misbranch_flag,
        //reg:
    output reg [`REG_POS_TYPE] rd_to_reg_file,
    output reg [`ROB_ID_TYPE] Q_to_reg_file,
    output reg [`DATA_TYPE] V_to_reg_file,
        //if:
    output reg [`ADDR_TYPE] target_pc_to_if,
        //lsb:
    output reg [`ROB_ID_TYPE] rob_id_to_lsb,
    output wire [`ROB_ID_TYPE] io_rob_id_to_lsb,
        //predictor:
    output reg enable_signal_to_predictor,
    output reg precise_branch_flag,
    output reg [`ADDR_TYPE] pc_to_predictor, 
    output wire full_signal
);

reg [`ROB_SIZE - 1 : 0] ROB_busy;
reg [`ROB_SIZE - 1 : 0] ROB_is_ready;
reg [`ROB_SIZE - 1 : 0] ROB_is_IO;
reg [`ROB_SIZE - 1 : 0] ROB_is_jump;
reg [`ROB_SIZE - 1 : 0] ROB_is_store;
reg [`ROB_SIZE - 1 : 0] ROB_precise_jump_result;
reg [`ROB_SIZE - 1 : 0] ROB_predicted_jump_result;
reg [`ADDR_TYPE] ROB_pc [`ROB_SIZE - 1 : 0];
reg [`ADDR_TYPE] ROB_target_pc [`ROB_SIZE - 1 : 0];
reg [`ADDR_TYPE] ROB_rollback_pc [`ROB_SIZE - 1 : 0];
reg [`REG_POS_TYPE] ROB_rd [`ROB_SIZE - 1 : 0];
reg [`DATA_TYPE] ROB_value [`ROB_SIZE - 1 : 0];
 
reg[`ROB_POS_TYPE] head, tail;
wire [`ROB_POS_TYPE]next_head, next_tail;
reg [`ROB_POS_TYPE] cur_ROB_size;
wire commit_signal;

assign alloced_rob_id_to_dispatcher = tail + 1;
assign io_rob_id_to_lsb = ROB_busy[head] && ROB_is_IO[head] ? head + 1: `ZERO_ROB;
assign full_signal = (cur_ROB_size >= `ROB_SIZE - 3);
assign commit_signal = ROB_busy[head] && (ROB_is_ready[head] || ROB_is_store[head]) ;
assign Q1_ready_signal_to_dispatcher = Q1_from_dispatcher == `ZERO_ROB ? `FALSE : ROB_is_ready[Q1_from_dispatcher - 1];
assign Q2_ready_signal_to_dispatcher = Q2_from_dispatcher == `ZERO_ROB ? `FALSE : ROB_is_ready[Q2_from_dispatcher - 1];
assign V1_to_dispatcher = Q1_from_dispatcher == `ZERO_ROB ? `ZERO_WORD : ROB_value[Q1_from_dispatcher - 1];
assign V2_to_dispatcher = Q2_from_dispatcher == `ZERO_ROB ? `ZERO_WORD : ROB_value[Q2_from_dispatcher - 1];
assign next_head = head == `ROB_SIZE - 1 ? 0 : head + 1;
assign next_tail = tail == `ROB_SIZE - 1 ? 0 : tail + 1;

integer i;

always @(posedge clk) begin
    if(rst || misbranch_flag) begin
        cur_ROB_size <= 0;
        head <= 0;
        tail <= 0;
        output_commit_flag <= `FALSE;
        enable_signal_to_predictor <= `FALSE;
        misbranch_flag <= `FALSE;
        for(i = 0; i <= 15; i = i + 1) begin
            ROB_busy[i] <= `FALSE;
            ROB_is_IO[i] <= `FALSE;
            ROB_is_jump[i] <= `FALSE;
            ROB_is_ready[i] <= `FALSE;
            ROB_is_store[i] <= `FALSE;
            ROB_pc[i] <= `FALSE;
            ROB_precise_jump_result[i] <= `FALSE;
            ROB_predicted_jump_result[i] <= `FALSE;
            ROB_rd[i] <= `ZERO_REG;
            ROB_rollback_pc[i] <= `ZERO_ADDR;
            ROB_target_pc[i] <= `ZERO_ADDR;
            ROB_value[i] <= `ZERO_WORD;
        end
    end
    else if(!rdy) begin
    end
    else begin
        //1.当head所在元素就绪时commit
        //2.当enable_signal_from_dispatcher为true时插入新的instructin
        //3.监听cdb总线对ROB中的信息进行更新.
        output_commit_flag <= `FALSE;
        misbranch_flag <= `FALSE;
        enable_signal_to_predictor <= `FALSE;
        cur_ROB_size <= cur_ROB_size - commit_signal + alloc_signal_from_dispatcher;
        //commit:
        if(ROB_busy[head] && (ROB_is_ready[head] || ROB_is_store[head])) begin
            //to reg file and LSB:
            if(ROB_is_jump[head]) begin
                enable_signal_to_predictor <= `TRUE;
                pc_to_predictor <= ROB_pc[head];
                precise_branch_flag <= ROB_precise_jump_result[head];
                if(ROB_precise_jump_result[head] != ROB_predicted_jump_result[head]) begin
                    misbranch_flag <= `TRUE;
                    target_pc_to_if <= ROB_precise_jump_result[head] ? ROB_target_pc[head] : ROB_rollback_pc[head];
                end
            end
            output_commit_flag <= `TRUE;
            rob_id_to_lsb <= head + 1;
            rd_to_reg_file <= ROB_rd[head];
            Q_to_reg_file <= head + 1;
            V_to_reg_file <= ROB_value[head];
            ROB_busy[head] <= `FALSE;
            ROB_is_ready[head] <= `FALSE;
            ROB_is_IO[head] <= `FALSE;
            ROB_is_jump[head] <= `FALSE;
            ROB_is_store[head] <= `FALSE;
            ROB_predicted_jump_result[head] <= `FALSE;
            head <= next_head;
        end
        //alloc:
        if(alloc_signal_from_dispatcher) begin
            ROB_busy[tail] <= `TRUE;
            ROB_is_ready[tail] <= `FALSE;
            ROB_is_IO[tail] <= `FALSE;
            ROB_value[tail] <= `ZERO_WORD;
            ROB_precise_jump_result[tail] <= `FALSE;
            ROB_target_pc[tail] <= `ZERO_ADDR;
            ROB_is_jump[tail] <= is_jump_flag_from_dispatcher;
            ROB_predicted_jump_result[tail] <= predicted_jump_result_from_dispatcher;
            ROB_is_store[tail] <= is_store_flag_from_dispatcher;
            ROB_pc[tail] <= pc_from_dispatcher;
            ROB_rollback_pc[tail] <= rollback_pc_from_dispatcher;
            ROB_rd[tail] <= rd_from_dispatcher;
            tail <= next_tail;
        end
        //update:
        if(io_ins_rob_id_from_LSB != `ZERO_ROB && ROB_busy[io_ins_rob_id_from_LSB - 1]) begin
            ROB_is_IO[io_ins_rob_id_from_LSB - 1] <= `TRUE;
        end

        if(update_signal_from_alu && ROB_busy[rob_id_from_alu - 1]) begin
            ROB_is_ready[rob_id_from_alu - 1] <= `TRUE;
            ROB_value[rob_id_from_alu - 1] <= result_from_alu;
            ROB_precise_jump_result[rob_id_from_alu - 1] <= precise_jump_result_from_alu;
            ROB_target_pc[rob_id_from_alu - 1] <= target_pc_from_alu;
        end
        if(update_signal_from_lsu && ROB_busy[rob_id_from_lsu - 1]) begin
            ROB_is_ready[rob_id_from_lsu - 1] <= `TRUE;
            ROB_value[rob_id_from_lsu - 1] <= result_from_lsu;
        end

    end
end

endmodule