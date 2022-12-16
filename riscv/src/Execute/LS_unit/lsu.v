`include "/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

module lsu(
    input wire clk,
    input wire rst,
    input wire rdy,

    //port with LSB:
    input wire enable_signal_from_LSB,
    input wire [`OPENUM_TYPE] openum_from_LSB,
    input wire [`ADDR_TYPE] address_from_LSB,
    input wire [`DATA_TYPE] data_from_LSB,
    output wire busy_signal_to_LSB,

    //port with memCtrl:
    input wire finish_flag_from_memctrl,
    input wire [`DATA_TYPE] data_from_memctrl,
    output reg enable_signal_to_memctrl,
    output reg read_or_write_flag_to_memctrl,
    output reg [2:0] size_to_memctrl,
    output reg [`ADDR_TYPE] address_to_memctrl,
    output reg [`DATA_TYPE] data_to_memctrl,

    //port to cdb:
    output reg valid_signal_to_cdb,
    output reg [`DATA_TYPE] result_to_cdb
);

localparam STATUS_IDLE = 0, STATUS_LB = 1, STATUS_LH = 2, STATUS_LW = 3,
STATUS_LBU = 4, STATUS_LHU = 5, STATUS_STORE = 6;


reg [`STATUS_TYPE] status;
assign busy_signal_to_LSB = (status != STATUS_IDLE || enable_signal_from_LSB);

always @(posedge clk) begin
    if(rst) begin
        enable_signal_to_memctrl <= `FALSE;
        valid_signal_to_cdb <= `FALSE;
        status <= STATUS_IDLE;
    end else if(!rdy) begin
    end 
    else begin
        if(status == STATUS_IDLE) begin
            valid_signal_to_cdb <= `FALSE;
            if(enable_signal_from_LSB) begin
                case (openum_from_LSB)
                    `OPENUM_NOP: begin
                        enable_signal_to_memctrl <= `FALSE;
                        read_or_write_flag_to_memctrl <= `FALSE;
                        size_to_memctrl <= 0;
                        address_to_memctrl <= `ZERO_WORD;
                        data_to_memctrl <= `ZERO_WORD;
                        status <= STATUS_IDLE;
                    end
                    `OPENUM_LB: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `READ_FLAG;
                        size_to_memctrl <= 1;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= `ZERO_WORD;
                        status <= STATUS_LB;
                    end
                    `OPENUM_LH: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `READ_FLAG;
                        size_to_memctrl <= 2;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= `ZERO_WORD;
                        status <= STATUS_LH;
                    end
                    `OPENUM_LW: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `READ_FLAG;
                        size_to_memctrl <= 4;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= `ZERO_WORD;
                        status <= STATUS_LW;
                    end
                    `OPENUM_LBU: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `READ_FLAG;
                        size_to_memctrl <= 1;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= `ZERO_WORD;
                        status <= STATUS_LBU;
                    end
                    `OPENUM_LHU: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `READ_FLAG;
                        size_to_memctrl <= 2;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= `ZERO_WORD;
                        status <= STATUS_LHU;
                    end
                    `OPENUM_SB: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `WRITE_FLAG;
                        size_to_memctrl <= 1;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= data_from_LSB;
                        status <= STATUS_STORE;
                    end
                    `OPENUM_SH: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `WRITE_FLAG;
                        size_to_memctrl <= 2;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= data_from_LSB;
                        status <= STATUS_STORE;
                    end
                    `OPENUM_SH: begin
                        enable_signal_to_memctrl <= `TRUE;
                        read_or_write_flag_to_memctrl <= `WRITE_FLAG;
                        size_to_memctrl <= 4;
                        address_to_memctrl <= address_from_LSB;
                        data_to_memctrl <= data_from_LSB;
                        status <= STATUS_STORE;
                    end
                endcase
            end
        end
        else begin
            enable_signal_to_memctrl <= `FALSE;
            if(finish_flag_from_memctrl) begin
                status <= STATUS_IDLE;
                if(status != STATUS_STORE) begin
                    case (status)
                        //更新load后的新值：
                        STATUS_LB: begin
                            valid_signal_to_cdb <= `TRUE;
                            result_to_cdb <= {{24{data_from_memctrl[7]}}, data_from_memctrl[7:0]};
                        end
                        STATUS_LH: begin
                            valid_signal_to_cdb <= `TRUE;
                            result_to_cdb <= {{16{data_from_memctrl[15]}}, data_from_memctrl[15:0]};
                        end
                        STATUS_LW: begin
                            valid_signal_to_cdb <= `TRUE;
                            result_to_cdb <= data_from_memctrl;
                        end
                        STATUS_LBU: begin
                            valid_signal_to_cdb <= `TRUE;
                            result_to_cdb <= {24'b0, data_from_memctrl[7:0]};
                        end
                        STATUS_LHU: begin
                            valid_signal_to_cdb <= `TRUE;
                            result_to_cdb <= {16'b0, data_from_memctrl[15:0]};
                        end
                    endcase
                end
            end
        end
    end
end

endmodule