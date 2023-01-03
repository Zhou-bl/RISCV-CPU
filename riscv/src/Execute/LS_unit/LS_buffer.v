`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

//为保证顺序执行，LSB需要实现为一个循环队列;

module LS_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with dispatcher:
    input wire enable_signal_from_dispatcher,
    input wire [`OPENUM_TYPE] openum_from_dispatcher,
    input wire [`DATA_TYPE] V1_from_dispatcher,
    input wire [`DATA_TYPE] V2_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q1_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q2_from_dispatcher,
    input wire [`ROB_ID_TYPE] rob_id_from_dispatcher,
    input wire [`DATA_TYPE] imm_from_dispatcher,
    
    //port with Arith_unit cdb:
    input wire valid_signal_from_Arith_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_Arith_unit_cdb,
    input wire [`DATA_TYPE] result_from_Arith_unit_cdb,
    
    //port with LS_unit cdb:
    input wire busy_signal_from_lsu,
    input wire valid_signal_from_LS_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_LS_unit_cdb,
    input wire [`DATA_TYPE] result_from_LS_unit_cdb,
    output reg enable_signal_to_lsu,
    output reg [`ROB_ID_TYPE] rob_id_to_LS_unit_cdb,
    output reg [`OPENUM_TYPE] openum_to_lsu,
    output reg [`ADDR_TYPE] mem_address_to_lsu,
    output reg [`DATA_TYPE] stored_data,
   
    //port with rob: store指令需要commit之后才能做
    input wire commit_signal,
    input wire [`ROB_ID_TYPE] commit_rob_id_from_rob,
    input wire [`ROB_ID_TYPE] io_rob_id_from_rob,
    output wire [`ROB_ID_TYPE] io_rob_id_to_rob,

    output wire full_signal,
    input wire misbranch_flag
    
);

reg [`LSB_ID_TYPE] head, tail, cur_store_index;


reg [`OPENUM_TYPE] LSB_openum [`LSB_SIZE - 1 : 0];
reg [`LSB_SIZE - 1 : 0] LSB_busy;
reg [`ROB_ID_TYPE] LSB_rob_id [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_Q1 [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_Q2 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_V1 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_V2 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_imm [`LSB_SIZE - 1 : 0];
reg [`LSB_SIZE - 1 : 0] LSB_is_committed;//for store and IO;

wire [`LSB_ID_TYPE] next_head, next_tail;
wire [`ADDR_TYPE] mem_address = LSB_V1[head] + LSB_imm[head];


reg [`ROB_POS_TYPE] LSB_cur_size;
wire ls_full_signal;
wire [`INT_TYPE] insert_cnt;
wire [`INT_TYPE] issue_cnt;

assign full_signal = ls_full_signal;
assign next_head = (head == `LSB_SIZE - 1) ? 0 : head + 1;
assign next_tail = (tail == `LSB_SIZE - 1) ? 0 : tail + 1;
assign io_rob_id_to_rob = (mem_address == `RAM_IO_ADDRESS) ? LSB_rob_id[head] : `ZERO_ROB;
assign issue_cnt = (((LSB_busy[head] && busy_signal_from_lsu == `FALSE && LSB_Q1[head] == `ZERO_ROB && LSB_Q2[head] == `ZERO_ROB) 
&& ((LSB_openum[head] <= `OPENUM_LHU && (mem_address != `RAM_IO_ADDRESS || io_rob_id_from_rob == LSB_rob_id[head]))
|| (LSB_is_committed[head]))
) ? -1 : 0);
assign ls_full_signal = (LSB_cur_size >= `LSB_SIZE - `FULL_WARNING);
assign insert_cnt = (enable_signal_from_dispatcher ? 1 : 0);

wire [`ROB_ID_TYPE] updated_Q1 = (valid_signal_from_Arith_unit_cdb && Q1_from_dispatcher == rob_id_from_Arith_unit_cdb) ? 
`ZERO_ROB : ((valid_signal_from_LS_unit_cdb && Q1_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
`ZERO_ROB : Q1_from_dispatcher);
wire [`ROB_ID_TYPE] updated_Q2 = (valid_signal_from_Arith_unit_cdb && Q2_from_dispatcher == rob_id_from_Arith_unit_cdb) ? 
`ZERO_ROB : ((valid_signal_from_LS_unit_cdb && Q2_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
`ZERO_ROB : Q2_from_dispatcher);
wire [`DATA_TYPE] updated_V1 = (valid_signal_from_Arith_unit_cdb && Q1_from_dispatcher == rob_id_from_Arith_unit_cdb) ? 
result_from_Arith_unit_cdb : ((valid_signal_from_LS_unit_cdb && Q1_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
result_from_LS_unit_cdb : V1_from_dispatcher);
wire [`DATA_TYPE] updated_V2 = (valid_signal_from_Arith_unit_cdb && Q2_from_dispatcher == rob_id_from_Arith_unit_cdb) ? 
result_from_Arith_unit_cdb : ((valid_signal_from_LS_unit_cdb && Q2_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
result_from_LS_unit_cdb : V2_from_dispatcher);

//for vcd:
reg [`ROB_ID_TYPE] debug_Q1, debug_Q2;
reg [`OPENUM_TYPE] debug_openum;

integer i;

always @(posedge clk) begin
    if (rst || (misbranch_flag == `TRUE && cur_store_index == `INVALID_LSB)) begin
        LSB_cur_size <= `ZERO_WORD;
        head <= `ZERO_LSB;
        tail <= `ZERO_LSB;
        cur_store_index <= `INVALID_LSB;
        enable_signal_to_lsu <= `FALSE;
        for (i = 0; i < `LSB_SIZE; i = i + 1) begin
            LSB_busy[i] <= `FALSE;
            LSB_openum[i] <= `OPENUM_NOP;
            LSB_imm[i] <= `ZERO_WORD;
            LSB_V1[i] <= `ZERO_WORD;
            LSB_V2[i] <= `ZERO_WORD;
            LSB_Q1[i] <= `ZERO_ROB;
            LSB_Q2[i] <= `ZERO_ROB;
            LSB_rob_id[i] <= `ZERO_ROB;
            LSB_is_committed[i] <= `FALSE;
        end
        
    end
    else if (~rdy) begin
    end
    else if (misbranch_flag) begin
        tail <= (cur_store_index == `LSB_SIZE - 1) ? 0 : cur_store_index + 1;
        LSB_cur_size <= ((cur_store_index > head) ? cur_store_index - head + 1 : `LSB_SIZE - head + cur_store_index + 1);
        for (i = 0; i < `LSB_SIZE; i = i+1)
            if (LSB_is_committed[i] == `FALSE || LSB_openum[i] <= `OPENUM_LHU) 
                LSB_busy[i] <= `FALSE;
    end
    else begin
        debug_Q1 <= LSB_Q1[head];
        debug_Q2 <= LSB_Q2[head];
        debug_openum <= LSB_openum[head];
        enable_signal_to_lsu <= `FALSE;
        LSB_cur_size <= LSB_cur_size + insert_cnt + issue_cnt;

        //1.将新的指令放入LSB中
        //2.将head所在的指令传给LSU
        //3.监听CDB总线更新LSB中的信息
        //$display("V1: ", head);
        //alloc from dispatcher:
        if (enable_signal_from_dispatcher) begin
                LSB_busy[tail] <= `TRUE;
                LSB_openum[tail] <= openum_from_dispatcher;          
                LSB_Q1[tail] <= updated_Q1;
                LSB_Q2[tail] <= updated_Q2;
                LSB_V1[tail] <= updated_V1;
                LSB_V2[tail] <= updated_V2;
                LSB_imm[tail] <= imm_from_dispatcher;
                LSB_rob_id[tail] <= rob_id_from_dispatcher;
                LSB_is_committed[tail] <= `FALSE;
                tail <= next_tail;
        end

        //send to lsu:
        if (LSB_busy[head] && !busy_signal_from_lsu && LSB_Q1[head] == `ZERO_ROB && LSB_Q2[head] == `ZERO_ROB) begin
            // load
            //$display("hello!!!!!!");
            if (LSB_openum[head] <= `OPENUM_LHU) begin
                //$display("hello_11111111111111");
                if (mem_address != `RAM_IO_ADDRESS || io_rob_id_from_rob == LSB_rob_id[head]) begin
                    //$display("hello_11111111111111");
                    enable_signal_to_lsu <= `TRUE;
                    openum_to_lsu <= LSB_openum[head];
                    mem_address_to_lsu <= mem_address;
                    rob_id_to_LS_unit_cdb <= LSB_rob_id[head];
                    //clear LSB[head]:
                    LSB_busy[head] <= `FALSE;
                    LSB_rob_id[head] <= `ZERO_ROB; 
                    LSB_is_committed[head] <= `FALSE;
                    LSB_imm[head] <= `ZERO_WORD;
                    LSB_Q1[head] <= `ZERO_ROB;
                    LSB_Q2[head] <= `ZERO_ROB;
                    LSB_V1[head] <= `ZERO_WORD;
                    LSB_V2[head] <= `ZERO_WORD;
                    head <= next_head;
                end
            end
            else begin
                //$display("hello_22222222222");
                if (LSB_is_committed[head]) begin
                    //$display("hello_22222222222");
                    enable_signal_to_lsu <= `TRUE;
                    openum_to_lsu <= LSB_openum[head];
                    mem_address_to_lsu <= mem_address;
                    stored_data <= LSB_V2[head];
                    rob_id_to_LS_unit_cdb <= LSB_rob_id[head];
                    //clear LSB[head]:
                    LSB_busy[head] <= `FALSE;
                    LSB_rob_id[head] <= `ZERO_ROB;
                    LSB_is_committed[head] <= `FALSE;
                    LSB_imm[head] <= `ZERO_WORD;
                    LSB_Q1[head] <= `ZERO_ROB;
                    LSB_Q2[head] <= `ZERO_ROB;
                    LSB_V1[head] <= `ZERO_WORD;
                    LSB_V2[head] <= `ZERO_WORD;
                    head <= next_head;
                    if (cur_store_index == head) begin
                        cur_store_index <= `INVALID_LSB;
                    end  
                end 
            end
        end

        //cdb update:
        if (valid_signal_from_Arith_unit_cdb) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (LSB_Q1[i] == rob_id_from_Arith_unit_cdb) begin
                    LSB_Q1[i] <= `ZERO_ROB;
                    LSB_V1[i] <= result_from_Arith_unit_cdb;
                end
                if (LSB_Q2[i] == rob_id_from_Arith_unit_cdb) begin
                    LSB_Q2[i] <= `ZERO_ROB;
                    LSB_V2[i] <= result_from_Arith_unit_cdb;
                end
            end
        end
        if (valid_signal_from_LS_unit_cdb) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (LSB_Q1[i] == rob_id_from_LS_unit_cdb) begin
                    LSB_Q1[i] <= `ZERO_ROB;
                    LSB_V1[i] <= result_from_LS_unit_cdb;
                end
                if (LSB_Q2[i] == rob_id_from_LS_unit_cdb) begin
                    LSB_Q2[i] <= `ZERO_ROB;
                    LSB_V2[i] <= result_from_LS_unit_cdb;
                end
            end
        end

        //commit update:
        if (commit_signal) begin
            for (i = 0; i < `LSB_SIZE; i=i+1) begin
                if (LSB_busy[i] && LSB_rob_id[i] == commit_rob_id_from_rob && !LSB_is_committed[i]) begin
                    LSB_is_committed[i] <= `TRUE;
                    if (LSB_openum[i] >= `OPENUM_SB) begin
                        cur_store_index <= i;
                    end
                end
            end
        end
    end
end

endmodule