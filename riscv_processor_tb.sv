
`timescale 1ns / 1ps

module riscv_processor_tb;

    logic clk;
    logic reset;

    integer i;
    integer errors;

    // Instantiate the processor
    riscv_processor dut (
        .clk   (clk),
        .reset (reset)
    );

    // 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---------------------------------------------------------
    // Check a register value
    // ---------------------------------------------------------
    task automatic check_reg(
        input integer reg_index,
        input logic [31:0] expected
    );
        begin
            if (dut.registers[reg_index] !== expected) begin
                $display(
                    "FAIL: x%0d expected %0d (0x%08h), got %0d (0x%08h)",
                    reg_index,
                    expected,
                    expected,
                    dut.registers[reg_index],
                    dut.registers[reg_index]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: x%0d = %0d (0x%08h)",
                    reg_index,
                    dut.registers[reg_index],
                    dut.registers[reg_index]
                );
            end
        end
    endtask

    // ---------------------------------------------------------
    // Check a data-memory word
    // ---------------------------------------------------------
    task automatic check_mem(
        input integer word_index,
        input logic [31:0] expected
    );
        begin
            if (dut.data_mem[word_index] !== expected) begin
                $display(
                    "FAIL: data_mem[%0d] expected %0d, got %0d",
                    word_index,
                    expected,
                    dut.data_mem[word_index]
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "PASS: data_mem[%0d] = %0d",
                    word_index,
                    dut.data_mem[word_index]
                );
            end
        end
    endtask

    // ---------------------------------------------------------
    // Initialize memories and load the test program
    // ---------------------------------------------------------
    initial begin

        errors = 0;
        reset  = 1'b1;

        // Fill instruction memory with NOPs
        for (i = 0; i < 256; i = i + 1) begin
            dut.instruction_mem[i] = 32'h00000013;
            dut.data_mem[i]        = 32'd0;
        end

        // Program begins at address 0.
        // Each instruction is 32 bits (4 bytes).

        // 0:  x1 = 5
        dut.instruction_mem[0]  = 32'h00500093; // ADDI x1,x0,5

        // 1:  x2 = 7
        dut.instruction_mem[1]  = 32'h00700113; // ADDI x2,x0,7

        // 2:  x3 = x1 + x2 = 12
        dut.instruction_mem[2]  = 32'h002081B3; // ADD x3,x1,x2

        // 3:  x4 = x3 - x1 = 7
        dut.instruction_mem[3]  = 32'h40118233; // SUB x4,x3,x1

        // 4:  x5 = x3 AND x2 = 4
        dut.instruction_mem[4]  = 32'h0021F2B3; // AND x5,x3,x2

        // 5:  x6 = x1 OR x2 = 7
        dut.instruction_mem[5]  = 32'h0020E333; // OR x6,x1,x2

        // 6:  x7 = x3 XOR x1 = 9
        dut.instruction_mem[6]  = 32'h0011C3B3; // XOR x7,x3,x1

        // 7:  data_mem[0] = x3 = 12
        dut.instruction_mem[7]  = 32'h00302023; // SW x3,0(x0)

        // 8:  x8 = data_mem[0] = 12
        dut.instruction_mem[8]  = 32'h00002403; // LW x8,0(x0)

        // 9:  x9 = x8 + x1 = 17
        //     Immediate load-use dependency: must stall
        dut.instruction_mem[9]  = 32'h001404B3; // ADD x9,x8,x1

        // 10: x10 = 1
        dut.instruction_mem[10] = 32'h00100513; // ADDI x10,x0,1

        // 11: BEQ x10,x10,+8; skip instruction 12
        dut.instruction_mem[11] = 32'h00A50463;

        // 12: Must be skipped
        dut.instruction_mem[12] = 32'h06300593; // ADDI x11,x0,99

        // 13: x11 = 42
        dut.instruction_mem[13] = 32'h02A00593; // ADDI x11,x0,42

        // 14: BNE x10,x0,+8; skip instruction 15
        dut.instruction_mem[14] = 32'h00051463;

        // 15: Must be skipped
        dut.instruction_mem[15] = 32'h06300613; // ADDI x12,x0,99

        // 16: x12 = 13
        dut.instruction_mem[16] = 32'h00D00613; // ADDI x12,x0,13

        // 17: JAL x13,+8
        //     x13 receives PC+4 = 72
        //     Skip instruction 18
        dut.instruction_mem[17] = 32'h008006EF;

        // 18: Must be skipped
        dut.instruction_mem[18] = 32'h06300713; // ADDI x14,x0,99

        // 19: x14 = 14
        dut.instruction_mem[19] = 32'h00E00713; // ADDI x14,x0,14

        // 20: JAL x0,0 - loop here
        dut.instruction_mem[20] = 32'h0000006F;

        // -----------------------------------------------------
        // Reset the processor
        // -----------------------------------------------------

        repeat (2) @(negedge clk);
        reset = 1'b0;

        // Allow the program to execute and reach its loop
        repeat (60) @(negedge clk);

        // Small settling delay before checking results
        #1;

        $display("");
        $display("====================================");
        $display("       REGISTER TEST RESULTS");
        $display("====================================");

        check_reg(0,  32'd0);
        check_reg(1,  32'd5);
        check_reg(2,  32'd7);
        check_reg(3,  32'd12);
        check_reg(4,  32'd7);
        check_reg(5,  32'd4);
        check_reg(6,  32'd7);
        check_reg(7,  32'd9);
        check_reg(8,  32'd12);
        check_reg(9,  32'd17);
        check_reg(10, 32'd1);
        check_reg(11, 32'd42);
        check_reg(12, 32'd13);
        check_reg(13, 32'd72);
        check_reg(14, 32'd14);

        $display("");
        $display("====================================");
        $display("        MEMORY TEST RESULTS");
        $display("====================================");

        check_mem(0, 32'd12);

        $display("");
        $display("====================================");

        if (errors == 0) begin
            $display("ALL TESTS PASSED!");
            $display("Total errors: 0");
            $display("====================================");
            $finish;
        end
        else begin
            $display("TESTS FAILED!");
            $display("Total errors: %0d", errors);
            $display("====================================");
            $fatal(1, "Processor verification failed");
        end

    end

endmodule
