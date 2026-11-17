// Protocol
// * One bit is sampled from serial_in on each rising clk edge while en = 1.
// * MSB first: the first bit received ends up in config_word[15].
// * After exactly 16 sampled bits, config_word is updated and word_valid is high for exactly one clock cycle.
// * Words may be sent back-to-back (keep en = 1 for 32, 48, ... cycles).
// * Incomplete words are discarded: if en goes low before 16 bits have been received, the bit counter is cleared and no word_valid is produced.
// * rst (active-high, synchronous) clears the shift register, the counter, config_word and word_valid.

`timescale 1ns / 1ps

module config_loader (
    input wire clk,
    input wire rst,
    input wire en, // load enable / start: high while bits are streamed
    input wire serial_in, // serial configuration data, MSB first
    output reg [15:0] config_word, // last complete 16-bit word
    output reg word_valid   // one-cycle pulse when config_word is updated
);

    reg [15:0] shift_reg; 
    reg [3:0]  bit_count;

    always @(posedge clk) begin
        if (rst) begin
            shift_reg <= 16'h0000;
            bit_count <= 4'd0;
            config_word <= 16'h0000;
            word_valid <= 1'b0;
        end else begin
            word_valid <= 1'b0; // pulse lasts one cycle

            if (en) begin
                shift_reg <= {shift_reg[14:0], serial_in};

                if (bit_count == 4'd15) begin // 16th bit received
                    config_word <= {shift_reg[14:0], serial_in};
                    word_valid <= 1'b1;
                    bit_count <= 4'd0;
                end else begin
                    bit_count <= bit_count + 4'd1;
                end
            end else begin
                bit_count <= 4'd0;
            end
        end
    end

endmodule
