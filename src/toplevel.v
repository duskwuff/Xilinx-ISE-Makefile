`timescale 1ns / 1ps

module toplevel(
    input clk,
    input  [7:0] sw,
    output [7:0] led
);

    reg [23:0] ctr;
    reg [7:0] state;

    always @(posedge clk) begin
        ctr <= ctr + 1;
        if (ctr == 0) begin
            state <= state + sw;
        end
    end

    assign led = state;

endmodule
