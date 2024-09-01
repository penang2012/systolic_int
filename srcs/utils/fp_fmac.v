// fp_fmac.v

////////////////////////////////////////////////////////////
// mult bf16, acc fp32
// bf16: 1/8/7  [15] [14: 7] [ 6:0] -> a, w
// fp32: 1/8/23 [31] [30:23] [22:0] -> p
////////////////////////////////////////////////////////////

module fp_fmac
#(parameter BIAS = 127) (
    input [15:0] a, // activation
    input [15:0] w, // weight
    input [31:0] p, // partial sum

    output reg [31:0] out
);

////////////////////////////////////////////////////////////
// extract inputs
////////////////////////////////////////////////////////////

// signals for zero, subnormal, inf, NaN of a, w, p
wire zero_a, zero_w, zero_p;
wire subnormal_a, subnormal_w, subnormal_p;
wire inf_a, inf_w, inf_p;
wire NaN_a, NaN_w, NaN_p;

assign zero_a = ~|a[14: 7] & ~|a[ 6:0];
assign zero_w = ~|w[14: 7] & ~|w[ 6:0];
assign zero_p = ~|p[30:23] & ~|p[22:0];

assign subnormal_a = ~|a[14:7 ] & |a[ 6:0];
assign subnormal_w = ~|w[14:7 ] & |w[ 6:0];
assign subnormal_p = ~|p[30:23] & |p[22:0];

assign inf_a = &a[14:7 ] & ~|a[ 6:0];
assign inf_w = &w[14:7 ] & ~|w[ 6:0];
assign inf_p = &p[30:23] & ~|p[22:0];

assign NaN_a = &a[14:7 ] & |a[ 6:0];
assign NaN_w = &w[14:7 ] & |w[ 6:0];
assign NaN_p = &p[30:23] & |p[22:0];

// extract signs, exponents, mantissas from a, w, p
wire s_a, s_w, s_p;
wire [ 7:0] e_a, e_w, e_p;
wire [ 7:0] m_a, m_w; // for 1.m (or 0.m)
wire [23:0] m_p;

assign s_a = a[15];
assign s_w = w[15];
assign s_p = p[31];

assign e_a = subnormal_a ? 8'd1 : a[14: 7];
assign e_w = subnormal_w ? 8'd1 : w[14: 7];
assign e_p = subnormal_p ? 8'd1 : p[30:23];

assign m_a = subnormal_a ? { 1'b0, a[ 6:0] } : { 1'b1, a[ 6:0] };
assign m_w = subnormal_w ? { 1'b0, w[ 6:0] } : { 1'b1, w[ 6:0] };
assign m_p = subnormal_p ? { 1'b0, p[22:0] } : { 1'b1, p[22:0] };

////////////////////////////////////////////////////////////
// OP select
////////////////////////////////////////////////////////////

// XOR signs (a, w)
wire s_t; // temp; a * w
assign s_t = s_a ^ s_w;

// XOR signs (t, p)
wire s_diff; // if different, subtract exponents
assign s_diff = s_t ^ s_p;

////////////////////////////////////////////////////////////
// exp comp
////////////////////////////////////////////////////////////

// add exponents (a, w) (2 ~ 508)
wire [8:0] e_sum;
assign e_sum = e_a + e_w;

// subtract bias (t) (-125 ~ 381)
wire signed [9:0] e_t;
assign e_t = e_sum - BIAS;

// subtract exponents (t, p) (-380 ~ 379)
wire signed [9:0] e_diff;
assign e_diff = e_p - e_t;

// compare exponents (t, p)
wire s_larger;
wire [7:0] e_larger;

assign s_larger = e_diff[9] ? s_t : s_p;
assign e_larger = e_diff[9] ? e_t : e_p;

////////////////////////////////////////////////////////////
// multiplication
////////////////////////////////////////////////////////////

// multplicate mantissas (a, w)
wire [15:0] m_t;
assign m_t = m_a * m_w;

////////////////////////////////////////////////////////////
// significand align
////////////////////////////////////////////////////////////

// align mantissas (t, p)
wire signed [49:0] m_larger, m_smaller;
assign m_larger  = e_diff[9] ? { 1'b0, m_t, 9'd0, 24'd0 }            : { 1'b0, 1'b0, m_p, 24'd0 };
assign m_smaller = e_diff[9] ? { 1'b0, 1'b0, m_p, 24'd0 } >> -e_diff : { 1'b0, m_t, 9'd0, 24'd0 } >> e_diff;

// OP select (if s_diff(subtract), complement m_smaller)
wire signed [49:0] m_adjusted;
assign m_adjusted = s_diff ? -m_smaller : m_smaller;

////////////////////////////////////////////////////////////
// addition
////////////////////////////////////////////////////////////

// add mantissas
wire signed [50:0] m_sum;
assign m_sum = m_larger + m_adjusted;

// absolute sum
wire m_neg;
assign m_neg = m_sum[50];
wire [49:0] m_abs_sum;
assign m_abs_sum = m_neg ? -m_sum : m_sum;

////////////////////////////////////////////////////////////
// LZD (Leading Zero Detection)
////////////////////////////////////////////////////////////

// lzd
wire [5:0] lz;
lzc64 m_lzc(.data({ m_abs_sum, {14{1'b1}} }), .count(lz));

////////////////////////////////////////////////////////////
// normalize & round
////////////////////////////////////////////////////////////

// normalize sum (for subnormals)
wire shift1;
assign shift1 = (lz > 2);
wire [49:0] m_normalized_sum;
assign m_normalized_sum = shift1 ? m_abs_sum << lz - 2 : m_abs_sum;

// round sum (rtne)
wire [2:0] GRS;
assign GRS = m_normalized_sum[49] ? { m_normalized_sum[25], m_normalized_sum[24], |m_normalized_sum[23:0] }
                                  : m_normalized_sum[48] ? { m_normalized_sum[24], m_normalized_sum[23], |m_normalized_sum[22:0] }
                                                         : { m_normalized_sum[23], m_normalized_sum[22], |m_normalized_sum[21:0] };
wire [25:0] m_rounded_sum;
assign m_rounded_sum = m_normalized_sum[49] ? GRS[2] & (|GRS[1:0] | m_normalized_sum[26]) ? { (m_normalized_sum[49:26] + 1'b1), 2'b0 }
                                                                                          : { m_normalized_sum[49:26], 2'b0 }
                                            : m_normalized_sum[48] ? GRS[2] & (|GRS[1:0] | m_normalized_sum[25]) ? { (m_normalized_sum[48:25] + 1'b1), 1'b0 }
                                                                                                                 : { m_normalized_sum[48:25], 1'b0 }
                                            : GRS[2] & (|GRS[1:0] | m_normalized_sum[24]) ? m_normalized_sum[47:24] + 1'b1
                                                                                          : m_normalized_sum[47:24];

// normalize
wire [23:0] m_final_sum;
assign m_final_sum = m_rounded_sum[25] ? m_rounded_sum[25:2]
                                       : m_rounded_sum[24] ? m_rounded_sum[24:1]
                                                           : m_rounded_sum[23:0];
wire [1:0] shift2;
assign shift2 = { m_rounded_sum[25], ~m_rounded_sum[25] & m_rounded_sum[24] };

////////////////////////////////////////////////////////////
// final align
////////////////////////////////////////////////////////////

// output sign
wire s_out;
assign s_out = m_neg ^ s_larger;

// align exponent
wire signed [8:0] e_out;
assign e_out = shift1 ? e_larger - (lz - 2) + shift2 : e_larger + shift2;

// detect underflow, overflow
wire underflow, overflow;
assign underflow = (e_out <  $signed(9'd0));
assign  overflow = (e_out >= $signed(9'd255));

// final mantissa
wire [22:0] m_out;
assign m_out = (e_out == 9'd0) ? m_final_sum[23:1] : m_final_sum[22:0];

////////////////////////////////////////////////////////////
// output
////////////////////////////////////////////////////////////

always @(*) begin
    if (NaN_a | NaN_w | NaN_p) begin // either a, w, p is NaN -> NaN
        out = { s_out, 8'hFF, 23'h7FFFFF };
    end else if (zero_a & inf_w) begin // a is zero, w is inf -> NaN
        out = { s_out, 8'hFF, 23'h7FFFFF };
    end else if (inf_a & zero_w) begin // a is inf, w is zero -> NaN
        out = { s_out, 8'hFF, 23'h7FFFFF };
    end else if (zero_a | zero_w) begin // either a, w is zero -> p
        out = p;
    end else if (inf_a | inf_w) begin // either a, w is inf
        if (zero_p) begin // p is zero -> NaN
            out = { s_out, 8'hFF, 23'h7FFFFF };
        end else if (s_diff) begin // p is diff sign inf -> NaN
            out = { s_out, 8'hFF, 23'h7FFFFF };
        end else begin
            out = { s_out, 8'hFF, 23'd0 };
        end
    end else if (inf_p) begin
        out = p;
    end else if (underflow) begin // underflow -> zero
        out = { s_out, 8'h00, 23'd0 };
    end else if (overflow) begin // overflow -> inf
        out = { s_out, 8'hFF, 23'd0 };
    end else begin
        out = { s_out, e_out[7:0], m_out };
    end
end

endmodule