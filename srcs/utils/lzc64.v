// lzc64.v

module lzc64
#(parameter DATA_WIDTH = 64)(
    input [63:0] data,

    output reg [5:0] count
);

wire [31:0] temp32;
assign temp32 = count[5] ? data[31:0] : data[63:32];

wire [15:0] temp16;
assign temp16 = count[4] ? temp32[15:0] : temp32[31:16];

wire [7:0] temp8;
assign temp8 = count[3] ? temp16[7:0] : temp16[15:8];

wire [3:0] temp4;
assign temp4 = count[2] ? temp8[3:0] : temp8[7:4];

wire [1:0] temp2;
assign temp2 = count[1] ? temp4[1:0] : temp4[3:2];

always @(*) begin
    count = { ~|data[63:32], ~|temp32[31:16], ~|temp16[15:8], ~|temp8[7:4], ~|temp4[3:2], ~temp2[1] };
end

endmodule