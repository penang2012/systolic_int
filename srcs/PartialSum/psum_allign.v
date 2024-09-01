
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/08 18:45:25
// Design Name: 
// Module Name: input_allign_2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module psum_allign
    # ( 
        parameter OUT_DATA_WIDTH = 32,
        parameter COL = 8
    )
    (
        input clk,
        input rstn,
        input en,

        input [COL-1:0] write_en,
        input read_en,

        input [OUT_DATA_WIDTH * COL - 1:0] in1,

        output [OUT_DATA_WIDTH * COL - 1:0] out,
        output isempty,
        output isfull
    );
    parameter logCOL = 3;
    
    // reg [COL-1:0] wen;
//    wire [ROW-1:0] ren;

    wire [COL-1:0] empty;
    wire [COL-1:0] full;

    wire [OUT_DATA_WIDTH * COL - 1:0] in;


    // write data allgin
    
    // write simultaneously
    // wen = wen

    // empty = 1 when every line is empty
    // full = 1 when any line is empty
    assign isempty = &empty;
    assign isfull = |full;

    assign in = en ? in1 : {OUT_DATA_WIDTH * COL{1'b0}};

    genvar i;
    generate
        for(i = 0; i < COL; i = i + 1) begin
            FIFO_module #(
                .DATA_WIDTH(OUT_DATA_WIDTH),
                .FIFO_DEPTH(COL),
                .PTR_SIZE(logCOL)
            ) ACT_FIFO (
                .clk(clk),
                .rstn(rstn),
                .ren(read_en),
                .wen(write_en[i]),
                .din(in[OUT_DATA_WIDTH * (i+1)-1 : OUT_DATA_WIDTH * i]),
                .dout(out[OUT_DATA_WIDTH *(i+1)-1 : OUT_DATA_WIDTH * i]),
                .empty(empty[i]),
                .full(full[i])
            );
        end
    endgenerate


endmodule

