 `timescale 1ns / 1ps

module psum_store #(
    parameter ROW = 8,
    parameter COL = 8,
    parameter OUT_DATA_WIDTH = 32,
    parameter IN_DATA_WIDTH = 8
)
(
    clk,
    rstn,

    buffer_sel,
    first_psum,

    psum_din,

    psum_prev_addr,
    psum_addr,
    psum_en,
    psum_we,

    psum_out

);
    input clk, rstn;

    input buffer_sel;
    input first_psum;

    input [COL*OUT_DATA_WIDTH-1:0] psum_din;
    input [7-1:0] psum_prev_addr, psum_addr;
    input psum_en;
    input psum_we;

    output [COL * OUT_DATA_WIDTH-1 : 0] psum_out;
    
//    wire [COL*OUT_DATA_WIDTH-1:0] psum_dout;
    
    wire psum_we1, psum_we2;
    wire [COL*OUT_DATA_WIDTH-1:0] psum_din1, psum_din2;
    wire [COL*OUT_DATA_WIDTH-1:0] psum_dout1, psum_dout2;
    wire [COL*OUT_DATA_WIDTH-1:0] adder_out;

    reg [COL*OUT_DATA_WIDTH-1:0] current_psum, current_psum_n;
    wire [7-1:0] psum_addr1, psum_addr2;
    
    wire [3 * COL - 1 : 0] GRS;

    // if current sel == 0 : add psum + (read data from buffer2) ,write on buffer1

    always @(posedge clk) begin
        current_psum <= current_psum_n;
    end
    always @ (*) begin
        current_psum_n <= first_psum ? 256'b0 : buffer_sel? psum_dout1 : psum_dout2;
    end

    // select psum double buffer

    assign psum_we1 = !buffer_sel & psum_we;
    assign psum_we2 = buffer_sel & psum_we;

    assign psum_din1 = buffer_sel ? 0 : adder_out;
    assign psum_din2 = !buffer_sel ? 0 : adder_out;

    assign psum_addr1 = buffer_sel ? psum_prev_addr : psum_addr;
    assign psum_addr2 = !buffer_sel ? psum_prev_addr : psum_addr;

    genvar i;
    generate
        for (i = 0; i < COL; i = i + 1) begin
            
            assign adder_out[OUT_DATA_WIDTH * i + 31 : OUT_DATA_WIDTH * i] = psum_din[OUT_DATA_WIDTH * i + 31 : OUT_DATA_WIDTH * i] + current_psum[OUT_DATA_WIDTH * i + 31 : OUT_DATA_WIDTH * i];
        end
    endgenerate 

    BRAM_32x8x32 psum_buffer_1(
        .clka(clk), // output clk 
        .ena(psum_en), // output enable
        .wea(psum_we1), //  write enable
        .addra(psum_addr1), // address 
        .dina(psum_din1), // input data [8 x 16 : 0]
        .douta(psum_dout1) //output data [8 x 16 : 0]
    );

    BRAM_32x8x32 psum_buffer_2(
        .clka(clk), // output clk 
        .ena(psum_en), // output enable
        .wea(psum_we2), //  write enable
        .addra(psum_addr2), // address 
        .dina(psum_din2), // input data [8 x 16 : 0]
        .douta(psum_dout2) //output data [8 x 16 : 0]
    );

    assign psum_out = !buffer_sel ? psum_dout1 : psum_dout2;

    
// temporal quantization using rounding + divide by 2048(2^11)

//    generate
//    for (i = 0; i < COL; i = i + 1) begin
//        assign GRS[3*i + 2 : 3*i] = {psum_dout[32*i + 10], psum_dout[32*i + 9], |psum_dout[32*i + 8 : 32 * i + 0]};
//        assign psum_out[IN_DATA_WIDTH * i + IN_DATA_WIDTH - 1 : IN_DATA_WIDTH * i] = 
//                                                 GRS[3*i + 2] & (|GRS[3*i + 1: 3*i] | psum_dout[32*i + 111]) ? 
//                                                 { (psum_dout[32*i + 18 : 32*i + 11] + 1'b1)} : { psum_dout[32*i + 18 : 32*i + 11]};
//    end
//    endgenerate


endmodule
