// fp_adder.v

module fp_adder_v2
#(parameter BIAS = 127)(
    input [31:0] a,
    input [31:0] b,

    output reg [31:0] out
);

////////////////////////////////////////////////////////////

// signals for zero, subnormal, inf, NaN
wire zero_a, zero_b;
assign zero_a = ~|a[30:23] & ~|a[22:0];
assign zero_b = ~|b[30:23] & ~|b[22:0];

wire subnormal_a, subnormal_b;
assign subnormal_a = ~|a[30:23] & |a[22:0];
assign subnormal_b = ~|b[30:23] & |b[22:0];

wire inf_a, inf_b;
assign inf_a = &a[30:23] & ~|a[22:0];
assign inf_b = &b[30:23] & ~|b[22:0];

wire NaN_a, NaN_b;
assign NaN_a = &a[30:23] & |a[22:0];
assign NaN_b = &b[30:23] & |b[22:0];

// wires for a, b
wire s_a, s_b;
wire [7:0] e_a, e_b;
wire [23:0] m_a, m_b;

// extract signs, exponents, mantissas from a, b
assign s_a = a[31];
assign s_b = b[31];

assign e_a = subnormal_a ? 8'd1 : a[30:23];
assign e_b = subnormal_b ? 8'd1 : b[30:23];

assign m_a = subnormal_a ? { 1'b0, a[22:0] } : { 1'b1, a[22:0] };
assign m_b = subnormal_b ? { 1'b0, b[22:0] } : { 1'b1, b[22:0] };

////////////////////////////////////////////////////////////
// XOR signs
wire s_diff;
wire s_out;
// compare exponents
wire signed [8:0] e_a_minus_e_b;
wire s_larger;
wire [7:0] e_larger;
wire signed [48:0] m_larger, m_smaller;

assign s_diff = s_a ^ s_b;

assign s_out = s_larger ^ m_neg;

assign e_a_minus_e_b = e_a - e_b;

assign s_larger = e_a_minus_e_b[8] ? s_b : s_a;

assign e_larger = e_a_minus_e_b[8] ? e_b : e_a;

assign m_larger = e_a_minus_e_b[8] ? { 1'b0, m_b, 24'd0 } : {1'b0, m_a, 24'd0 };
assign m_smaller= e_a_minus_e_b[8] ? {1'b0, m_a, 24'd0 } >> -e_a_minus_e_b : { 1'b0, m_b, 24'd0 } >> e_a_minus_e_b;

wire signed [48:0] m_adjusted;
assign m_adjusted = s_diff ? -m_smaller : m_smaller;

////////////////////////////////////////////////////////////

// add mantissas
wire [49:0] m_sum;
assign m_sum = m_larger + m_adjusted;

wire m_neg;
assign m_neg = m_sum[49];

wire [48:0] m_abs_sum;
assign m_abs_sum = m_neg ? -m_sum : m_sum;

// leading zeros counter
wire [5:0] lz;
lzc64 m_lzc(.data({ m_sum, {15{1'b1}} }), .count(lz));

// normalize sum (for subnormals)
wire shift1;
assign shift1 = (lz > 1);
wire [48:0] m_normalized_sum;
assign m_normalized_sum = shift1 ? m_sum << lz - 2 : m_sum;

// round sum (rtne)
wire [2:0] GRS;
assign GRS = m_normalized_sum[48] ? { m_normalized_sum[24], m_normalized_sum[23], |m_normalized_sum[22:0] }
                                  : { m_normalized_sum[23], m_normalized_sum[22], |m_normalized_sum[21:0] };
wire [24:0] m_rounded_sum;
assign m_rounded_sum = m_normalized_sum[48] ? GRS[2] & (|GRS[1:0] | m_normalized_sum[25]) ? { (m_normalized_sum[48:25] + 1'b1), 1'b0 }
                                                                                          : { m_normalized_sum[48:25], 1'b0 }
                                            : GRS[2] & (|GRS[1:0] | m_normalized_sum[24]) ? m_normalized_sum[47:24] + 1'b1
                                                                                          : m_normalized_sum[47:24];

// normalize product
wire [23:0] m_final_sum;
assign m_final_sum = m_rounded_sum[24] ? m_rounded_sum[24:1] : m_rounded_sum[23:0];
wire shift2;
assign shift2 = m_rounded_sum[24];

////////////////////////////////////////////////////////////

// align exponent
wire signed [8:0] e_out;
assign e_out = shift1 ? e_larger - (lz - 2) + shift2 : e_larger + shift2;

// detect underflow, overflow
wire underflow, overflow;
assign underflow = (e_out < $signed(9'd0));
assign overflow = (e_out >= $signed(9'd255));

// final mantissa
wire [22:0] m_out;
assign m_out = (e_out == 9'd0) ? m_final_sum[23:1] : m_final_sum[22:0];

////////////////////////////////////////////////////////////

always @(*) begin
    if (NaN_a | NaN_b) begin // either a, b is NaN -> NaN
        out = { s_out, 8'hFF, 23'h7FFFFF };
    end else if (zero_a) begin // a is zero -> b
        out = b;
    end else if (zero_b) begin // b is zero -> a
        out = a;
    end else if (inf_a & inf_b) begin // a, b is inf
        if (s_diff) begin // different sign -> NaN
            out = { s_out, 8'hFF, 23'h7FFFFF };
        end else begin // same sign -> a or b
            out = a;
        end
    end else if (underflow) begin // underflow -> zero
        out = { s_out, 8'h00, 23'd0 };
    end else if (overflow) begin // overflow -> inf
        out = { s_out, 8'hFF, 23'd0 };
    end else begin
        out = { s_out, e_out[7:0], m_out };
    end
end

////////////////////////////////////////////////////////////

endmodule