`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module fetcher(
    input wire clk,
    input wire rst,
    input wire rdy,

    //full signal:
    input wire global_full_signal,

    //port with memCtrl:
    input wire finish_query_signal,//一个脉冲信号
    input wire [`INST_TYPE] queried_inst,
    output reg start_query_signal,//一个脉冲信号
    output reg[`ADDR_TYPE] query_pc,
    output reg stop_signal, //stop querying the instruction when disbranch signal go into the fetcher.

    //port with branch_predicter:
    input wire predicted_jump_flag_from_bp,
    input wire [`ADDR_TYPE] predicted_imm_from_bp,
    output wire [`ADDR_TYPE] pc_to_bp,
    output wire [`INST_TYPE] inst_to_bp,

    //port with dispatcher:
    output reg ok_to_dsp_signal,//一个脉冲信号
    output reg [`INST_TYPE] inst_to_dsp,
    output reg [`ADDR_TYPE] pc_to_dsp,
    output reg predicted_jump_to_dsp,
    output reg [`ADDR_TYPE] roll_back_pc_to_dsp,
    
    //port with ROB:
    input wire misbranch_flag,
    input wire [`ADDR_TYPE] target_pc_from_rob

);

localparam IDLE = 0, BUSY = 1; //busy : is querying inst from memCtrl

//256 line-DM cache(block size is 1 inst):
reg cache_valid [`ICACHE_SIZE - 1 : 0];//1 bit for valid;
reg [`ICACHE_TAG_RANGE] cache_tag [`ICACHE_SIZE - 1 : 0];//for tag in cache
reg [`INST_TYPE] cache_data [`ICACHE_SIZE - 1 : 0];//store data in cache

reg [`STATUS_TYPE] fetcher_status;//一个持续的状态
reg [`ADDR_TYPE] pc;
reg [`ADDR_TYPE] pc_for_memctrl;

wire is_hit_in_cache = cache_valid[pc[`ICACHE_INDEX_RANGE]] && cache_tag[pc[`ICACHE_INDEX_RANGE]] == pc[`ICACHE_TAG_RANGE];
wire [`INST_TYPE] hitted_inst_in_cache = is_hit_in_cache ? cache_data[pc[`ICACHE_INDEX_RANGE]] : `ZERO_WORD;

assign inst_to_bp = hitted_inst_in_cache;
assign pc_to_bp = pc;

integer i;

always @(posedge clk) begin
    if(rst) begin//initial:
        fetcher_status <= IDLE;
        //output signal:
        start_query_signal <= `FALSE;
        stop_signal <= `FALSE;
        ok_to_dsp_signal <= `FALSE;
        //output data:
        pc <= `ZERO_ADDR;
        pc_for_memctrl <= `ZERO_ADDR;
        query_pc <= `ZERO_ADDR;
        inst_to_dsp <= `ZERO_WORD;
        pc_to_dsp <= `ZERO_ADDR;
        for (i = 0; i < `ICACHE_SIZE; i = i + 1) begin
            cache_valid[i] <= `FALSE;
            cache_tag[i] <= `ZERO_WORD;
            cache_data[i] <= `ZERO_WORD;
        end
    end else if (~rdy)begin
    end
    else if(misbranch_flag == `TRUE) begin
        //$display("IF---> misbranch: ", pc);
        ok_to_dsp_signal <= `FALSE;
        pc <= target_pc_from_rob;
        pc_for_memctrl <= target_pc_from_rob;
        fetcher_status <= IDLE;
        start_query_signal <= `FALSE;
        stop_signal <= `TRUE;
    end
    else begin
        //$display("IF---> non_misbranch: ", pc);
        stop_signal <= `FALSE;
        start_query_signal <= `FALSE;
        if (is_hit_in_cache == `TRUE && global_full_signal == `FALSE) begin//往下传指令
            ok_to_dsp_signal <= `TRUE;
            inst_to_dsp <= hitted_inst_in_cache;
            pc_to_dsp <= pc;
            predicted_jump_to_dsp <= predicted_jump_flag_from_bp;
            pc <= pc + (predicted_jump_flag_from_bp == `TRUE ? predicted_imm_from_bp : 4);
            roll_back_pc_to_dsp <= pc + `NEXT_PC;
        end
        else begin
            ok_to_dsp_signal <= `FALSE;
        end
        //not hit or global_full
        if(fetcher_status == IDLE) begin
            //访问内存取指令
            //[BUG!!!] 同时IDLE和往dispatcher传指令时,要记录一个更早的pc
            fetcher_status <= BUSY;
            start_query_signal <= `TRUE;
            query_pc <= pc_for_memctrl;
        end
        else if (finish_query_signal) begin
            fetcher_status <= IDLE;
            pc_for_memctrl <= pc_for_memctrl == pc ? pc_for_memctrl + `NEXT_PC : pc;
            cache_data[pc_for_memctrl[`ICACHE_INDEX_RANGE]] <= queried_inst;
            cache_valid[pc_for_memctrl[`ICACHE_INDEX_RANGE]] <= `TRUE;
            cache_tag[pc_for_memctrl[`ICACHE_INDEX_RANGE]] <= pc_for_memctrl[`ICACHE_TAG_RANGE];
        end
    end
end

endmodule