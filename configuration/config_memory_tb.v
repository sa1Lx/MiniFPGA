// Testbench for config_memory.v
// Inputs are changed on the falling edge so they are stable at each rising edge.
`timescale 1ns / 1ps

module config_memory_tb;

    reg clk = 1'b0;
    reg rst;
    reg wr_en;
    reg [4:0] wr_addr;
    reg [15:0] wr_data;
    reg [4:0] rd_addr;
    wire [15:0] rd_data;

    integer errors = 0;
    integer k;

    config_memory dut (
        .clk(clk), .rst(rst),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data),
        .rd_addr(rd_addr), .rd_data(rd_data)
    );

    always #5 clk = ~clk;   // 100 MHz, 10 ns period

    function [15:0] pattern;
        input [4:0] a;
        pattern = {a, 3'b101, ~a, 3'b010};
    endfunction

    task check;
        input [4:0]  a;
        input [15:0] expected;
        begin
            rd_addr = a;
            #1;
            if (rd_data !== expected) begin
                $display("FAIL  addr %0d: read %h, expected %h  (t=%0t)", a, rd_data, expected, $time);
                errors = errors + 1;
            end
        end
    endtask

    task write_word;
        input [4:0]  a;
        input [15:0] d;
        begin
            @(negedge clk);
            wr_en = 1'b1; wr_addr = a; wr_data = d;
            @(negedge clk);
            wr_en = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("config_memory_tb.vcd");
        $dumpvars(0, config_memory_tb);

        rst = 1'b1; wr_en = 1'b0; wr_addr = 5'd0; wr_data = 16'h0000; rd_addr = 5'd0;

        // Test 1: reset clears all 32 words 
        @(negedge clk); @(negedge clk);
        rst = 1'b0;
        for (k = 0; k < 32; k = k + 1) check(k, 16'h0000);
        $display("Test 1 (reset clears memory) done");

        // Test 2: write all 32 words, read them all back
        for (k = 0; k < 32; k = k + 1) write_word(k, pattern(k));
        for (k = 0; k < 32; k = k + 1) check(k, pattern(k));
        $display("Test 2 (write/read all 32 words) done");

        // Test 3: wr_en = 0 must not write
        @(negedge clk);
        wr_en = 1'b0; wr_addr = 5'd7; wr_data = 16'hDEAD;
        @(negedge clk); @(negedge clk);
        check(5'd7, pattern(5'd7));
        $display("Test 3 (no write when wr_en = 0) done");

        // Test 4: overwrite one word, neighbours unchanged
        write_word(5'd10, 16'hAC3D);
        check(5'd10, 16'hAC3D);
        check(5'd9,  pattern(5'd9));
        check(5'd11, pattern(5'd11));
        $display("Test 4 (overwrite) done");

        // Test 5: data retained over many idle cycles
        repeat (20) @(negedge clk);
        check(5'd0,  pattern(5'd0));
        check(5'd31, pattern(5'd31));
        check(5'd10, 16'hAC3D);
        $display("Test 5 (retention) done");

        // Test 6: asynchronous read, rd_addr changes between clock edges
        @(posedge clk); #2;          // mid-cycle, away from any edge
        check(5'd3, pattern(5'd3));
        #1 check(5'd20, pattern(5'd20));
        #1 check(5'd10, 16'hAC3D);
        $display("Test 6 (asynchronous read) done");

        // Test 7: synchronous reset clears everything again
        @(negedge clk); rst = 1'b1;
        @(negedge clk); rst = 1'b0;
        for (k = 0; k < 32; k = k + 1) check(k, 16'h0000);
        $display("Test 7 (reset after writes) done");

        if (errors == 0) $display("ALL CONFIG_MEMORY TESTS PASSED");
        else $display("CONFIG_MEMORY TESTS FAILED: %0d error(s)", errors);
        #20 $finish;
    end

endmodule
