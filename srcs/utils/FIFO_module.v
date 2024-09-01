`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/08/08 18:39:26
// Design Name: 
// Module Name: FIFO_module
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


`timescale 1ns / 1ps

module FIFO_module #(
    parameter DATA_WIDTH = 16,
    parameter FIFO_DEPTH = 9,
    parameter PTR_SIZE = 4
    )
    (
        clk, rstn, ren, wen, din, dout, empty, full
    );
    
    input                          clk;
    input                          rstn;
    input                          ren;
    input                          wen;
    input       [DATA_WIDTH-1:0]   din;
    output reg  [DATA_WIDTH-1:0]   dout;
    output                         empty;
    output                         full;
    
    reg         [DATA_WIDTH-1:0]   mem_fifo [0:FIFO_DEPTH-1];
    reg             [PTR_SIZE:0]   r_rptr;
    reg             [PTR_SIZE:0]   r_wptr;
    
    assign  empty = (r_wptr == r_rptr);
    assign  full  = (r_wptr[PTR_SIZE-1:0] == r_rptr[PTR_SIZE-1:0]) & (r_wptr[PTR_SIZE] != r_rptr[PTR_SIZE]);
    
    always @ (posedge clk or negedge rstn) begin         // WRITE POINTER
        if (!rstn) begin
            r_wptr <= 'd0;
        end
        else if ((!full|ren)&&wen) begin
            r_wptr <= r_wptr + 1;
        end
        // else if (r_wpt )
        else begin
            r_wptr <= r_wptr;
        end
    end
    
    always @ (posedge clk or negedge rstn) begin          // READ POINTER
        if (!rstn) begin
            r_rptr <= 'd0;
        end
        else if (!empty && ren) begin
            r_rptr <= r_rptr + 1;
        end
        // else if (r_rptr[PTR_SIZE-1] == 1) begin
        //     r_rptr[PTR_SIZE-1] = ~r_rptr[PTR_SIZE-1];
        // end
        else begin
            r_rptr <= r_rptr;
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if(!rstn) begin
            dout <= {DATA_WIDTH{1'b0}};
        end
        else if (!empty && ren) begin // read
            dout <= mem_fifo[r_rptr[PTR_SIZE-1:0]];
        end else begin
            dout <= {DATA_WIDTH{1'b0}};
        end
    end

    always @ (posedge clk) begin         					     // READ and  WRITE
        // if (!full && wen) begin
        if((!full|ren)&&wen) begin // write
            mem_fifo[r_wptr[PTR_SIZE-1:0]] <= din;
        end
    end
    
    // always @ (posedge clk) begin                               //READ
    //     if (!empty && ren) begin
    //         dout <= mem_fifo[r_rptr[PTR_SIZE-1:0]];
    //     end
    // end
    
    // FOR CYCLE
    


endmodule
