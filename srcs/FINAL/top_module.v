`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/07/30 15:47:29
// Design Name: 
// Module Name: Matmul_module
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
// This is the top module of Matrix multiplication
// This module includes Systolic array, Ifmap buffer, Weight buffer
//  ,Psum buffer unit, Output Store buffer, Matmul control unit
// This module gets input data from DRAM (DMA), control from Top module, [ADDED ON]
//////////////////////////////////////////////////////////////////////////////////


module top_module #(
    parameter integer IN_DATA_WIDTH = 8,
    parameter integer OUT_DATA_WIDTH = 32,
    parameter integer ROW = 8,
    parameter integer COL = 8,

    parameter integer BRAM_ADDR_WIDTH = 11,
    parameter integer BRAM_DATA_WIDTH = 8,

    parameter integer P_BRAM_ADDR_WIDTH = 5,
    parameter integer P_BRAM_DATA_WIDTH = 256,

    parameter integer O_BRAM_ADDR_WIDTH = 11,
    parameter integer O_BRAM_DATA_WIDTH = 8

    )  
    (
        input clk,
        input rstn,
        
        input [7:0] M,
        input [7:0] N,
        input [7:0] K,
        
        input [7:0] A,
        input [7:0] B,
        input [7:0] C,
        
        input start,
        input [1:0] opcode,
        
        input a_sel,
        input w_sel,
        input o_sel,

        input is_first_psum,

        input is_outputload,

        output busy,
        output done,
        
        output [O_BRAM_DATA_WIDTH - 1:0] o_buf0_dout,
        output [O_BRAM_DATA_WIDTH - 1:0] o_buf1_dout

    );
// weight buffer wire
wire w_buf0_en, w_buf0_we;
wire [BRAM_ADDR_WIDTH - 1 : 0] w_buf0_addr;
wire [BRAM_DATA_WIDTH - 1 : 0] w_buf0_din;
wire [ROW * IN_DATA_WIDTH -1 : 0] w_buf0_dout;

wire w_buf1_en, w_buf1_we;
wire [BRAM_ADDR_WIDTH - 1 : 0] w_buf1_addr;
wire [BRAM_DATA_WIDTH - 1 : 0] w_buf1_din;
wire [ROW * IN_DATA_WIDTH -1 : 0] w_buf1_dout;

wire [COL * IN_DATA_WIDTH - 1 : 0] in_north;
// activation buffer wire   

wire a_buf0_en, a_buf0_we;
wire [BRAM_ADDR_WIDTH - 1 : 0] a_buf0_addr;
wire [BRAM_DATA_WIDTH - 1 : 0] a_buf0_din;
wire [COL * IN_DATA_WIDTH -1 : 0] a_buf0_dout;

wire a_buf1_en, a_buf1_we;
wire [BRAM_ADDR_WIDTH - 1 : 0] a_buf1_addr;
wire [BRAM_DATA_WIDTH - 1 : 0] a_buf1_din;
wire [COL * IN_DATA_WIDTH -1 : 0] a_buf1_dout;

// activation allign wire
wire a_allign_rstn, a_allign_en, a_allign_we;
wire [COL - 1 : 0] a_allign_re;
wire [COL * IN_DATA_WIDTH - 1 : 0] a_allign_dout;
wire a_allign_empty, a_allign_full;
// systolic array wire
wire sys_array_control;
// wire [255:0] out_east; // not for use
wire [COL * OUT_DATA_WIDTH - 1: 0] sys_out;
// psum allign wire
wire p_allign_en, p_allign_re;
wire [COL-1:0] p_allign_we;
wire [COL * OUT_DATA_WIDTH - 1: 0] psum_din;
wire p_allign_empty, p_allign_full;

// psum buffer + adder wire
wire first_psum;


wire psum_sel;

wire [P_BRAM_ADDR_WIDTH -1:0] psum_addr, psum_prev_addr;
wire psum_en, psum_we;
wire [ROW * OUT_DATA_WIDTH - 1:0] psum_dout;
// output buffer + round wire
wire [O_BRAM_ADDR_WIDTH -1:0] o_buf0_addr;
wire o_buf0_en, o_buf0_we;
//wire [127:0] dout_o1;

wire [O_BRAM_ADDR_WIDTH -1:0] o_buf1_addr;
wire o_buf1_en, o_buf1_we;
//wire [127:0] dout_o2;

wire outputload_fin;

/////////////////////////////////////////////////////////////////////////////////
// Activation buffer unit.
/////////////////////////////////////////////////////////////////////////////////
// Input: From DRAM(AXI) ifmap data.
// Output: To sys_array unit. (1) with diagonal order  _OR_  (2) to allign unit 
// 
BRAM_W32x2048_R128 activation_buffer_1(
    .clka(clk), // output clk 
    .ena(a_buf0_en), // output enable
    .wea(a_buf0_we), //  write enable
    .addra(a_buf0_addr), // address [6 : 0] : 128
    // .dina(a_buf0_din), // input data [8 x 16 : 0]
    .dina(0), // input data [8 x 16 : 0]
    .douta(a_buf0_dout) //output data [8 x 16 : 0]
); //-> 16 x 1024

BRAM_W32x2048_R128 activation_buffer_2(
    .clka(clk), // output clk 
    .ena(a_buf1_en), // output enable
    .wea(a_buf1_dwe), //  write enable
    .addra(a_buf1_addr), // address [6 : 0] : 128
    // .dina(a_buf1_din), // input data [8 x 16 : 0]
    .dina(0), // input data [8 x 16 : 0]
    .douta(a_buf1_dout) //output data [8 x 16 : 0]
); //-> 16 x 1024


input_allign #(
    .IN_DATA_WIDTH(IN_DATA_WIDTH), 
    .ROW(ROW)
) input_setup (
    .clk(clk),
    .rstn(a_allign_rstn),
    .en(a_allign_en),
    .write_en(a_allign_we),
    .read_en(a_allign_re),
    .sel(a_sel),
    .in1(a_buf0_dout),
    .in2(a_buf1_dout),
    .out(a_allign_dout),
    .isempty(a_allign_empty),
    .isfull(a_allign_full)
); 


/////////////////////////////////////////////////////////////////////////////////
// Weight buffer unit.
/////////////////////////////////////////////////////////////////////////////////
// Input: From DRAM(AXI) ifmap data.
// Output: To sys_array unit. (1) with diagonal order  _OR_  (2) to allign unit 

BRAM_W32x2048_R128 weight_buffer_1(
    .clka(clk), // output clk 
    .ena(w_buf0_en), // output enable
    .wea(w_buf0_we), //  write enable
    .addra(w_buf0_addr), // address 
    // .dina(w_buf0_din), // input data [8 x 16 : 0]
    .dina(0), // input data [8 x 16 : 0]
    .douta(w_buf0_dout) //output data [8 x 16 : 0]
);

BRAM_W32x2048_R128 weight_buffer_2(
    .clka(clk), // output clk 
    .ena(w_buf1_en), // output enable
    .wea(w_buf1_we), //  write enable
    .addra(w_buf1_addr), // address 
    // .dina(w_buf1_din), // input data [8 x 16 : 0]
    .dina(0), // input data [8 x 16 : 0]
    .douta(w_buf1_dout) //output data [8 x 16 : 0]
);

assign in_north = (!w_sel) ? w_buf0_dout : w_buf1_dout;

// Systolic Array unit.
// Input: ifmap, weight from BRAM. Output: partial sum to Psum_unit

sys_array #(
    .IN_DATA_WIDTH(IN_DATA_WIDTH),
    .OUT_DATA_WIDTH(OUT_DATA_WIDTH),
    .ROW(ROW),
    .COL(COL)
) sys_array (
    .clk(clk),
    .rstn(rstn),
    .weight_en(sys_array_control), // Weight ready control unit 
    .in_west(a_allign_dout), //Activation buffer output
    .in_north(in_north), // Weight buffer output
//        .out_east(out_east), // Not for use
    .out_south(sys_out)
    );



/////////////////////////////////////////////////////////////////////////////
// Partial sum unit
/////////////////////////////////////////////////////////////////////////////////
// Input: From Systolic Array, Diagonal partial sum of Systolic Array.
// Fucntion: (1) Add partial sum with psum_buffer_A to store psum_buffer_B
// Function: (2) Transform Diagonalized Psum to Normal Format
// INFO: Two psum buffers(double_buffer) 8 x 64 x 2 (Need to be changeable by defined parameter inside.), Vector Adder 
// Output: When adding partial sum is over(From control), store to Output_store Unit.

psum_allign #(
    .OUT_DATA_WIDTH(OUT_DATA_WIDTH), 
    .COL(COL)
) psum_setup (
    .clk(clk),
    .rstn(p_allign_rstn),
    .en(p_allign_en),
    .write_en(p_allign_we), // {ROW} bits.
    .read_en(p_allign_re), // Single bits
    .in1(sys_out),
    .out(psum_din),
    .isempty(p_allign_empty),
    .isfull(p_allign_full)
); 


psum_store #(
    .ROW(ROW),
    .COL(COL), 
    .OUT_DATA_WIDTH(OUT_DATA_WIDTH), 
    .IN_DATA_WIDTH(IN_DATA_WIDTH)
) psum_buff (
    .clk(clk),
    .rstn(rstn),
    
    .buffer_sel(psum_sel), // NEED to CHANGE
    .first_psum(first_psum),
    
    .psum_din(psum_din),

    .psum_prev_addr(psum_prev_addr),
    .psum_addr(psum_addr),
    .psum_en(psum_en),
    .psum_we(psum_we),
    .psum_out(psum_dout)
);


/////////////////////////////////////////////////////////////////////////////
// Output Store unit
/////////////////////////////////////////////////////////////////////////////////
// Input: From psum_unit
// Function: store psum while data write to DRAM (controlled by Controller)
// Output: When psum_unit over, write to DRAM (slow)


BRAM_W128x32_R32x128 output_buffer_1(
.clka(clk), // output clk 
.ena(o_buf0_en), // output enable
.wea(o_buf0_we), //  write enable
.addra(o_buf0_addr), // address 
.dina(psum_dout), // input data [8 x 16 : 0]
.douta(o_buf0_dout) //output data [8 x 16 : 0]
);

BRAM_W128x32_R32x128 output_buffer_2(
.clka(clk), // output clk 
.ena(o_buf1_en), // output enable
.wea(o_buf1_we), //  write enable
.addra(o_buf1_addr), // address 
.dina(psum_dout), // input data [8 x 16 : 0]
.douta(o_buf1_dout) //output data [8 x 16 : 0]
);

multiply_control #(
    .ROW(ROW),
    .COL(COL),
    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH),
    .O_BRAM_ADDR_WIDTH(O_BRAM_ADDR_WIDTH),
    .O_BRAM_DATA_WIDTH(O_BRAM_DATA_WIDTH)
) multiply_control (
    .clk(clk),
    .rstn(rstn),

    .A(A),
    .B(B),
    .C(C),

    .start(start),
    .opcode(opcode),
    .a_sel(a_sel),
    .w_sel(w_sel),
    .o_sel(o_sel),
    .is_first_psum(is_first_psum),
    .is_outputload(is_outputload),

    .busy(busy),
    .done(done),    
    
    .w_buf0_en(w_buf0_en),
    .w_buf0_we(w_buf0_we),
    .w_buf0_addr(w_buf0_addr),

    .w_buf1_en(w_buf1_en),
    .w_buf1_we(w_buf1_we),
    .w_buf1_addr(W_buf1_addr),

    .a_buf0_en(a_buf0_en),
    .a_buf0_we(a_buf0_we),
    .a_buf0_addr(a_buf0_addr),

    .a_buf1_en(a_buf1_en),
    .a_buf1_we(a_buf1_we),
    .a_buf1_addr(a_buf1_addr),

    .a_allign_rstn(a_allign_rstn),
    .a_allign_en(a_allign_en),
    .a_allign_we(a_allign_we),
    .a_allign_re(a_allign_re),

    .sys_array_control(sys_array_control),

    .p_allign_rstn(p_allign_rstn),
    .p_allign_en(p_allign_en),
    .p_allign_we(p_allign_we),
    .p_allign_re(p_allign_re),

    .psum_en(psum_en),
    .psum_we(psum_we),
    .psum_addr(psum_addr),
    .psum_prev_addr(psum_prev_addr),
    .psum_sel(psum_sel),
    .first_psum(first_psum),

    .o_buf0_en(o_buf0_en),
    .o_buf0_we(o_buf0_we),
    .o_buf0_addr(o_buf0_addr),

    .o_buf1_en(o_buf1_en),
    .o_buf1_we(o_buf1_we),
    .o_buf1_addr(o_buf1_addr)    
);


endmodule