`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

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
    output reg [`ADDR_TYPE] pc_to_alu,

    //port with cdb:
    input wire valid_signal_from_Arith_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_Arith_unit_cdb,
    input wire [`DATA_TYPE] result_from_Arith_unit_cdb,
    output reg [`ROB_ID_TYPE] rob_id_to_Arith_unit_cdb,

    input wire valid_signal_from_LS_unit_cdb,
    input wire [`ROB_ID_TYPE] rob_id_from_LS_unit_cdb,
    input wire [`DATA_TYPE] result_from_LS_unit_cdb,

    //full signal:
    output wire full_signal,
    input wire misbranch_flag
);
// 16-size reserve station:
reg [`RS_SIZE - 1 : 0] RS_busy;
reg [`ROB_ID_TYPE] RS_rob_id [`RS_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] RS_Q1 [`RS_SIZE - 1 : 0];
reg [`ROB_ID_TYPE] RS_Q2 [`RS_SIZE - 1 : 0];
reg [`DATA_TYPE] RS_V1 [`RS_SIZE - 1 : 0];
reg [`DATA_TYPE] RS_V2 [`RS_SIZE - 1 : 0];
reg [`DATA_TYPE] RS_imm [`RS_SIZE - 1 : 0];
reg [`ADDR_TYPE] RS_pc [`RS_SIZE - 1 : 0];
reg [`OPENUM_TYPE] RS_openum [`RS_SIZE - 1 : 0];

integer i;
wire [`RS_ID_TYPE] free_index;
wire [`RS_ID_TYPE] next_to_alu_index;
wire full = (free_index == `INVALID_RS);
assign full_signal = full;
wire [`ROB_ID_TYPE] updated_Q1, updated_Q2;
wire [`DATA_TYPE] updated_V1, updated_V2;

integer debug_cnt = 0;

//更新最新的Q1,Q2,V1,V2:
//因为某条指令j在dispatch中时，它的上一条指令i在RS中，当j在RS中时，i在ALU中计算出来了结果，需要对其更新
assign updated_Q1 = (valid_signal_from_Arith_unit_cdb && Q1_from_dispatcher == rob_id_from_Arith_unit_cdb) ? 
`ZERO_ROB : ((valid_signal_from_LS_unit_cdb && Q1_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
`ZERO_ROB : Q1_from_dispatcher);

assign updated_Q2 = (valid_signal_from_Arith_unit_cdb && Q2_from_dispatcher == rob_id_from_Arith_unit_cdb) ? 
`ZERO_ROB : ((valid_signal_from_LS_unit_cdb && Q2_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
`ZERO_ROB : Q2_from_dispatcher);

assign updated_V1 = (valid_signal_from_Arith_unit_cdb && Q1_from_dispatcher == rob_id_from_Arith_unit_cdb) ?
result_from_Arith_unit_cdb : ((valid_signal_from_LS_unit_cdb && Q1_from_dispatcher == rob_id_from_LS_unit_cdb ?
result_from_LS_unit_cdb : V1_from_dispatcher));

assign updated_V2 = (valid_signal_from_Arith_unit_cdb && Q2_from_dispatcher == rob_id_from_Arith_unit_cdb) ?
result_from_Arith_unit_cdb : ((valid_signal_from_LS_unit_cdb && Q2_from_dispatcher == rob_id_from_LS_unit_cdb) ? 
result_from_LS_unit_cdb : V2_from_dispatcher);

//利用状态机的思想寻找空闲的位置：
assign free_index = 
(!RS_busy[0] ? 0 : 
(!RS_busy[1] ? 1 : 
(!RS_busy[2] ? 2 : 
(!RS_busy[3] ? 3 :
(!RS_busy[4] ? 4 :
(!RS_busy[5] ? 5 :
(!RS_busy[6] ? 6 :
(!RS_busy[7] ? 7 :
(!RS_busy[8] ? 8 :
(!RS_busy[9] ? 9 :
(!RS_busy[10] ? 10 :
(!RS_busy[11] ? 11 :
(!RS_busy[12] ? 12 :
(!RS_busy[13] ? 13 :
(!RS_busy[14] ? 14 :
(!RS_busy[15] ? 15 :
(`INVALID_RS)))))))))))))))));

//在RS中选择操作数都可用的指令：
assign next_to_alu_index =
(RS_busy[0] && RS_Q1[0] == `ZERO_ROB && RS_Q2[0] == `ZERO_ROB ? 0 :
(RS_busy[1] && RS_Q1[1] == `ZERO_ROB && RS_Q2[1] == `ZERO_ROB ? 1 : 
(RS_busy[2] && RS_Q1[2] == `ZERO_ROB && RS_Q2[2] == `ZERO_ROB ? 2 :
(RS_busy[3] && RS_Q1[3] == `ZERO_ROB && RS_Q2[3] == `ZERO_ROB ? 3 :
(RS_busy[4] && RS_Q1[4] == `ZERO_ROB && RS_Q2[4] == `ZERO_ROB ? 4 : 
(RS_busy[5] && RS_Q1[5] == `ZERO_ROB && RS_Q2[5] == `ZERO_ROB ? 5 :
(RS_busy[6] && RS_Q1[6] == `ZERO_ROB && RS_Q2[6] == `ZERO_ROB ? 6 : 
(RS_busy[7] && RS_Q1[7] == `ZERO_ROB && RS_Q2[7] == `ZERO_ROB ? 7 :
(RS_busy[8] && RS_Q1[8] == `ZERO_ROB && RS_Q2[8] == `ZERO_ROB ? 8 :
(RS_busy[9] && RS_Q1[9] == `ZERO_ROB && RS_Q2[9] == `ZERO_ROB ? 9 :
(RS_busy[10] && RS_Q1[10] == `ZERO_ROB && RS_Q2[10] == `ZERO_ROB ? 10 :
(RS_busy[11] && RS_Q1[11] == `ZERO_ROB && RS_Q2[11] == `ZERO_ROB ? 11 :
(RS_busy[12] && RS_Q1[12] == `ZERO_ROB && RS_Q2[12] == `ZERO_ROB ? 12 :
(RS_busy[13] && RS_Q1[13] == `ZERO_ROB && RS_Q2[13] == `ZERO_ROB ? 13 :
(RS_busy[14] && RS_Q1[14] == `ZERO_ROB && RS_Q2[14] == `ZERO_ROB ? 14 :
(RS_busy[15] && RS_Q1[15] == `ZERO_ROB && RS_Q2[15] == `ZERO_ROB ? 15 :
(`INVALID_RS)))))))))))))))));

always @(posedge clk) begin
    if(rst || misbranch_flag == `TRUE) begin//clear RS station
        for(i = 0; i <= 15; i = i + 1) begin
            RS_busy <= `FALSE;
            RS_imm[i] <= `ZERO_WORD;
            RS_openum[i] <= `OPENUM_NOP;
            RS_pc[i] <= `ZERO_ADDR;
            RS_Q1[i] <= `ZERO_ROB;
            RS_Q2[i] <= `ZERO_ROB;
            RS_rob_id[i] <= `ZERO_ROB;
            RS_V1[i] <= `ZERO_WORD;
            RS_V2[i] <= `ZERO_WORD;
        end
        //$display("RS_Q1: ", RS_Q1[0]);
    end else if(~rdy) begin 
    end else begin
        //1.监听cdb总线更新RS中的数据
        //2.将从dispatcher传入的指令放入RS中
        //3.将next_to_alu_index所在的指令传到alu中

        if(next_to_alu_index == `INVALID_RS) begin
            openum_to_alu <= `OPENUM_NOP;
        end else begin
            //$display("next_to_alu_index: ", next_to_alu_index);
            //$display("RS_busy: ", RS_busy[0]);
            //$display("RS_Q1: ", RS_Q1[0]);
            openum_to_alu <= openum_from_dispatcher;
            rob_id_to_Arith_unit_cdb <= RS_rob_id[next_to_alu_index];
            RS_busy[next_to_alu_index] <= `FALSE;
            V1_to_alu <= RS_V1[next_to_alu_index];
            V2_to_alu <= RS_V2[next_to_alu_index];
            pc_to_alu <= RS_pc[next_to_alu_index];
            imm_to_alu <= RS_imm[next_to_alu_index];
        end

        if(valid_signal_from_Arith_unit_cdb == `TRUE) begin
            for(i = 0; i <= 15; i = i + 1) begin
                if(RS_Q1[i] == rob_id_from_Arith_unit_cdb) begin
                    RS_Q1[i] <= `ZERO_ROB;
                    RS_V1[i] <= result_from_Arith_unit_cdb;
                end
                if(RS_Q2[i] == rob_id_from_Arith_unit_cdb) begin
                    RS_Q2[i] <= `ZERO_ROB;
                    RS_V2[i] <= result_from_Arith_unit_cdb;
                end
            end
        end
        if(valid_signal_from_LS_unit_cdb == `TRUE) begin
            for(i = 0; i <= 15; i = i + 1) begin
                if(RS_Q1[i] == rob_id_from_LS_unit_cdb) begin
                    RS_Q1[i] <= `ZERO_ROB;
                    RS_V1[i] <= result_from_LS_unit_cdb;
                end
                if(RS_Q2[2] == rob_id_from_LS_unit_cdb) begin
                    RS_Q2[i] <= `ZERO_ROB;
                    RS_V2[i] <= result_from_LS_unit_cdb;
                end
            end
        end

        if(enable_signal_from_dispatcher == `TRUE && free_index != `INVALID_RS) begin
            
            /*
            debug_cnt++;
            $display("cnt : ", debug_cnt);
            $display("valid_signal_from_Arith: ", valid_signal_from_Arith_unit_cdb);
            $display("Q1_from_dispatcher: ", Q1_from_dispatcher);
            $display("rob_id_from_Arith, ", rob_id_from_Arith_unit_cdb);
            $display("valid_signal_from_LS: ", valid_signal_from_LS_unit_cdb);
            $display("Q1_from_LS: ", rob_id_from_LS_unit_cdb);
            $display("");
            */

            RS_busy[free_index] <= `TRUE;
            RS_imm[free_index] <= imm_from_dispatcher;
            RS_openum[free_index] <= openum_from_dispatcher;
            RS_pc[free_index] <= pc_from_dispatcher;
            RS_Q1[free_index] <= updated_Q1;
            RS_Q2[free_index] <= updated_Q2;
            RS_V1[free_index] <= updated_V1;
            RS_V2[free_index] <= updated_V2;
            RS_rob_id[free_index] <= rob_id_from_dispatcher;
        end
    end
end


endmodule