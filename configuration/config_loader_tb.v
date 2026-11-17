// Testbench for config_loader.v
// Inputs change on the falling edge; the DUT samples on the rising edge

`timescale 1ns / 1ps

module config_loader_tb;

    reg clk = 1'b0;
    reg rst;
    reg en;
    reg serial_in;
    wire [15:0] config_word;
    wire word_valid;

    integer errors      = 0;
    integer valid_count = 0;
    integer i;

    config_loader dut (
        .clk(clk), .rst(rst), .en(en), .serial_in(serial_in), .config_word(config_word), .word_valid(word_valid)
    );

    always #5 clk = ~clk;

    always @(posedge clk) if (word_valid) valid_count = valid_count + 1;

    task send_bits;
        input [15:0] w;
        input integer nbits;
        begin
            for (i = 15; i > 15 - nbits; i = i - 1) begin
                @(negedge clk);
                en = 1'b1; serial_in = w[i];
            end
        end
    endtask

    task idle;
        input integer n;
        begin
            repeat (n) begin
                @(negedge clk);
                en = 1'b0; serial_in = 1'b0;
            end
        end
    endtask

    task expect_count;
        input integer n;
        begin
            if (valid_count !== n) begin
                $display("FAIL: %0d word_valid pulse(s) so far, expected %0d", valid_count, n);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("config_loader_tb.vcd");
        $dumpvars(0, config_loader_tb);

        rst = 1'b1; en = 1'b0; serial_in = 1'b0;
        @(negedge clk); @(negedge clk);
        rst = 1'b0;
        idle(2);

        // Test 1: spec example 1010 1100 0011 1101 -> 16'hAC3D
        send_bits(16'hAC3D, 16);
        @(negedge clk); en = 1'b0;
        if (!word_valid || config_word !== 16'hAC3D) begin
            $display("FAIL test 1: valid=%b word=%h", word_valid, config_word);
            errors = errors + 1;
        end
        @(negedge clk);
        if (word_valid) begin
            $display("FAIL test 1: word_valid longer than one cycle");
            errors = errors + 1;
        end
        expect_count(1);
        $display("Test 1 (spec example AC3D) done");
        idle(3);

        // Test 2: two words back-to-back, en held high for 32 cycles
        send_bits(16'h1234, 16);
        send_bits(16'hBEEF, 16);
        idle(2);
        expect_count(3);
        if (config_word !== 16'hBEEF) begin
            $display("FAIL test 2: last word %h, expected BEEF", config_word);
            errors = errors + 1;
        end
        $display("Test 2 (back-to-back words) done");
        idle(3);

        // Test 3: incomplete word (7 bits) is ignored 
        send_bits(16'hFFFF, 7);
        idle(2);
        expect_count(3); 
        if (config_word !== 16'hBEEF) begin
            $display("FAIL test 3: config_word changed to %h on an incomplete word", config_word);
            errors = errors + 1;
        end
        send_bits(16'h0F0F, 16);
        idle(2);
        expect_count(4);
        if (config_word !== 16'h0F0F) begin
            $display("FAIL test 3: word after incomplete one = %h, expected 0F0F", config_word);
            errors = errors + 1;
        end
        $display("Test 3 (incomplete word discarded) done");
        idle(3);

        // Test 4: reset in the middle of a word 
        send_bits(16'hAAAA, 9);
        @(negedge clk); rst = 1'b1; en = 1'b0;
        @(negedge clk); rst = 1'b0;
        if (config_word !== 16'h0000 || word_valid !== 1'b0) begin
            $display("FAIL test 4: after reset word=%h valid=%b", config_word, word_valid);
            errors = errors + 1;
        end
        send_bits(16'h5A5A, 16);
        idle(2);
        expect_count(5);
        if (config_word !== 16'h5A5A) begin
            $display("FAIL test 4: word after reset = %h, expected 5A5A", config_word);
            errors = errors + 1;
        end
        $display("Test 4 (reset mid-word) done");
        idle(3);

        if (errors == 0) $display("ALL CONFIG_LOADER TESTS PASSED");
        else $display("CONFIG_LOADER TESTS FAILED: %0d error(s)", errors);
        #20 $finish;
    end

endmodule
