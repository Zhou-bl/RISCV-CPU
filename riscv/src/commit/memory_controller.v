`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
module memory_controller(
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with ram
    input wire io_buffer_full_signal,
    input wire [`MEMPORT_TYPE] input_byte_from_ram,
    output reg read_or_write_flag_to_ram,
    output reg [`ADDR_TYPE] access_address_to_ram,
    output reg [`MEMPORT_TYPE] output_byte_to_ram,

    //port with if:
    input wire [`ADDR_TYPE] pc_from_if,
    input wire start_query_signal,
    input wire stop_signal,
    output reg finish_query_signal,
    output reg [`INST_TYPE] output_inst_to_if,

    //port with lsu:
    input wire [`ADDR_TYPE] access_address_from_ls_ex,
    input wire [`DATA_TYPE] write_data_from_ls_ex,
    input wire start_access_mem_signal,
    input wire read_or_write_flag_from_ls_ex,
    input wire [2:0] rw_length_from_ls_ex,
    output reg finish_rw_flag_to_ls_ex,
    output reg [`DATA_TYPE] load_data_to_ls_ex
);

//define IF message:
parameter STATUS_IDLE = 0, STATUS_FETCH = 1, STATUS_LOAD = 2, STATUS_STORE = 3;

//因为instruction fetch和ls可能同时到达，需要缓存一下脉冲数据。
//buffered IF message:
reg buffered_start_query_signal;
reg [`ADDR_TYPE] buffered_pc_from_if;
//buffer ls_ex message:
reg buffered_start_access_mem_signal;
reg buffered_read_or_write_flag_from_ls_ex;
reg [2: 0] buffered_rw_length_from_ls_ex;
reg [`ADDR_TYPE] buffered_access_address_from_ls_ex;
reg [`ADDR_TYPE] buffered_write_data_from_ls_ex;
reg uart_write_is_io, uart_write_lock;
reg [`STATUS_TYPE] status;
reg [`INT_TYPE] ram_access_cnt, ram_access_size;
reg [`ADDR_TYPE] ram_access_pc;
reg [`DATA_TYPE] writing_data;

reg ena_output_status, ena_output_fetch_valid, ena_output_ls_valid;

wire [`STATUS_TYPE] status_magic = (ena_output_status) ? STATUS_IDLE : status;
wire buf_fetch_valid_magic = (ena_output_fetch_valid) ? `FALSE : buffered_start_query_signal;
wire buf_ls_valid_magic = (ena_output_ls_valid) ? `FALSE : buffered_start_access_mem_signal;

always @(posedge clk) begin
    if (rst == `TRUE) begin
        status <= STATUS_IDLE;
        ram_access_cnt <= `ZERO_WORD;
        ram_access_size <= `ZERO_WORD;
        ram_access_pc <= `ZERO_ADDR;
        buffered_start_query_signal <= `FALSE;
        buffered_start_access_mem_signal <= `FALSE;
        output_inst_to_if <= `ZERO_ADDR;
        load_data_to_ls_ex <= `ZERO_WORD;
        uart_write_is_io <= `FALSE;
        uart_write_lock <= `FALSE;
    end
    else if (~rdy) begin
    end
    else begin
        finish_query_signal <= `FALSE;
        finish_rw_flag_to_ls_ex <= `FALSE;
        
        access_address_to_ram <= `ZERO_ADDR;
        read_or_write_flag_to_ram <= `READ_FLAG;

        if (ena_output_status) status <= STATUS_IDLE;
        if (ena_output_fetch_valid) buffered_start_query_signal <= `FALSE;
        if (ena_output_ls_valid) buffered_start_access_mem_signal <= `FALSE;

        //buffered the query from instruction or lsu:
        if (status_magic != STATUS_IDLE || (start_access_mem_signal && start_query_signal)) begin
            if (start_query_signal == `FALSE && start_access_mem_signal == `TRUE) begin
                buffered_start_access_mem_signal <= `TRUE;
                buffered_read_or_write_flag_from_ls_ex <= read_or_write_flag_from_ls_ex;
                buffered_access_address_from_ls_ex <= access_address_from_ls_ex;
                buffered_write_data_from_ls_ex <= write_data_from_ls_ex;
                buffered_rw_length_from_ls_ex <= rw_length_from_ls_ex;
            end
            else if (start_query_signal == `TRUE) begin
                buffered_start_query_signal <= `TRUE;
                buffered_pc_from_if <= pc_from_if;
            end
        end

        if (status_magic == STATUS_IDLE) begin 
            finish_query_signal <= `FALSE;
            finish_rw_flag_to_ls_ex <= `FALSE;
            output_inst_to_if <= `ZERO_ADDR;
            load_data_to_ls_ex <= `ZERO_WORD;
            if (start_access_mem_signal == `TRUE) begin
                if (read_or_write_flag_from_ls_ex == `WRITE_FLAG) begin
                    ram_access_cnt <= `ZERO_WORD;
                    ram_access_size <= rw_length_from_ls_ex;
                    writing_data <= write_data_from_ls_ex;
                    access_address_to_ram <= `ZERO_ADDR;
                    ram_access_pc <= access_address_from_ls_ex;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    uart_write_is_io <= (access_address_from_ls_ex == `RAM_IO_ADDRESS);
                    uart_write_lock <= `FALSE;
                    status <= STATUS_STORE;
                end
                else if (read_or_write_flag_from_ls_ex == `READ_FLAG) begin
                    ram_access_cnt <= `ZERO_WORD;
                    ram_access_size <= rw_length_from_ls_ex;
                    access_address_to_ram <= access_address_from_ls_ex;
                    ram_access_pc <= access_address_from_ls_ex + 32'h1;
                    read_or_write_flag_to_ram <= `READ_FLAG;
                    status <= STATUS_LOAD;
                end
            end
            else if (buf_ls_valid_magic) begin
                if (buffered_read_or_write_flag_from_ls_ex == `WRITE_FLAG) begin
                    ram_access_cnt <= `ZERO_WORD;
                    ram_access_size <= buffered_rw_length_from_ls_ex;
                    writing_data <= buffered_write_data_from_ls_ex;
                    access_address_to_ram <= `ZERO_ADDR;
                    ram_access_pc <= buffered_access_address_from_ls_ex;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    status <= STATUS_STORE;
                end    
                else if (buffered_read_or_write_flag_from_ls_ex == `READ_FLAG) begin
                    ram_access_cnt <= `ZERO_WORD;
                    ram_access_size <= buffered_rw_length_from_ls_ex;
                    access_address_to_ram <= buffered_access_address_from_ls_ex;
                    ram_access_pc <= buffered_access_address_from_ls_ex + 32'h1;
                    read_or_write_flag_to_ram <= `READ_FLAG;
                    status <= STATUS_LOAD;
                end
                buffered_start_access_mem_signal <= `FALSE;
            end
            else if (start_query_signal == `TRUE) begin
                ram_access_cnt <= `ZERO_WORD;
                ram_access_size <= 32'h4;
                access_address_to_ram <= pc_from_if;
                ram_access_pc <= pc_from_if + 32'h1;
                read_or_write_flag_to_ram <= `READ_FLAG;
                status <= STATUS_FETCH;
            end
            else if (buf_fetch_valid_magic) begin
                ram_access_cnt <= `ZERO_WORD;
                ram_access_size <= 32'h4;
                access_address_to_ram <= buffered_pc_from_if;
                ram_access_pc <= buffered_pc_from_if + 32'h1;
                read_or_write_flag_to_ram <= `READ_FLAG;
                status <= STATUS_FETCH;
                buffered_start_query_signal <= `FALSE;
            end
        end
        else if (!(io_buffer_full_signal && status_magic == STATUS_STORE)) begin
            if (status_magic == STATUS_FETCH) begin
                access_address_to_ram <= ram_access_pc;
                read_or_write_flag_to_ram <= `READ_FLAG;
                case (ram_access_cnt)
                    32'h1:  output_inst_to_if[7:0] <= input_byte_from_ram;
                    32'h2:  output_inst_to_if[15:8] <= input_byte_from_ram;
                    32'h3:  output_inst_to_if[23:16] <= input_byte_from_ram;
                    32'h4:  output_inst_to_if[31:24] <= input_byte_from_ram;
                endcase
                ram_access_pc <= (ram_access_cnt >= ram_access_size - 32'h1) ? `ZERO_ADDR : ram_access_pc + 32'h1;
                if (ram_access_cnt == ram_access_size) begin
                    finish_query_signal <= ~stop_signal;
                    status <= STATUS_IDLE;
                    ram_access_pc <= `ZERO_ADDR;
                    ram_access_cnt <= `ZERO_WORD;
                end
                else begin
                    ram_access_cnt <= ram_access_cnt + 32'h1;
                end
            end
            else if (status_magic == STATUS_LOAD) begin
                access_address_to_ram <= ram_access_pc;
                read_or_write_flag_to_ram <= `READ_FLAG;
                case (ram_access_cnt)
                    32'h1:  load_data_to_ls_ex[7:0] <= input_byte_from_ram;
                    32'h2:  load_data_to_ls_ex[15:8] <= input_byte_from_ram;
                    32'h3:  load_data_to_ls_ex[23:16] <= input_byte_from_ram;
                    32'h4:  load_data_to_ls_ex[31:24] <= input_byte_from_ram;
                endcase
                ram_access_pc <= (ram_access_cnt >= ram_access_size - 1) ? `ZERO_ADDR : ram_access_pc + 1;

                if (ram_access_cnt == ram_access_size) begin
                    finish_rw_flag_to_ls_ex <= ~stop_signal;
                    status <= STATUS_IDLE;
                    ram_access_pc <= `ZERO_ADDR;
                    ram_access_cnt <= 0;
                end
                else begin
                    ram_access_cnt <= ram_access_cnt + 1;
                end
            end
            else if (status_magic == STATUS_STORE) begin
                if (uart_write_is_io == `FALSE || ~uart_write_lock) begin
                    uart_write_lock <= `TRUE;
                    access_address_to_ram <= ram_access_pc;
                    read_or_write_flag_to_ram <= `WRITE_FLAG;
                    case (ram_access_cnt)
                        32'h0:  output_byte_to_ram <= writing_data[7:0];
                        32'h1:  output_byte_to_ram <= writing_data[15:8];
                        32'h2:  output_byte_to_ram <= writing_data[23:16];
                        32'h3:  output_byte_to_ram <= writing_data[31:24];
                    endcase
                    ram_access_pc <= (ram_access_cnt >= ram_access_size - 32'h1) ? `ZERO_ADDR : ram_access_pc + 32'h1;
                    if (ram_access_cnt == ram_access_size) begin
                        finish_rw_flag_to_ls_ex <= `TRUE;
                        status <= STATUS_IDLE;
                        ram_access_pc <= `ZERO_ADDR;
                        ram_access_cnt <= `ZERO_WORD;
                        access_address_to_ram <= `ZERO_ADDR;
                        read_or_write_flag_to_ram <= `READ_FLAG;
                    end
                    else begin
                        ram_access_cnt <= ram_access_cnt + 32'h1;
                    end
                end
                else begin
                    uart_write_lock <= `FALSE;
                end
            end
        end
    end
end

always @(*) begin
    ena_output_status = `FALSE;
    ena_output_ls_valid = `FALSE;
    ena_output_fetch_valid = `FALSE;

    if (stop_signal) begin
        if (status == STATUS_FETCH || status == STATUS_LOAD) begin
            ena_output_status = `TRUE;
        end
        ena_output_fetch_valid = `TRUE;
        if (buffered_start_access_mem_signal == `TRUE && buffered_read_or_write_flag_from_ls_ex == `READ_FLAG) begin
            ena_output_ls_valid = `TRUE;
        end
    end
end

endmodule