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


module input_allign
    # ( 
        parameter IN_DATA_WIDTH = 8,
        parameter ROW = 8
    )
    (
        input clk,
        input rstn,
        input en,

        input write_en,
        input [ROW - 1:0] read_en,

        input sel,

        input [IN_DATA_WIDTH * ROW - 1:0] in1,
        input [IN_DATA_WIDTH * ROW - 1:0] in2,


        output [IN_DATA_WIDTH * ROW - 1:0] out,
        output isempty,
        output isfull
    );
    parameter logROW = 3;
    
//    wire [ROW-1:0] wen;

    wire [ROW-1:0] empty;
    wire [ROW-1:0] full;

    wire [ROW * IN_DATA_WIDTH-1:0] in;
   
    // write simultaneously
    // wen = wen

    // empty = 1 when every line is empty
    // full = 1 when any line is empty
    assign isempty = &empty;
    assign isfull = |full;

    // Input buffer select
    // assign in = en ? (sel ? in2 : in1) : {IN_DATA_WIDTH * ROW{1'b0}};

    assign in = sel ? in2 : in1;

    genvar i;
    generate
        for(i = 0; i < ROW; i = i + 1) begin
            FIFO_module #(
                .DATA_WIDTH(IN_DATA_WIDTH),
                .FIFO_DEPTH(ROW),
                .PTR_SIZE(logROW)
            ) ACT_FIFO (
                .clk(clk),
                .rstn(rstn),
                .ren(read_en[i]),
                .wen(write_en),
                .din(in[IN_DATA_WIDTH * (i+1)-1 : IN_DATA_WIDTH * i]),
                .dout(out[IN_DATA_WIDTH *(i+1)-1 : IN_DATA_WIDTH * i]),
                .empty(empty[i]),
                .full(full[i])
            );
        end
    endgenerate


endmodule
