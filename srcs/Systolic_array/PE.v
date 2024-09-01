// pe.v

module pe
#(
    parameter  IN_DATA_WIDTH = 8,
    parameter OUT_DATA_WIDTH = 32
)
(
    input clk,
    input rstn,

    input weight_en,

    input signed [IN_DATA_WIDTH-1:0] in_west,
    input signed [IN_DATA_WIDTH-1:0] in_north_weight,
    input signed [OUT_DATA_WIDTH-1:0] in_north_psum,

    output reg [ IN_DATA_WIDTH-1:0] out_east,
    output reg [ IN_DATA_WIDTH-1:0] out_south_weight,
    output reg [OUT_DATA_WIDTH-1:0] out_south_psum
);

reg signed [IN_DATA_WIDTH-1:0] weight;

wire signed [IN_DATA_WIDTH-1:0] weight_mux;
assign weight_mux = weight_en ? in_north_weight : weight;

wire signed [OUT_DATA_WIDTH-1:0] result;

assign result = in_west * weight_mux + in_north_psum;

always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
        weight <= {IN_DATA_WIDTH{1'b0}};
        out_east <= {IN_DATA_WIDTH{1'b0}};
        out_south_weight <= {IN_DATA_WIDTH{1'b0}};
        out_south_psum <= {OUT_DATA_WIDTH{1'b0}};
    end else begin
        if (weight_en) begin
            weight <= in_north_weight;
        end else begin
            weight <= weight;
        end
        out_east <= in_west;
        out_south_weight <= in_north_weight;
        out_south_psum <= result;
    end
end

endmodule