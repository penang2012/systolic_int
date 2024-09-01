module psum_control #(
    parameter ROW = 8,
    parameter COL = 8,

    parameter integer BRAM_ADDR_WIDTH = 11,
    parameter integer BRAM_DATA_WIDTH = 32,
    
    parameter integer P_BRAM_ADDR_WIDTH = 5,
    parameter integer P_BRAM_DATA_WIDTH = 256,
    
    parameter integer O_BRAM_ADDR_WIDTH = 7,
    parameter integer O_BRAM_DATA_WIDTH = 32,

    parameter NDATA = 4
)
(
    clk,
    rstn,

    start,

    is_first_psum,
    is_outputload,

    outputload_fin,

    o_sel,

    A,
    C,
    L,

    psum_baseaddr,
    psum_ctrl_sel,

    p_allign_rstn,
    p_allign_en,
    p_allign_we,
    p_allign_re,

    psum_sel,
    first_psum,

    psum_en,
    psum_we,
    psum_addr,
    psum_prev_addr,

    o_buf0_en,
    o_buf0_we,
    o_buf0_addr,

    o_buf1_en,
    o_buf1_we,
    o_buf1_addr

);
    input clk, rstn;
    input start;
    input is_first_psum;
    input is_outputload;
    input o_sel;

    output reg outputload_fin;

    input [7:0] A, C, L;

    input [O_BRAM_ADDR_WIDTH:0] psum_baseaddr;

    input psum_ctrl_sel;
    
    output reg p_allign_rstn;
    output reg p_allign_en, p_allign_re;
    output reg [COL-1:0] p_allign_we;

    output reg psum_sel;
    output reg first_psum;

    output reg [P_BRAM_ADDR_WIDTH-1:0] psum_addr, psum_prev_addr;
    output reg psum_en, psum_we;

    output reg o_buf0_en, o_buf0_we;
    output reg [O_BRAM_ADDR_WIDTH - 1:0] o_buf0_addr;

    output reg o_buf1_en, o_buf1_we;
    output reg [O_BRAM_ADDR_WIDTH - 1:0] o_buf1_addr;
    
    reg [P_BRAM_ADDR_WIDTH-1:0] psum_base;

    reg [7:0] count;
    reg [7:0] count_out;

    reg [3:0] count_psum;

    reg [1:0] state;

    parameter IDLE = 2'b00;
    parameter STORE = 2'b01;
    parameter OUTPUTLOAD = 2'b10;

    initial begin
        state = IDLE;
    end

    always @(posedge clk) begin
        if(!rstn) begin
            state <= IDLE;

            count_psum <= 4'b0;

            p_allign_rstn <= 1'b0;
            p_allign_en <= 1'b0;
            p_allign_re <= 1'b0;
            p_allign_we <= 1'b0;

            psum_en <= 1'b0;
            psum_we <= 1'b0;

            o_buf0_en <= 1'b0;
            o_buf0_we <= 1'b0;
            o_buf0_addr <= 8'b0;

            o_buf1_en <= 1'b0;
            o_buf1_en <= 1'b0;
            o_buf1_addr <= 8'b0;

            count <= 8'b0;
            count_out <= 8'b0;

            outputload_fin <= 1'b0;


        end else begin
            case(state)
            IDLE: begin
                outputload_fin <= 1'b0;
                psum_en <= 1'b0;
                psum_we <= 1'b0;

                count <= 8'b0;
                count_out <= 8'b0;
                count_psum <= 4'b0;

                if(start) begin
                    p_allign_rstn <= 1'b1;
                    p_allign_en <= 1'b1;
                    p_allign_we[0] <= 1'b1;

                    
                    psum_sel <= !psum_ctrl_sel; // Previous psum BRAM.
                    first_psum <= is_first_psum;
                    psum_prev_addr <= psum_baseaddr;
                    
                    psum_addr <= psum_baseaddr;

                    state <= STORE;
                end
            end
            STORE: begin
                count <= count + 1;

                p_allign_we[COL - 1 : 1] <= p_allign_we[COL - 2 : 0];

                if(count > ROW - 3) begin
                    if(count_psum == ROW - 1) begin
                        count_psum <= 4'b0;
                    end else begin
                        count_psum <= count_psum + 1;
                    end
                end 
                if(count > ROW - 3 & !first_psum) begin
                    if(count_psum == ROW - 1) begin
                        psum_prev_addr <= psum_prev_addr + C * ROW - ROW + 1;
                    end else begin
                        psum_prev_addr <= psum_prev_addr + 1;
                    end
                end 
                if(count > ROW) begin
                    if(count_psum == 2) begin
                        psum_addr <= psum_addr + C * ROW - ROW + 1;
                    end else begin
                        psum_addr <= psum_addr + 1;
                    end
                end 


                if(count == ROW - 3) begin
                    psum_en <= 1'b1;
                end else if(count == ROW - 1) begin
                    p_allign_re <= 1'b1;
                end else if(count == ROW) begin
                    psum_we <= 1'b1;
                end else if(count == L * ROW - 1) begin
                    p_allign_we[0] <= 1'b0;
                end else if(count == L * ROW + ROW - 1) begin
                    p_allign_re <= 1'b0;
                end else if(count == L * ROW + ROW) begin
                    psum_we <= 1'b0;
                    p_allign_rstn <= 1'b0;
                    if(is_outputload) begin
                        state <= OUTPUTLOAD;
                    end else begin
                        state <= IDLE;
                    end
                end
            end
            OUTPUTLOAD: begin
                count_out <= count_out + 1;

                psum_we <= 1'b0;
                psum_addr <= count_out - 1;

                if(!o_sel) begin
                    o_buf0_addr <= (COL) * (count_out - 3);
                end else begin
                    o_buf1_addr <= (COL) * (count_out - 3);
                end 

                if(count_out == 3) begin
                    if(!o_sel) begin
                        o_buf0_en <= 1'b1;
                        o_buf0_we <= 1'b1;
                    end else begin
                        o_buf1_en <= 1'b1;
                        o_buf1_we <= 1'b1;
                    end 
                end
                else if(count_out == 8 * A * C + 3) begin
                    state <= IDLE;
                    outputload_fin <= 1'b1;

                    o_buf0_en <= 1'b0;
                    o_buf0_we <= 1'b0;

                    o_buf1_en <= 1'b0;
                    o_buf1_we <= 1'b0;
                end
            end
            default: state <= IDLE;
            endcase
        end
    end
    

endmodule