`timescale 1ns / 1ps

module tb_top_module_2;

    // Parameters
    parameter IN_DATA_WIDTH = 8;
    parameter OUT_DATA_WIDTH = 32;
    parameter ROW = 8;
    parameter COL = 8;
    
    parameter BRAM_ADDR_WIDTH = 11;
    parameter BRAM_DATA_WIDTH = 32;

    parameter P_BRAM_ADDR_WIDTH = 5;
    parameter P_BRAM_DATA_WIDTH = 256;

    parameter O_BRAM_ADDR_WIDTH = 8;
    parameter O_BRAM_DATA_WIDTH = 32;

    // Inputs
    reg clk;
    reg rstn;
    reg [7:0] M = 256;
    reg [7:0] N = 256;
    reg [7:0] K = 256;
    reg [7:0] A = 2;
    reg [7:0] B = 32;
    reg [7:0] C = 2;
    reg a_sel;
    reg w_sel;
    reg o_sel;
    reg start;
    reg [1:0] opcode;
    reg is_first_psum;
    reg is_outputload;
    wire busy;
    wire done;

    wire [O_BRAM_DATA_WIDTH-1:0] o_buf0_dout;
    wire [O_BRAM_DATA_WIDTH-1:0] o_buf1_dout;

////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////       TOP MODULE        //////////////////////////////////
// weight buffer wire
wire w_buf0_en, w_buf0_we;
wire [BRAM_ADDR_WIDTH - 1 : 0] w_buf0_addr;
wire [BRAM_DATA_WIDTH - 1 : 0] w_buf0_din;
wire [ROW * IN_DATA_WIDTH -1 : 0] w_buf0_dout;

wire w_buf1_en, w_buf1_we;
wire [BRAM_ADDR_WIDTH - 1 : 0] w_buf1_addr;
wire [BRAM_DATA_WIDTH - 1 : 0] w_buf1_din;
wire [ROW * IN_DATA_WIDTH -1 : 0] w_buf1_dout;

wire [ROW * IN_DATA_WIDTH - 1 : 0] in_north;
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
wire empty_allign_a, full_allign_a;
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


//////////////////////////////////////////////////////////
// simulation port
reg tb_on_a0;
reg tb_on_a1;
reg tb_on_w0;
reg tb_on_w1;
reg tb_on_o0;
reg tb_on_o1;

reg tb_w_buf0_en, tb_w_buf0_we;
reg [BRAM_ADDR_WIDTH - 1 : 0] tb_w_buf0_addr;
reg [BRAM_DATA_WIDTH - 1 : 0] tb_w_buf0_din;

reg tb_w_buf1_en, tb_w_buf1_we;
reg [BRAM_ADDR_WIDTH - 1 : 0] tb_w_buf1_addr;
reg [BRAM_DATA_WIDTH - 1 : 0] tb_w_buf1_din;

reg tb_a_buf0_en, tb_a_buf0_we;
reg [BRAM_ADDR_WIDTH - 1 : 0] tb_a_buf0_addr;
reg [BRAM_DATA_WIDTH - 1 : 0] tb_a_buf0_din;

reg tb_a_buf1_en, tb_a_buf1_we;
reg [BRAM_ADDR_WIDTH - 1 : 0] tb_a_buf1_addr;
reg [BRAM_DATA_WIDTH - 1 : 0] tb_a_buf1_din;


reg [O_BRAM_ADDR_WIDTH -1:0] tb_o_buf0_addr;
reg tb_o_buf0_en, tb_o_buf0_we;

reg [O_BRAM_ADDR_WIDTH-1:0] tb_o_buf1_addr;
reg tb_o_buf1_en, tb_o_buf1_we;

/////////////////////////////////////////////////////////////////////////////////
// Activation buffer unit.
/////////////////////////////////////////////////////////////////////////////////
// Input: From DRAM(AXI) ifmap data.
// Output: To sys_array unit. (1) with diagonal order  _OR_  (2) to allign unit 
// 
BRAM_W32x2048_R128 activation_buffer_1(
    .clka(clk), // output clk 
    .ena(!tb_on_a0 ? a_buf0_en : tb_a_buf0_en), // output enable
    .wea(!tb_on_a0 ? a_buf0_we : tb_a_buf0_we), //  write enable
    .addra(!tb_on_a0 ? a_buf0_addr : tb_a_buf0_addr), // address [6 : 0] : 128
    .dina(tb_a_buf0_din), // input data [8 x 16 : 0]
    // .dina(0), // input data [8 x 16 : 0]
    .douta(a_buf0_dout) //output data [8 x 16 : 0]
); //-> 16 x 1024

BRAM_W32x2048_R128 activation_buffer_2(
    .clka(clk), // output clk 
    .ena(!tb_on_a1 ? a_buf1_en : tb_a_buf1_en), // output enable
    .wea(!tb_on_a1 ? a_buf1_we : tb_a_buf1_we), //  write enable
    .addra(!tb_on_a1 ? a_buf1_addr : tb_a_buf1_addr), // address [6 : 0] : 128
    .dina(tb_a_buf1_din), // input data [8 x 16 : 0]
    // .dina(0), // input data [8 x 16 : 0]
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
    .ena(!tb_on_w0 ? w_buf0_en : tb_w_buf0_en), // output enable
    .wea(!tb_on_w0 ? w_buf0_we : tb_w_buf0_we), //  write enable
    .addra(!tb_on_w0 ? w_buf0_addr : tb_w_buf0_addr), // address 
    .dina(tb_w_buf0_din), // input data [8 x 16 : 0]
    // .dina(0), // input data [8 x 16 : 0]
    .douta(w_buf0_dout) //output data [8 x 16 : 0]
);

BRAM_W32x2048_R128 weight_buffer_2(
    .clka(clk), // output clk 
    .ena(!tb_on_w1 ? w_buf1_en : tb_w_buf1_en), // output enable
    .wea(!tb_on_w1 ? w_buf1_we : tb_w_buf1_we), //  write enable
    .addra(!tb_on_w1 ? w_buf1_addr : tb_w_buf1_addr), // address 
    .dina(tb_w_buf1_din), // input data [8 x 16 : 0]
    // .dina(0), // input data [8 x 16 : 0]
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
.ena(!tb_on_o0 ? o_buf0_en : tb_o_buf0_en), // output enable
.wea(!tb_on_o0 ? o_buf0_we : tb_o_buf0_we), //  write enable
.addra(!tb_on_o0 ? o_buf0_addr : tb_o_buf0_addr), // address 
.dina(psum_dout), // input data [8 x 16 : 0]
.douta(o_buf0_dout) //output data [8 x 16 : 0]
);

BRAM_W128x32_R32x128 output_buffer_2(
.clka(clk), // output clk 
.ena(!tb_on_o1 ? o_buf1_en : tb_o_buf1_en), // output enable
.wea(!tb_on_o1 ? o_buf1_we : tb_o_buf1_we), //  write enable
.addra(!tb_on_o1 ? o_buf1_addr : tb_o_buf1_addr), // address 
.dina(psum_dout), // input data [8 x 16 : 0]
.douta(o_buf1_dout) //output data [8 x 16 : 0]
);

multiply_control #(
    .ROW(ROW),
    .COL(COL),

    .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH),

    .P_BRAM_ADDR_WIDTH(P_BRAM_ADDR_WIDTH),
    .P_BRAM_DATA_WIDTH(P_BRAM_DATA_WIDTH),

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
    .w_buf1_addr(w_buf1_addr),

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

//////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end
    
    reg load_mem_done;

    task load_buf_from_mem;
        input [3:0] buf_sel; // 0001: a_buf0, 0010: a_buf1, 0100: w_buf0, 1000: w_buf1
        input string mem_file; // File name to load
        input integer start_row;
        input integer start_col;
        input integer num_row;
        input integer num_col;
        input integer max_row;
        input integer max_col;
        integer i, j, k;
        reg [BRAM_DATA_WIDTH-1:0] mem_data [256 * 256-1:0]; // can hold 256 * 256 as a input.
        integer addr;
        begin
            $readmemh(mem_file, mem_data); // Load data from the specified .mem file
            addr = 0;
            load_mem_done = 0;
            tb_on_a0 = 0;
            tb_on_a1 = 0;
            tb_on_w0 = 0;
            tb_on_w1 = 0;

            for (i = start_row; i < start_row + num_row; i = i + 8) begin
                for(j = start_col; j < start_col + num_col; j = j + 8) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        
                        @(posedge clk);
                        case(buf_sel)
                        4'b0001: begin
                            tb_a_buf0_en = 1;
                            tb_a_buf0_we = 1;
                            tb_a_buf0_addr = addr;
                            tb_a_buf0_din = mem_data[k + ROW / 4 * j + max_col / 4 * i];
                            tb_on_a0 = 1;
                        end
                        4'b0010: begin
                            tb_a_buf1_en = 1;
                            tb_a_buf1_we = 1;
                            tb_a_buf1_addr = addr;
                            tb_a_buf1_din = mem_data[k + ROW / 4 * j + max_col / 4 * i];
                            tb_on_a1 = 1;
                        end
                        4'b0100: begin
                            tb_w_buf0_en = 1;
                            tb_w_buf0_we = 1;
                            tb_w_buf0_addr = addr;
                            tb_w_buf0_din = mem_data[k + ROW / 4 * j + max_col / 4 * i];
                            tb_on_w0 = 1;
                        end
                        4'b1000: begin
                            tb_w_buf1_en = 1;
                            tb_w_buf1_we = 1;
                            tb_w_buf1_addr = addr;
                            tb_w_buf1_din = mem_data[k + ROW / 4 * j + max_col / 4 * i];
                            tb_on_w1 = 1;
                        end
                        endcase
                        addr = addr + 1;
                    end     
                end
            end
            #10;
            tb_on_a0 = 0;
            tb_on_a1 = 0;
            tb_on_w0 = 0;
            tb_on_w1 = 0;
            tb_a_buf0_we = 0;
            tb_a_buf0_en = 0;
            tb_a_buf0_addr = 0;
            tb_a_buf1_we = 0;
            tb_a_buf1_en = 0;
            tb_a_buf1_addr = 0;
            tb_w_buf0_we = 0;
            tb_w_buf0_en = 0;
            tb_w_buf0_addr = 0;
            tb_w_buf1_we = 0;
            tb_w_buf1_en = 0;
            tb_w_buf1_addr = 0;
            load_mem_done = 1;
            #10;
        end
    endtask

   

    task fetch_bram;
        input [1:0] bram_id; // Select which BRAM to fetch from (2'b01 for o_buf0, 2'b10 for o_buf1)
        input integer num_words; // Number of words to fetch
        integer i;
        begin
            tb_on_o0 = 0;
            tb_on_o1 = 0;
            for (i = 0; i < num_words; i = i + 1) begin
                #10;
                case (bram_id)
                    2'b01: begin
                        tb_o_buf0_en = 1;
                        tb_o_buf0_we = 0;
                        tb_o_buf0_addr = i;
                        tb_on_o0 = 1;
                    end
                    2'b10: begin
                        tb_o_buf1_en = 1;
                        tb_o_buf1_we = 0;
                        tb_o_buf1_addr = i;
                        tb_on_o1 = 1;
                    end
                endcase

            end
            #10
            tb_on_o0 = 0;
            tb_on_o1 = 0;
            tb_o_buf0_en = 0;
            tb_o_buf0_we = 0;
            tb_o_buf0_addr = 0;
            tb_o_buf1_en = 0;
            tb_o_buf1_we = 0;
            tb_o_buf1_addr = 0;   
            #10;
        end
    endtask
    
    integer i;
    integer j;
    integer k;
    integer file;

    reg [O_BRAM_ADDR_WIDTH - 1 : 0] prev_tb_o_buf0_addr;
    reg [O_BRAM_ADDR_WIDTH - 1 : 0] prev_tb_o_buf1_addr;

    always @(posedge clk) begin
        #1
        if (tb_o_buf0_addr !== prev_tb_o_buf0_addr) begin
            prev_tb_o_buf0_addr <= tb_o_buf0_addr; 
            
            $fwrite(file, "%h\n", o_buf0_dout);
        end
    end

    always @(posedge clk) begin
        #1
        if (tb_o_buf1_addr !== prev_tb_o_buf1_addr) begin
            prev_tb_o_buf1_addr <= tb_o_buf1_addr; 
            
            $fwrite(file, "%h\n", o_buf1_dout);
        end
    end

    // Stimulus generation
    initial begin        
//        $monitor("BRAM1 Addr: %0d, Data: %0h", tb_o_buf0_addr - 2, o_buf0_dout);
//        $monitor("BRAM2 Addr: %0d, Data: %0h", tb_o_buf1_addr - 2, o_buf1_dout);
        
        file = $fopen("output.txt", "w");

        if (file == 0) begin
            $display("Error: Could not open file for writing.");
            $finish;
            $stop;
        end

        // TESTBENCH code for fetching DRAM.

        #10
        rstn = 0;
        #10
        rstn = 1;
        #10
        
        start = 0;
        opcode = 2'b11;
        is_first_psum = 1'b1;
        is_outputload = 1'b1;
        a_sel = 1'b0;
        w_sel = 1'b0;
        o_sel = 1'b0;
        
        tb_on_a0 = 0;
        tb_on_a1 = 0;
        tb_on_w0 = 0;
        tb_on_w1 = 0;
        tb_a_buf0_we = 0;
        tb_a_buf0_en = 0;
        tb_a_buf0_addr = 0;
        tb_a_buf1_we = 0;
        tb_a_buf1_en = 0;
        tb_a_buf1_addr = 0;
        tb_w_buf0_we = 0;
        tb_w_buf0_en = 0;
        tb_w_buf0_addr = 0;
        tb_w_buf1_we = 0;
        tb_w_buf1_en = 0;
        tb_w_buf1_addr = 0;
        load_mem_done = 0;
        tb_on_o0 = 0;
        tb_on_o1 = 0;
        tb_o_buf0_en = 0;
        tb_o_buf0_we = 0;
        tb_o_buf0_addr = 0;
        tb_o_buf1_en = 0;
        tb_o_buf1_we = 0;
        tb_o_buf1_addr = 0;   

        
        #10
        load_buf_from_mem({w_sel, !w_sel, 1'b0, 1'b0},"weight.mem", 0, 0, 256, 16, 256, 256); 
        load_buf_from_mem({1'b0, 1'b0, a_sel, !a_sel}, "activation.mem", 0, 0, 16, 256, 256, 256);
        #10
        // j_max == M / (8 * A)

        // i_max == N / (8 * N)
        for(i = 0; i < 16; i = i + 1) begin
            for(k = 0; k < 1; k = k + 1) begin
                if(i == 0 & k == 0) begin
                end else begin
                    w_sel = !w_sel;
                end
                for(j = 0; j < 16; j = j + 1) begin
                        if(i == 0 & j == 0) begin
                            @(posedge clk);
                            start = 1;
                            @(posedge clk);
                            start = 0;
                        end 
                        else begin
                            @(posedge done);
                            a_sel = !a_sel;
                            fetch_bram({o_sel, !o_sel}, 256 / 8 * 8);
                            o_sel = !o_sel;
                            @(posedge clk);
                            start = 1;
                            @(posedge clk);
                            start = 0;
                        end
                        @(posedge clk);
                        // load next buffer, next memory
                        if(k == 0 & j == 15) begin
                            load_buf_from_mem({1'b0, 1'b0, !a_sel, a_sel}, "activation.mem", 0, 0, 16, 256, 256, 256);
                        end else if (j == 15) begin
                            load_buf_from_mem({1'b0, 1'b0, !a_sel, a_sel}, "activation.mem", 0, 16 * k + 16, 16, 256, 256, 256); 
                        end else begin
                            load_buf_from_mem({1'b0, 1'b0, !a_sel, a_sel}, "activation.mem", 16 * j + 16, 16 * k, 16, 256, 256, 256);
                        end
                end
                if(i == 15 & k == 0) begin
                end else if(k == 0) begin
                    load_buf_from_mem({!w_sel, w_sel, 1'b0, 1'b0},"weight.mem", 0, 16 * i + 16, 256, 16, 256, 256); 
                end else begin
                    load_buf_from_mem({!w_sel, w_sel, 1'b0, 1'b0},"weight.mem", 16 * k + 16, 16 * i, 256, 16, 256, 256); 
                end
            end
        end
        
        fetch_bram({o_sel, !o_sel}, 256 / 8  * 8);
        #1000
        $fclose(file);  
        #10
        $finish;

    end
endmodule
