`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

//为保证顺序执行，LSB需要实现为一个循环队列;

module LS_buffer (
    input wire clk,
    input wire rst,
    input wire rdy,

    // from dispatcher
    input wire enable_signal_from_dispatcher,
    input wire [`OPENUM_TYPE] openum_from_dispatcher,
    input wire [`DATA_TYPE] V1_from_dispatcher,
    input wire [`DATA_TYPE] V2_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q1_from_dispatcher,
    input wire [`ROB_ID_TYPE] Q2_from_dispatcher,
    input wire [`DATA_TYPE] imm_from_dispatcher,
    input wire [`ROB_ID_TYPE] rob_id_from_dispatcher,
    
    // to if
    output wire full_signal,

    // to ls ex
    output reg enable_signal_to_lsu,
    output reg [`OPENUM_TYPE] openum_to_lsu,
    output reg [`ADDR_TYPE] mem_address_to_lsu,
    output reg [`DATA_TYPE] stored_data,
    // to cdb
    output reg [`ROB_ID_TYPE] rob_id_to_LS_unit_cdb,

    // from ls ex
    input wire busy_signal_from_lsu,

    // update when commit
    // from rob
    input wire commit_signal,
    input wire [`ROB_ID_TYPE] commit_rob_id_from_rob,
    input wire [`ROB_ID_TYPE] io_rob_id_from_rob,

    // from rs cdb
    input wire valid_signal_from_Arith_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_Arith_unit_cdb,
    input wire [`DATA_TYPE] result_from_Arith_unit_cdb,

    // from ls cdb
    input wire valid_signal_from_LS_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_LS_unit_cdb,
    input wire [`DATA_TYPE] result_from_LS_unit_cdb,

    // to rob: notify io
    output wire [`ROB_ID_TYPE] io_rob_id_to_rob,

    // jump_flag
    input wire misbranch_flag
);

reg [`LSB_ID_TYPE] head, tail, store_tail;
wire [`LSB_ID_TYPE] next_head, next_tail;

reg [`LSB_SIZE - 1 : 0] LSB_busy;
reg [`ROB_ID_TYPE] LSB_rob_id [`LSB_SIZE - 1 : 0];
reg [`OPENUM_TYPE] LSB_openum [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_Q1 [`LSB_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] LSB_Q2 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_V1 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_V2 [`LSB_SIZE - 1 : 0];
reg [`DATA_TYPE] LSB_imm [`LSB_SIZE - 1 : 0];
reg [`LSB_SIZE - 1 : 0] LSB_is_committed;//for store and IO;

wire [`ADDR_TYPE] mem_address = LSB_V1[head] + LSB_imm[head];


reg [`ROB_POS_TYPE] lsb_element_cnt;
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
assign ls_full_signal = (lsb_element_cnt >= `LSB_SIZE - `FULL_WARNING);
assign insert_cnt = (enable_signal_from_dispatcher ? 1 : 0);

integer i;

wire [`ROB_ID_TYPE] updated_Q1 = (valid_signal_from_Arith_unit_cdb && Q1_from_dispatcher == rob_id_from_Arith_unit_cdb) ? `ZERO_ROB : ((valid_signal_from_LS_unit_cdb && Q1_from_dispatcher == rob_id_from_LS_unit_cdb) ? `ZERO_ROB : Q1_from_dispatcher);
wire [`ROB_ID_TYPE] updated_Q2 = (valid_signal_from_Arith_unit_cdb && Q2_from_dispatcher == rob_id_from_Arith_unit_cdb) ? `ZERO_ROB : ((valid_signal_from_LS_unit_cdb && Q2_from_dispatcher == rob_id_from_LS_unit_cdb) ? `ZERO_ROB : Q2_from_dispatcher);
wire [`DATA_TYPE] updated_V1 = (valid_signal_from_Arith_unit_cdb && Q1_from_dispatcher == rob_id_from_Arith_unit_cdb) ? result_from_Arith_unit_cdb : ((valid_signal_from_LS_unit_cdb && Q1_from_dispatcher == rob_id_from_LS_unit_cdb) ? result_from_LS_unit_cdb : V1_from_dispatcher);
wire [`DATA_TYPE] updated_V2 = (valid_signal_from_Arith_unit_cdb && Q2_from_dispatcher == rob_id_from_Arith_unit_cdb) ? result_from_Arith_unit_cdb : ((valid_signal_from_LS_unit_cdb && Q2_from_dispatcher == rob_id_from_LS_unit_cdb) ? result_from_LS_unit_cdb : V2_from_dispatcher);

//for vcd:
reg [`ROB_ID_TYPE] debug_Q1, debug_Q2;
reg [`OPENUM_TYPE] debug_openum;

always @(posedge clk) begin
    if (rst || (misbranch_flag && store_tail == `INVALID_LSB)) begin
        lsb_element_cnt <= `ZERO_WORD;
        head <= `ZERO_LSB;
        tail <= `ZERO_LSB;
        store_tail <= `INVALID_LSB;
        for (i = 0; i < `LSB_SIZE; i=i+1) begin
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
        enable_signal_to_lsu <= `FALSE;
    end
    else if (~rdy) begin
    end
    else if (misbranch_flag) begin
        tail <= (store_tail == `LSB_SIZE - 1) ? 0 : store_tail + 1;
        lsb_element_cnt <= ((store_tail > head) ? store_tail - head + 1 : `LSB_SIZE - head + store_tail + 1);
        for (i = 0; i < `LSB_SIZE; i = i+1)
            if (LSB_is_committed[i] == `FALSE || LSB_openum[i] <= `OPENUM_LHU) 
                LSB_busy[i] <= `FALSE;
    end
    else begin
        debug_Q1 <= LSB_Q1[head];
        debug_Q2 <= LSB_Q2[head];
        debug_openum <= LSB_openum[head];
        enable_signal_to_lsu <= `FALSE;
        lsb_element_cnt <= lsb_element_cnt + insert_cnt + issue_cnt;

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
                    if (store_tail == head) begin
                        store_tail <= `INVALID_LSB;
                    end  
                end 
            end
        end

        //cdb update:
        if (valid_signal_from_Arith_unit_cdb) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (LSB_Q1[i] == rob_id_from_Arith_unit_cdb) begin
                    LSB_V1[i] <= result_from_Arith_unit_cdb;
                    LSB_Q1[i] <= `ZERO_ROB;
                end
                if (LSB_Q2[i] == rob_id_from_Arith_unit_cdb) begin
                    LSB_V2[i] <= result_from_Arith_unit_cdb;
                    LSB_Q2[i] <= `ZERO_ROB;
                end
            end
        end
        if (valid_signal_from_LS_unit_cdb) begin
            for (i = 0; i < `LSB_SIZE; i = i + 1) begin
                if (LSB_Q1[i] == rob_id_from_LS_unit_cdb) begin
                    LSB_V1[i] <= result_from_LS_unit_cdb;
                    LSB_Q1[i] <= `ZERO_ROB;
                end
                if (LSB_Q2[i] == rob_id_from_LS_unit_cdb) begin
                    LSB_V2[i] <= result_from_LS_unit_cdb;
                    LSB_Q2[i] <= `ZERO_ROB;
                end
            end
        end

        //commit update:
        if (commit_signal) begin
            for (i = 0; i < `LSB_SIZE; i=i+1) begin
                if (LSB_busy[i] && LSB_rob_id[i] == commit_rob_id_from_rob && !LSB_is_committed[i]) begin
                    LSB_is_committed[i] <= `TRUE;
                    if (LSB_openum[i] >= `OPENUM_SB) begin
                        store_tail <= i;
                    end
                end
            end
        end
    end
end

endmodule