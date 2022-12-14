`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

//为保证顺序执行，LSB需要实现为一个循环队列:
module LS_buffer(
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
    input wire [`DATA_TYPE] imm_from_dispatcher,

    //port with alu:
    input wire valid_signal_from_alu,
    input wire [`ROB_ID_TYPE] rob_id_from_alu,
    input wire [`DATA_TYPE] result_from_alu,
 
    //port with lsu:
    input wire busy_signal_from_lsu,
    input wire valid_signal_from_lsu,
    input wire [`ROB_ID_TYPE] rob_id_from_lsi,
    input wire [`DATA_TYPE] result_from_lsu,
    output reg enable_signal_to_lsu,
    output reg [`OPENUM_TYPE] openum_to_lsu,
    output reg [`ADDR_TYPE] mem_address_to_lsu,
    output reg [`DATA_TYPE] stored_data,


    //port with rob: store指令需要commit之后才能做
    input wire commit_signal,
    input wire [`ROB_ID_TYPE] commit_rob_id_from_rob,
    input wire [`ROB_ID_TYPE] io_rob_id_from_rob,
    output wire [`ROB_ID_TYPE] io_rob_id_to_rob,

    output wire full_signal
);

//LSB:
reg [`LSB_ID_TYPE] head, tail, cur_store_index;
reg [`LSB_SIZE - 1 : 0] LSB_busy;
reg [`OPENUM_TYPE] LSB_openum [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_Q1 [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_Q2 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_V1 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_V2 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_imm [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_rob_id [`LSB_SIZE - 1 : 0];
reg [`LSB_SIZE - 1 : 0] LSB_is_committed;
//other variable: for IO...
wire [`LSB_ID_TYPE] next_head, next_tail;
wire address;
wire send_to_lsu_signal;
reg [`ROB_POS_TYPE] LSB_cur_size;


assign full_signal = (LSB_cur_size >= `LSB_SIZE - 3);
assign address = LSB_V1[head] + LSB_imm[head];
assign io_rob_id_to_rob = address == `RAM_IO_ADDRESS ? LSB_rob_id[head] : `ZERO_ROB;
assign next_head = head == `LSB_SIZE - 1 ? 0 : head + 1;
assign next_tail = tail == `LSB_SIZE - 1 ? 0 : tail + 1;

assign send_to_lsu_signal = (LSB_busy[head] && !busy_signal_from_lsu && LSB_Q1[head] == `ZERO_ROB && LSB_Q2[head]) && 
(LSB_is_committed[head] || (LSB_openum[head] <= `OPENUM_LHU && (address != `RAM_IO_ADDRESS || io_rob_id_from_rob == LSB_rob_id[head])));

integer i;

always @(posedge clk) begin
    if(rst) begin
        for(i = 0; i <= 15; i = i + 1) begin
            LSB_busy[i] <= `FALSE;
            LSB_imm[i] <= `ZERO_WORD;
            LSB_openum[i] <= `OPENUM_NOP;
            LSB_is_committed[i] <= `FALSE;
            LSB_Q1[i] <= `ZERO_ROB;
            LSB_Q2[i] <= `ZERO_ROB;
            LSB_V1[i] <= `ZERO_WORD;
            LSB_V2[i] <= `ZERO_WORD;
            LSB_rob_id[i] <= `ZERO_ROB; 
        end
    end
end

endmodule