
// config_memory.v : register-based configuration bank
// * 32 words x 16 bits (5-bit address)
// * synchronous write (posedge clk, only when wr_en = 1)
// * asynchronous (combinational) read
// * active-high synchronous reset clears every word to zero

`timescale 1ns / 1ps

module config_memory (
    input wire clk,
    input wire rst,
    input wire wr_en,
    input wire [4:0] wr_addr,
    input wire [15:0] wr_data,

    input wire [4:0] rd_addr,
    output wire [15:0] rd_data
);

    localparam DEPTH = 32;

    reg [15:0] mem [0:DEPTH-1];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < DEPTH; i = i + 1)
                mem[i] <= 16'h0000;
        end else if (wr_en) begin
            mem[wr_addr] <= wr_data;
        end
    end

    assign rd_data = mem[rd_addr];

endmodule
