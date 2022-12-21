`include "/mnt/c/Users/zbl/Desktop/RISCV-CPU/riscv/src/constant.v"
//此module的作用是从指令解析出指令的Type, rs1, rs2, rd, imm;
module decoder(
    input wire [`INST_TYPE] input_inst,

    output reg is_jump,
    output reg is_store,
    output reg [`OPENUM_TYPE] openum,
    output reg [`REG_POS_TYPE] rd,
    output reg [`REG_POS_TYPE] rs1,
    output reg [`REG_POS_TYPE] rs2,
    output reg [`DATA_TYPE] imm
);

always @(*) begin
    is_jump <= `FALSE;
    is_store <= `FALSE;
    openum <= `OPENUM_NOP;
    rd <= input_inst[`RD_RANGE];
    rs1 <= input_inst[`RS1_RANGE];
    rs2 <= input_inst[`RS2_RANGE];
    imm <= `ZERO_WORD;

    case (input_inst[`OPCODE_RANGE])

        `OPCODE_LUI, `OPCODE_AUIPC : begin//U-Type
            imm <= {input_inst[31:12], 12'b0};
            rs1 <= `ZERO_REG;
            rs2 <= `ZERO_REG;
            if(input_inst[`OPCODE_RANGE] == `OPCODE_LUI) openum <= `OPENUM_LUI;
            else openum <= `OPENUM_AUIPC;
        end

        `OPCODE_BR : begin//B-Type
            imm <= {{20{input_inst[31]}}, input_inst[7:7], input_inst[30:25], input_inst[11:8], 1'b0};
            is_jump <= `TRUE;
            rd <= `ZERO_REG;
            case (input_inst[`FUNC3_RANGE])
                `FUNC3_BEQ : openum <= `OPENUM_BEQ;
                `FUNC3_BNE : openum <= `OPENUM_BNE;
                `FUNC3_BLT : openum <= `OPENUM_BLT;
                `FUNC3_BGE : openum <= `OPENUM_BGE;
                `FUNC3_BLTU: openum <= `OPENUM_BLTU;
                `FUNC3_BGEU: openum <= `OPENUM_BGEU;
            endcase
        end

        `OPCODE_L, `OPCODE_JALR, `OPCODE_ARITHI : begin//I-Type
            imm <= {{20{input_inst[31]}}, input_inst[31:20]};
            rs2 <= `ZERO_REG;
            case (input_inst[`OPCODE_RANGE])
                `OPCODE_JALR : begin
                    is_jump <= `TRUE;
                    openum <= `OPENUM_JALR;
                end
                `OPCODE_L : begin
                    case (input_inst[`FUNC3_RANGE])
                        `FUNC3_LB : openum <= `OPENUM_LB;
                        `FUNC3_LH : openum <= `OPENUM_LH;
                        `FUNC3_LW : openum <= `OPENUM_LW;
                        `FUNC3_LBU: openum <= `OPENUM_LBU;
                        `FUNC3_LHU: openum <= `OPENUM_LHU;
                    endcase
                end
                `OPCODE_ARITHI : begin
                    case (input_inst[`FUNC3_RANGE])
                        `FUNC3_ADDI : openum <= `OPENUM_ADDI;
                        `FUNC3_SLTI : openum <= `OPENUM_SLTI;
                        `FUNC3_SLTIU: openum <= `OPENUM_SLTIU;
                        `FUNC3_XORI : openum <= `OPENUM_XORI;
                        `FUNC3_ORI : openum <= `OPENUM_ORI;
                        `FUNC3_ANDI: openum <= `OPENUM_ANDI;
                        `FUNC3_SLLI : openum <= `OPENUM_SLLI;
                        `FUNC3_SRLI : begin
                            if(input_inst[`FUNC7_RANGE] == `FUNC7_SPEC) openum <= `OPENUM_SRAI;
                            else openum <= `OPENUM_SRLI;
                        end
                    endcase  
                end
            endcase
        end

        `OPCODE_ARITH : begin//R-Type
            case (input_inst[`FUNC3_RANGE])
                `FUNC3_ADD : begin
                    if(input_inst[`FUNC7_RANGE] == `FUNC7_SPEC) openum <= `OPENUM_SUB;
                    else openum <= `OPENUM_ADD;
                end
                `FUNC3_SLL : openum <= `OPENUM_SLL;
                `FUNC3_SLT : openum <= `OPENUM_SLT;
                `FUNC3_SLTU: openum <= `OPENUM_SLTU;
                `FUNC3_XOR : openum <= `OPENUM_XOR;
                `FUNC3_SRL : begin
                    if(input_inst[`FUNC7_RANGE] == `FUNC7_SPEC) openum <= `OPENUM_SRA;
                    else openum <= `OPENUM_SRL;
                end
                `FUNC3_OR : openum <= `OPENUM_OR;
                `FUNC3_AND : openum <= `OPENUM_AND;
            endcase
        end

        `OPCODE_S : begin//S-Type
            imm <= {{20{input_inst[31]}}, input_inst[31:25], input_inst[11:7]};
            is_store <= `TRUE;
            rd <= `ZERO_REG;
            case (input_inst[`FUNC3_RANGE])
                `FUNC3_SB : openum <= `OPENUM_SB;
                `FUNC3_SH : openum <= `OPENUM_SH;
                `FUNC3_SW : openum <= `OPENUM_SW;
            endcase
        end

        `OPCODE_JAL : begin//J-Type
            imm <= {{12{input_inst[31]}}, input_inst[19:12], input_inst[20], input_inst[30:21], 1'b0};
            is_jump <= `TRUE;
            openum <= `OPENUM_JAL;
        end

        default begin
            imm <= `ZERO_WORD;
            openum <= `OPENUM_NOP;
        end
        
    endcase
end

endmodule