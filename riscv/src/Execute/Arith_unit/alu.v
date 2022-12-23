`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"

module alu(
    input wire [`OPENUM_TYPE] input_openum,
    input wire [`DATA_TYPE] V1,
    input wire [`DATA_TYPE] V2,
    input wire [`DATA_TYPE] imm,
    input wire [`ADDR_TYPE] input_pc,
    output reg [`DATA_TYPE] output_result,
    output reg [`ADDR_TYPE] output_pc,
    output reg is_jump_flag,
    output reg valid
);

always @(*) begin
    //valid = (input_openum != `OPENUM_NOP);
    
    case (input_openum)
        `OPENUM_LUI:begin
            output_result = imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_AUIPC:begin
            output_result = input_pc + imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_JAL:begin
            output_result = input_pc + 4;
            output_pc = input_pc + imm;
            is_jump_flag = `TRUE;
            valid = `TRUE;
        end
        `OPENUM_JALR:begin
            output_result = input_pc + 4;
            output_pc = V1 + imm;
            is_jump_flag = `TRUE;
            valid = `TRUE;
        end
        `OPENUM_BEQ:begin
            output_result = `ZERO_WORD;
            output_pc = input_pc + imm;
            is_jump_flag = (V1 == V2);
            valid = `TRUE;
        end
        `OPENUM_BNE:begin
            output_result = `ZERO_WORD;
            output_pc = input_pc + imm;
            is_jump_flag = (V1 == V2);
            valid = `TRUE;
        end
        `OPENUM_BLT:begin
            output_result = `ZERO_WORD;
            output_pc = input_pc + imm;
            is_jump_flag = ($signed(V1) < $signed(V2));
            valid = `TRUE;
        end
        `OPENUM_BGE:begin
            output_result = `ZERO_WORD;
            output_pc = input_pc + imm;
            is_jump_flag = ($signed(V1) >= $signed(V2));
            valid = `TRUE;
        end
        `OPENUM_BLTU:begin
            output_result = `ZERO_WORD;
            output_pc = input_pc + imm;
            is_jump_flag = (V1 < V2);
            valid = `TRUE;
        end
        `OPENUM_BGEU:begin
            output_result = `ZERO_WORD;
            output_pc = input_pc + imm;
            is_jump_flag = (V1 >= V2);
            valid = `TRUE;
        end
        `OPENUM_ADD:begin
            output_result = V1 + V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SUB:begin
            output_result = V1 - V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SLL:begin
            output_result = V1 << V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SLT:begin
            output_result = ($signed(V1) < $signed(V2));
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SLTU:begin
            output_result = (V1 < V2);
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_XOR:begin
            output_result = V1 ^ V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SRL:begin
            output_result = V1 >> V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SRA:begin
            output_result = V1 >>> V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_OR:begin
            output_result = V1 | V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_AND:begin
            output_result = V1 & V2;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_ADDI:begin
            output_result = V1 + imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end    
        `OPENUM_SLLI:begin
            output_result = V1 << imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end    
        `OPENUM_SLTI:begin
            output_result = ($signed(V1) < $signed(imm));
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SLTIU:begin
            output_result = (V1 < imm);
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_XORI:begin
            output_result = V1 ^ imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SRLI:begin
            output_result = V1 >> imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_SRAI:begin
            output_result = V1 >>> imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_ORI:begin
            output_result = V1 | imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_ANDI:begin
            output_result = V1 & imm;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `TRUE;
        end
        `OPENUM_NOP:begin
            output_result = `ZERO_WORD;
            output_pc = `ZERO_ADDR;
            is_jump_flag = `FALSE;
            valid = `FALSE;
        end
    endcase
    //$display("valid: ", valid);
end

endmodule