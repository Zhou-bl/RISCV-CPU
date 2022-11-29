`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module memory_controller(
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with RAM:
    input wire uart_full_signal,
    output reg read_or_write_flag_to_ram,
    output reg [`ADDR_TYPE] access_address_to_ram,
    input wire [`MEMPORT_TYPE] input_byte_from_ram,
    output reg [`MEMPORT_TYPE] output_byte_to_ram,

    //port with IF:
    input wire start_query_signal,//脉冲
    input wire [`ADDR_TYPE] pc_from_if,
    output reg finish_query_signal,//脉冲
    output reg [`INST_TYPE] output_inst_to_if,

    //port with ls_ex:
    input wire start_access_mem_signal,//脉冲
    input wire read_or_write_flag_from_ls_ex,//read:0   write:1;
    input wire [2:0] rw_length_from_ls_ex,
    input wire [`ADDR_TYPE] access_address_from_ls_ex,
    input wire [`DATA_TYPE] write_data_from_ls_ex,
    output reg finish_rw_flag_to_ls_ex,
    output reg [`DATA_TYPE] load_data_to_ls_ex
);
//define status:
localparam STATUS_IDLE = 0, STATUS_FETCH = 1, STATUS_LOAD = 2, STATUS_STORE = 3;

//因为instruction fetch和ls可能同时到达，需要缓存一下脉冲数据。
//buffered IF message:
reg buffered_start_query_signal;
reg [`ADDR_TYPE] buffered_pc_from_if;
//buffered ls_ex message:
reg buffered_start_access_mem_signal;
reg buffered_read_or_write_flag_from_ls_ex;
reg [2:0] buffered_rw_length_from_ls_ex;
reg [`ADDR_TYPE] buffered_access_address_from_ls_ex;
reg [`DATA_TYPE] buffered_write_data_from_ls_ex;
//记录当前memCtlr的状态
reg [`STATUS_TYPE] status;
//记录当前正在access第几个字节，总共需要access多少字节
reg [`INT_TYPE] ram_access_cnt, ram_access_size; //cnt = 0 时发出了第一个字节的请求, cnt = ran_access_size - 1 时发出了最后一个字节的请求
//记录当前正在access的字节的位置
reg [`ADDR_TYPE] ram_access_pc;
reg [`DATA_TYPE] stored_data;

always @(posedge clk) begin
    if (rst) begin
        status <= STATUS_IDLE;
        ram_access_cnt <= `ZERO_WORD;
        ram_access_size <= `ZERO_WORD;
        ram_access_pc <= `ZERO_ADDR;
        buffered_start_query_signal <= `FALSE;
        buffered_start_access_mem_signal <= `FALSE;
        output_inst_to_if <= `ZERO_WORD;
        load_data_to_ls_ex <= `ZERO_WORD;
        finish_query_signal <= `FALSE;
        finish_rw_flag_to_ls_ex <= `FALSE;
    end
    else if (~rdy) begin
        finish_query_signal <= `FALSE;
        finish_rw_flag_to_ls_ex <= `FALSE;
    end
    else begin
        if ((status != STATUS_IDLE && start_access_mem_signal) || (status != STATUS_IDLE && start_query_signal)) begin
            //buffer the message:
            if (start_access_mem_signal == `TRUE) begin
                buffered_start_access_mem_signal <= `TRUE;
                buffered_read_or_write_flag_from_ls_ex <= read_or_write_flag_from_ls_ex;
                buffered_rw_length_from_ls_ex <= rw_length_from_ls_ex;
                buffered_access_address_from_ls_ex <= access_address_from_ls_ex;
                buffered_write_data_from_ls_ex <= write_data_from_ls_ex;
            end
            if (start_query_signal == `TRUE) begin
                buffered_start_query_signal <= `TRUE;
                buffered_pc_from_if <= `TRUE;
            end
        end

        if (status == STATUS_IDLE) begin //IDLE
            finish_query_signal <= `FALSE;
            finish_rw_flag_to_ls_ex <= `FALSE;
            output_inst_to_if <= `ZERO_WORD;
            load_data_to_ls_ex <= `ZERO_WORD;

            if (start_access_mem_signal == `TRUE) begin
                if (read_or_write_flag_from_ls_ex == `WRITE_FLAG) begin
                    ram_access_cnt <= 0;
                    ram_access_size <= rw_length_from_ls_ex;
                    ram_access_pc <= access_address_from_ls_ex;
                    stored_data <= write_data_from_ls_ex;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    status <= STATUS_STORE;
                end
                if (read_or_write_flag_from_ls_ex == `READ_FLAG) begin
                    ram_access_cnt <= 0;
                    ram_access_size <= rw_length_from_ls_ex;
                    ram_access_pc <= access_address_from_ls_ex + 1;
                    access_address_to_ram <= access_address_from_ls_ex;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    status <= STATUS_LOAD;
                end
            end
            else if (buffered_start_access_mem_signal == `TRUE) begin
                if (buffered_read_or_write_flag_from_ls_ex == `WRITE_FLAG) begin
                    //设置moule的状态为store, 但是不向ram传送mem access的信号
                    ram_access_cnt <= 0;
                    ram_access_size <= buffered_rw_length_from_ls_ex;
                    ram_access_pc <= buffered_access_address_from_ls_ex;
                    stored_data <= buffered_write_data_from_ls_ex;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    status <= STATUS_STORE;
                end
                if (buffered_read_or_write_flag_from_ls_ex == `READ_FLAG) begin
                    ram_access_cnt <= 0;
                    ram_access_size <= buffered_rw_length_from_ls_ex;
                    ram_access_pc <= buffered_access_address_from_ls_ex + 1;
                    access_address_to_ram <= buffered_access_address_from_ls_ex;
                    read_or_write_flag_to_ram <= `READ_FLAG;
                    status <= STATUS_LOAD;
                end
                buffered_start_access_mem_signal <= `FALSE;
            end
            else if (buffered_start_query_signal == `TRUE) begin
                ram_access_cnt <= 0;
                ram_access_size <= 4;
                ram_access_pc <= buffered_pc_from_if + 1;
                access_address_to_ram <= buffered_pc_from_if;
                read_or_write_flag_to_ram <= `READ_FLAG;
                status <= STATUS_FETCH;
                buffered_start_query_signal <= `FALSE;
            end
        end
        else begin// busy
            if (uart_full_signal == `FALSE) begin
                if (status == STATUS_FETCH) begin
                    access_address_to_ram <= ram_access_pc;
                    read_or_write_flag_to_ram <= `READ_FLAG;
                    case (ram_access_cnt)
                        1 : output_inst_to_if[7 : 0] <= input_byte_from_ram;
                        2 : output_inst_to_if[15 : 8] <= input_byte_from_ram;
                        3 : output_inst_to_if[23 : 16] <= input_byte_from_ram;
                        4 : output_inst_to_if[31 : 24] <= input_byte_from_ram;
                    endcase
                    ram_access_pc <= (ram_access_cnt >= ram_access_size - 1) ? `ZERO_ADDR : ram_access_pc + 1;
                    if (ram_access_cnt == ram_access_size) begin
                        finish_query_signal <= `TRUE;
                        ram_access_pc <= `ZERO_ADDR;
                        ram_access_cnt <= 0;
                        status <= STATUS_IDLE;
                    end else begin ram_access_cnt <= ram_access_cnt + 1; end
                end
                if (status == STATUS_LOAD) begin
                    access_address_to_ram <= ram_access_pc;
                    read_or_write_flag_to_ram <= `READ_FLAG;
                    case (ram_access_cnt)
                        1 : load_data_to_ls_ex[7 : 0] <= input_byte_from_ram;
                        2 : load_data_to_ls_ex[15 : 8] <= input_byte_from_ram;
                        3 : load_data_to_ls_ex[23 : 16] <= input_byte_from_ram;
                        4 : load_data_to_ls_ex[31 : 24] <= input_byte_from_ram;
                    endcase
                    ram_access_pc <= (ram_access_cnt >= ram_access_size - 1) ? `ZERO_WORD : ram_access_pc + 1;
                    if (ram_access_cnt == ram_access_size) begin
                        finish_rw_flag_to_ls_ex <= `TRUE;
                        ram_access_pc <= `ZERO_WORD;
                        ram_access_cnt <= 0;
                        status <= STATUS_IDLE;
                    end else begin ram_access_cnt <= ram_access_cnt + 1; end
                end
                if (status == STATUS_STORE) begin
                    access_address_to_ram <= ram_access_pc;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    case (ram_access_cnt)
                        0 : output_byte_to_ram <= stored_data[7:0];
                        1 : output_byte_to_ram <= stored_data[15:8];
                        2 : output_byte_to_ram <= stored_data[23:16];
                        3 : output_byte_to_ram <= stored_data[31:24];
                    endcase
                    ram_access_pc <= ram_access_cnt >= ram_access_size - 1 ? `ZERO_WORD : ram_access_pc + 1;
                    if (ram_access_cnt == ram_access_size) begin
                        finish_rw_flag_to_ls_ex <= `TRUE;
                        ram_access_pc <= `ZERO_ADDR;
                        ram_access_cnt <= 0;
                        access_address_to_ram <= `ZERO_ADDR;
                        read_or_write_flag_to_ram <= `READ_FLAG;//闲置时改为read mode
                        status <= STATUS_IDLE;
                    end else begin ram_access_cnt <= ram_access_cnt + 1; end
                end
            end
        end
    end
end

endmodule