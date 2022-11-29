`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
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

    //port with branch_predicter:
    input wire is_jump_flag_from_bp,
    input wire [`ADDR_TYPE] imm_from_bp,
    output wire [`ADDR_TYPE] pc_to_bp,
    output wire [`INST_TYPE] inst_to_bp,

    //port with dispatcher:
    output reg ok_to_dsp_signal,//一个脉冲信号
    output reg [`INST_TYPE] inst_to_dsp,
    output reg [`ADDR_TYPE] pc_to_dsp
);

localparam IDLE = 0, BUSY = 1; //busy : is querying inst from memCtrl

//256 line-DM cache(block size is 1 inst):
reg cache_valid [`ICACHE_SIZE - 1 : 0];//1 bit for valid;
reg [`ICACHE_TAG_RANGE] cache_tag [`ICACHE_SIZE - 1 : 0];//for tag in cache
reg [`INST_TYPE] cache_data [`ICACHE_SIZE - 1 : 0];//store data in cache

reg [`STATUS_TYPE] fetcher_status;//一个持续的状态
reg [`ADDR_TYPE] pc;

wire is_hit_in_cache = cache_valid[pc[`ICACHE_INDEX_RANGE]] && cache_tag[pc[`ICACHE_INDEX_RANGE]] == pc[`ICACHE_INDEX_RANGE];
wire [`INST_TYPE] hitted_inst_in_cache = is_hit_in_cache ? cache_data[pc[`ICACHE_INDEX_RANGE]] : `ZERO_WORD;

assign inst_to_bp = hitted_inst_in_cache;
assign pc_to_bp = pc;

always @(posedge clk) begin
    if(rst) begin//initial:
        fetcher_status <= IDLE;
        //output signal:
        start_query_signal <= `FALSE;
        ok_to_dsp_signal <= `FALSE;
        //output data:
        pc <= `ZERO_ADDR;
        query_pc <= `ZERO_ADDR;
        inst_to_dsp <= `ZERO_WORD;
        pc_to_dsp <= `ZERO_ADDR;
        for (integer i = 0; i < `ICACHE_SIZE; i++) begin
            cache_valid[i] <= `FALSE;
            cache_tag[i] <= `ZERO_WORD;
            cache_data[i] <= `ZERO_WORD;
        end
    end else if (~rdy)begin
    end
    start_query_signal <= `FALSE;
    ok_to_dsp_signal <= `FALSE;
    if (is_hit_in_cache == `TRUE && global_full_signal == `FALSE) begin//往下传指令
        ok_to_dsp_signal <= `TRUE;
        inst_to_dsp <= hitted_inst_in_cache;
        pc_to_dsp <= pc;
        //todo:change pc
    end else begin//not hit or global_full
        if(is_hit_in_cache == `FALSE && fetcher_status == IDLE) begin//访问内存取指令
            fetcher_status <= BUSY;
            start_query_signal <= `TRUE;
            query_pc <= pc;
        end
        if (finish_query_signal) begin
            fetcher_status <= IDLE;
            cache_data[pc[`ICACHE_INDEX_RANGE]] <= queried_inst;
            cache_valid[pc[`ICACHE_INDEX_RANGE]] <= `TRUE;
            cache_tag[pc[`ICACHE_INDEX_RANGE]] <= pc[`ICACHE_TAG_RANGE];
        end
    end
end

endmodule