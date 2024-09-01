`timescale 1ns / 1ps

module multiply_control #(
    parameter ROW = 8,
    parameter COL = 8,

    parameter integer BRAM_ADDR_WIDTH = 11,
    parameter integer BRAM_DATA_WIDTH = 32,
    
    parameter integer P_BRAM_ADDR_WIDTH = 5,
    parameter integer P_BRAM_DATA_WIDTH = 256,
    
    parameter integer O_BRAM_ADDR_WIDTH = 7,
    parameter integer O_BRAM_DATA_WIDTH = 32
)
(
    clk,
    rstn,

    A,
    B,
    C,

    start,
    opcode,
    a_sel,
    w_sel,
    o_sel,
    is_first_psum,
    is_outputload,

    busy,
    done,    
    
    w_buf0_en,
    w_buf0_we,
    w_buf0_addr,

    w_buf1_en,
    w_buf1_we,
    w_buf1_addr,

    a_buf0_en,
    a_buf0_we,
    a_buf0_addr,

    a_buf1_en,
    a_buf1_we,
    a_buf1_addr,

    a_allign_rstn,
    a_allign_en,
    a_allign_we,
    a_allign_re,

    sys_array_control,

    p_allign_rstn,
    p_allign_en,
    p_allign_we,
    p_allign_re,

    psum_en,
    psum_we,
    psum_addr,
    psum_prev_addr,
    psum_sel,
    first_psum,

    o_buf0_en,
    o_buf0_we,
    o_buf0_addr,

    o_buf1_en,
    o_buf1_we,
    o_buf1_addr
);
input clk;
input rstn; // synchronous reset_n signals

input [7:0] A, B, C;

input start;
input [1:0] opcode;
input a_sel, w_sel, o_sel;
input is_first_psum, is_outputload;

output reg busy;
output reg done;    

output reg w_buf0_en, w_buf0_we;
output reg [BRAM_ADDR_WIDTH-1:0] w_buf0_addr;

output reg w_buf1_en, w_buf1_we;
output reg [BRAM_ADDR_WIDTH-1:0] w_buf1_addr;

output reg a_buf0_en, a_buf0_we;
output reg [BRAM_ADDR_WIDTH-1:0] a_buf0_addr;

output reg a_buf1_en, a_buf1_we;
output reg [BRAM_ADDR_WIDTH-1:0] a_buf1_addr;

output [O_BRAM_ADDR_WIDTH - 1:0] psum_addr, psum_prev_addr;
output psum_en, psum_we;

output o_buf0_en, o_buf0_we;
output [O_BRAM_ADDR_WIDTH-1:0] o_buf0_addr;

output o_buf1_en, o_buf1_we;
output [O_BRAM_ADDR_WIDTH-1:0] o_buf1_addr;

output reg a_allign_rstn, a_allign_en, a_allign_we;
output reg [COL - 1 : 0] a_allign_re;

output p_allign_rstn, p_allign_en, p_allign_re;
output [COL - 1 : 0]  p_allign_we;

output psum_sel;
output first_psum;

output reg sys_array_control;

///////////////////////////////////////////////////////////////////////

localparam IDLE = 2'b00;
localparam WEIGHTLOAD = 2'b01;
localparam MULTIPLY = 2'b10;
localparam OUTPUTLOAD = 2'b11;

localparam integer NDATA = 4;

reg [1:0] state;

// count
reg [7:0] count;
reg [7:0] idx_a, idx_w, idx_p;
reg [7:0] count_mul, count_weight;

reg is_first_psum_reg;
reg is_outputload_reg;

reg psum_to_out; // enable psum to store at output buffer

reg [P_BRAM_ADDR_WIDTH - 1 : 0] psum_baseaddr;

reg psum_start;

reg psum_ctrl_sel;

// For loop count
reg [7:0] i, j, k, l;

// For loop max.
reg [7:0] I, J, K, L;

// initial block:  set counters to zero
initial begin
    count = 8'b0;
    idx_a = 8'b0;
    idx_w = 8'b0;
    idx_p = 8'b0;
    count_mul = 8'b0;

    state = IDLE;
end

// State control;
always @(posedge clk) begin
    if(!rstn) begin
        state <= IDLE;
    end
    else begin
        case (state)
        IDLE: begin
            if(start) begin
                state <= WEIGHTLOAD;
            end
            else begin
                state <= IDLE;
            end
        end
        WEIGHTLOAD: begin
            if(count_weight == ROW - 1) begin
                state <= MULTIPLY;
            end
            else begin
                state <= WEIGHTLOAD;
            end
        end
        MULTIPLY: begin
            if(count_mul == ROW + COL + L * COL ) begin
                if(l == L - 1) begin
                    if((i == I - 1) & (j == J - 1) & (k == K - 1)) begin
                        if(is_outputload_reg) begin
                            state <= OUTPUTLOAD;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        state <= WEIGHTLOAD;
                    end
                end else begin
                    state <= MULTIPLY;
                end
            end else begin
                state <= MULTIPLY;
            end
        end
        OUTPUTLOAD: begin
            if(outputload_fin) begin
                state <= IDLE;
            end
        end
        default: begin
            state <= IDLE;
        end
        endcase
    end
end

// Register control : TODO. Not Complete

always @(posedge clk) begin
    if(!rstn) begin
        count <= 8'b0;
        count_mul <= 8'b0;
        count_weight <= 8'b0;

        idx_a <= 8'b0;
        idx_w <= 8'b0;
        idx_p <= 8'b0;

        i <= 8'b0;
        j <= 8'b0;
        k <= 8'b0;
        l <= 8'b0;

        busy <= 1'b0;
        done <= 1'b0;

        is_first_psum_reg <= 1'b1;

    end else begin
        case(state)
        IDLE: begin     
            count <= 8'b0;
            count_mul <= 8'b0;
            count_weight <= 8'b0;    
                
            psum_to_out <= 1'b0; 

            i <= 8'b0;
            j <= 8'b0;
            k <= 8'b0;
            l <= 8'b0;

            idx_a <= 8'b0;
            idx_w <= 8'b0;
            idx_p <= 8'b0;

            busy <= 1'b0;
            done <= 1'b0;

            case(opcode)
                2'b00: begin
                    I <= A;
                    J <= B;
                    K <= C;
                    L <= 8'b00000001;
                end
                2'b01: begin
                    I <= A;
                    J <= C;
                    K <= B;
                    L <= 8'b00000001;
                end
                2'b10: begin
                    I <= 8'b00000001;
                    J <= B;
                    K <= C;
                    L <= A;
                end
                2'b11: begin
                    I <= 8'b00000001;
                    J <= C;
                    K <= B;
                    L <= A;
                end
                default: begin // opcode default == 2'b01
                    I <= 8'b00000001;
                    J <= B;
                    K <= C;
                    L <= A;
                end
            endcase

            if(start) begin
                busy <= 1'b1;
                is_first_psum_reg <= is_first_psum;
                is_outputload_reg <= is_outputload;
            end

        end
        WEIGHTLOAD: begin
            if(count_weight == ROW - 1) begin
                count_weight <= 0;
                l <= 0;
            end else begin
                count_weight <= count_weight + 1;
            end

        end
        MULTIPLY: begin
            count_mul <= count_mul + 1;

            if(l == L-1 & idx_a == ROW-1) begin
                idx_a <= 0;
            end else if(idx_a == ROW-1) begin
                idx_a <= 0;
                l <= l + 1;
            end else begin
                idx_a <= idx_a + 1;
            end

            if(count_mul == ROW + COL + L * COL) begin
                
                count_mul <= 8'b0;
                if(l == L - 1) begin
                    idx_a <= 0;
                end

                if((i == I - 1) &&  (j == J - 1) && (k == K - 1)) begin
                end else begin
                    if(k == K - 1) begin
                        k <= 0;
                        if(j == J - 1) begin
                            j <= 0;
                            i <= i + 1;
                        end else begin
                            j <= j + 1;
                        end
                        is_first_psum_reg <= 1'b1;
                    end else begin
                        k <= k + 1;
                        is_first_psum_reg <= 1'b0;
                    end
                end
            end
        end
        OUTPUTLOAD: begin
            psum_to_out <= 1'b1;
            if(outputload_fin) begin   
                done <= 1'b1;
            end
        end
        
        endcase
    end
end


// Weight buffer control

always @(posedge clk) begin
    if(!rstn) begin
        w_buf0_en <= 1'b0;
        w_buf0_we <= 1'b0;
        w_buf0_addr <= {BRAM_ADDR_WIDTH{1'b0}};

        w_buf1_en <= 1'b0;
        w_buf1_we <= 1'b0;  
        w_buf1_addr <= {BRAM_ADDR_WIDTH{1'b0}};
    end else if(!w_sel) begin
        w_buf1_en <= 1'b0;
        w_buf1_we <= 1'b0;  
        w_buf1_addr <= {BRAM_ADDR_WIDTH{1'b0}};

        case(state)
        IDLE: begin
            w_buf0_en <= 1'b0;
            w_buf0_we <= 1'b0;
        end
        WEIGHTLOAD: begin
            w_buf0_en <= 1'b1;
            w_buf0_we <= 1'b0;
            w_buf0_addr <= (COL / NDATA) * (ROW * (J * k + j) + ROW - count_weight - 1);
        end
        default: begin // MULTIPLY, OUTPUTLOAD, DEFAULT
            w_buf0_en <= 1'b0;
            w_buf0_we <= 1'b0;
            w_buf0_addr <= w_buf0_addr;
        end
        endcase
    end else begin
        w_buf0_en <= 1'b0;
        w_buf0_we <= 1'b0;  
        w_buf0_addr <= {BRAM_ADDR_WIDTH{1'b0}};

        case(state)
        IDLE: begin
            w_buf1_en <= 1'b0;
            w_buf1_we <= 1'b0;
        end
        WEIGHTLOAD: begin
            w_buf1_en <= 1'b1;
            w_buf1_we <= 1'b0;
            w_buf1_addr <= (COL / NDATA) * (ROW * (J * k + j) + ROW - count_weight - 1);
            
            // if(idx_w > 0) begin
            //     sys_array_control <= 1'b1;
            // end
        end
        default: begin // MULTIPLY, OUTPUTLOAD, DEFAULT
            w_buf1_en <= 1'b0;
            w_buf1_we <= 1'b0;
            w_buf1_addr <= w_buf1_addr;
        end
        endcase
    end
end


// ACTIVATION, ALLIGN control

always @(posedge clk) begin
    if(!rstn) begin
        a_buf0_en <= 1'b0;
        a_buf0_we <= 1'b0;
        a_buf0_addr <= {BRAM_ADDR_WIDTH{1'b0}};

        a_buf1_en <= 1'b0;
        a_buf1_we <= 1'b0;  
        a_buf1_addr <= {BRAM_ADDR_WIDTH{1'b0}};

    end else if(!a_sel) begin // Activation Buffer select 1
        a_buf1_en <= 1'b0;
        a_buf1_we <= 1'b0;  
        a_buf1_addr <= {BRAM_ADDR_WIDTH{1'b0}};

        case(state)
        IDLE: begin
            a_buf0_en <= 1'b0;
            a_buf0_we <= 1'b0;
            a_buf0_addr <= {BRAM_ADDR_WIDTH{1'b0}};
        end
        WEIGHTLOAD: begin
            if(count_weight == ROW ) begin
                a_buf0_en <= 1'b1;
                a_buf0_we <= 1'b0;
            end else begin
                a_buf0_en <= 1'b0;
                a_buf0_we <= 1'b0;
            end
        end
        MULTIPLY: begin
            if(count_mul < L*COL) begin
                a_buf0_en <= 1'b1;
                a_buf0_we <= 1'b0;
                a_buf0_addr <= (ROW/ NDATA) * (ROW * (K * (l + L * i) + k) + count_mul % COL); 
            end else begin
                a_buf0_en <= 1'b0;
            end
        end
        default: begin // state IDLE, OUTPUTLOAD
            a_buf0_en <= 1'b0;
            a_buf0_we <= 1'b0;
            a_buf0_addr <= {BRAM_ADDR_WIDTH{1'b0}};
        end
        endcase
    end else begin // Activation Buffer select 1
        a_buf0_en <= 1'b0;
        a_buf0_we <= 1'b0;  
        a_buf0_addr <= {BRAM_ADDR_WIDTH{1'b0}};

        case(state)
        IDLE: begin
            a_buf1_en <= 1'b0;
            a_buf1_we <= 1'b0;
            a_buf1_addr <= {BRAM_ADDR_WIDTH{1'b0}};
        end
        WEIGHTLOAD: begin
            if(count_weight == ROW ) begin
                a_buf1_en <= 1'b1;
                a_buf1_we <= 1'b0;
            end else begin
                a_buf1_en <= 1'b0;
                a_buf1_we <= 1'b0;
            end
        end
        MULTIPLY: begin
            if(count_mul < L*COL) begin
                a_buf1_en <= 1'b1;
                a_buf1_we <= 1'b0;
                a_buf1_addr <= (ROW / NDATA) * (COL * (K * (l + L * i) + k) + count_mul % COL);
            end else begin
                a_buf1_en <= 1'b0;
            end
        end
        default: begin // state IDLE, OUTPUTLOAD
            a_buf1_en <= 1'b0;
            a_buf1_we <= 1'b0;
            a_buf1_addr <= {BRAM_ADDR_WIDTH{1'b0}};
        end
        endcase
    end
end


// Act_Allign unit & Systolic Array control

always @(posedge clk) begin
    if(!rstn) begin
        a_allign_rstn <= 1'b0;
        a_allign_en <= 1'b0;
        a_allign_we <= 1'b0;
        a_allign_re <= 1'b0;

        sys_array_control <= 1'b1;
    end else begin
        case(state)
        IDLE: begin
            a_allign_rstn <= 1'b0;
            a_allign_en <= 1'b0;
            a_allign_we <= 1'b0;
            a_allign_re <= 1'b0;

            sys_array_control <= 1'b0;
        end
        WEIGHTLOAD: begin
            sys_array_control <= 1'b1;
        end
        MULTIPLY: begin
            a_allign_re[ROW-1 : 1] <= a_allign_re[ROW-2 : 0];

            if(count_mul == 0) begin
                a_allign_rstn <= 1'b1;
            end else if(count_mul == 1) begin
                sys_array_control <= 1'b0;
                a_allign_en <= 1'b1;
                a_allign_we <= 1'b1;
            end else if (count_mul == 2) begin
                a_allign_re[0] <= 1'b1;
            end else if (count_mul == L * COL + 1) begin
                a_allign_en <= 1'b0;
                a_allign_we <= 1'b0;
            end else if (count_mul == L * COL + 2) begin
                a_allign_re[0] <= 1'b0;
            end 
        end
        default: begin // state IDLE, WEIGHTLOAD, OUTPUTLOAD
            a_allign_rstn <= 1'b0;
            a_allign_en <= 1'b0;
            a_allign_we <= 1'b0;
            a_allign_re <= 1'b0;

            sys_array_control <= 1'b0;
        end
        endcase
    end
end

 //
// PSUM CONTROL
always @ (posedge clk) begin
    if(!rstn) begin
        psum_ctrl_sel <= 1'b0;
    end else begin
        case(state)
        IDLE: begin
            if(start) begin
                psum_ctrl_sel <= !psum_ctrl_sel;
            end
        end 

        // WEIGHTLOAD:
        MULTIPLY: begin
            if(!opcode[0]) begin
                psum_baseaddr <= ROW * (k + J * L * i);              
            end else begin
                psum_baseaddr <= ROW * (j + K * L * i);
            end

            // if(count_mul == 0) begin
            //     p_allign_rstn <= 1'b0;
            // end else 
            if(count_mul == (COL + 2)) begin
                psum_start <= 1'b1;
            end else if(count_mul == (COL + 3)) begin
                psum_start <= 1'b0;
            end else if(count_mul == ROW + COL + L * COL) begin
                psum_ctrl_sel <= !psum_ctrl_sel;
                // if(l == L - 1 & idx_a == ROW - 1) begin
                //     psum_ctrl_sel <= !psum_ctrl_sel;
                // end
            end
        end
        // OUTPUTLOAD: begin
        //     ___
        // end
        default: begin
            psum_baseaddr <= {BRAM_ADDR_WIDTH{1'b0}};
        end
        endcase
    end
end


psum_control #(
    .ROW(ROW),
    .COL(COL),
    .O_BRAM_ADDR_WIDTH(O_BRAM_ADDR_WIDTH),
    .NDATA(NDATA)
)psum_control(
    .clk(clk),
    .rstn(rstn),
    .start(psum_start),
    .is_first_psum(is_first_psum_reg),
    .is_outputload(psum_to_out),
    .outputload_fin(outputload_fin),
    .o_sel(o_sel),

    .A(A),
    .C(C),
    .L(L),

    .psum_baseaddr(psum_baseaddr),
    .psum_ctrl_sel(psum_ctrl_sel),

    .p_allign_rstn(p_allign_rstn),
    .p_allign_en(p_allign_en),
    .p_allign_we(p_allign_we),
    .p_allign_re(p_allign_re),

    .psum_sel(psum_sel),
    .first_psum(first_psum),

    .psum_en(psum_en),
    .psum_we(psum_we),
    .psum_addr(psum_addr),
    .psum_prev_addr(psum_prev_addr),

    .o_buf0_en(o_buf0_en),
    .o_buf0_we(o_buf0_we),
    .o_buf0_addr(o_buf0_addr),

    .o_buf1_en(o_buf1_en),
    .o_buf1_we(o_buf1_we),
    .o_buf1_addr(o_buf1_addr)
);

endmodule



    
            

















