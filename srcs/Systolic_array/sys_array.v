// sys_array.v

module sys_array
#(
    parameter  IN_DATA_WIDTH = 8,
    parameter OUT_DATA_WIDTH = 32,

    parameter ROW = 8,
    parameter COL = 8
)
(
    input clk,
    input rstn,

    input weight_en,

    input [IN_DATA_WIDTH*ROW-1:0] in_west,
    input [IN_DATA_WIDTH*COL-1:0] in_north,

//    output [IN_DATA_WIDTH*ROW-1 :0] out_east,
    output [OUT_DATA_WIDTH*COL-1 :0] out_south
);

wire [ IN_DATA_WIDTH-1:0] row_connect [ROW-1:0][COL-1:0];
wire [OUT_DATA_WIDTH-1:0] col_connect [COL-1:0][ROW:0];
wire [IN_DATA_WIDTH-1:0] weight_connect [COL-1:0][ROW:0];

genvar i, j;

generate
    for (i = 0; i < ROW; i = i + 1) begin
        assign row_connect[i][0] = in_west[(i + 1) * IN_DATA_WIDTH - 1:i * IN_DATA_WIDTH];
//        assign out_east[ (i + 1) * IN_DATA_WIDTH - 1:i * IN_DATA_WIDTH] = row_connect[i][COL];
    end
    for (j = 0; j < COL; j = j + 1) begin
        assign col_connect[j][0] = {OUT_DATA_WIDTH{1'b0}};
        assign out_south[(j + 1) * OUT_DATA_WIDTH - 1:j * OUT_DATA_WIDTH] = col_connect[j][ROW];
        assign weight_connect[j][0] = in_north[(j + 1) * IN_DATA_WIDTH - 1:j * IN_DATA_WIDTH ];
    end
endgenerate

generate
    for (i = 0; i < ROW; i = i + 1) begin
        for (j = 0; j < COL; j = j + 1) begin
            pe #(
                .IN_DATA_WIDTH(IN_DATA_WIDTH),
                .OUT_DATA_WIDTH(OUT_DATA_WIDTH)
            )
            m_pe(
                .clk(clk),
                .rstn(rstn),

                .weight_en(weight_en),

                .in_west(row_connect[i][j]),
                .in_north_weight(weight_connect[j][i]),
                .in_north_psum(col_connect[j][i]),

                .out_east(row_connect[i][j+1]),
                .out_south_weight(weight_connect[j][i+1]),
                .out_south_psum(col_connect[j][i+1])
            );
        end
    end
endgenerate

endmodule