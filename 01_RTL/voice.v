`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// voice.v  --  one oscillator: phase accumulator + envelope + timbre
//
// EXPR_EN = 0 : original behaviour (sine or triangle selected by `tone`).
// EXPR_EN = 1 : `expr` (0..255) crossfades the selected wave towards a version
//               with an octave-up sine mixed in. expr=0 has the same values as
//               the original voice, expr=255 is the bright end.
//
// The octave component is read from the same mathematical sine table at twice
// the phase rate. A second table instance/read path is used; no recorded PCM.
// -----------------------------------------------------------------------------
module voice #(
    parameter EXPR_EN = 0
)(
    input  wire               clk,
    input  wire               tick,
    input  wire               gate,
    input  wire               start,
    input  wire [31:0]        increment,
    input  wire               tone,
    input  wire [7:0]         expr,
    input  wire [2:0]         a,
    input  wire [2:0]         d,
    input  wire [2:0]         s,
    input  wire [2:0]         r,
    output signed [15:0]      audio,
    output wire               busy,
    output wire               audible
);

reg [31:0] phase     = 32'd0;
reg [31:0] phase_inc = 32'd0;
wire [7:0] level;

envelope env(clk, tick, gate, start, a, d, s, r, level, busy);

always @(posedge clk) if (tick) begin
    phase_inc <= increment;
    phase     <= phase + phase_inc;
end

// Triangle from the top 17 phase bits, offset-binary to signed.
wire [15:0] tri_bits = phase[31] ? ~phase[30:15] : phase[30:15];
wire signed [15:0] tri_wave = $signed(tri_bits ^ 16'h8000);

wire signed [15:0] sine;
sine_table rom(phase[31:24], sine);

wire signed [15:0] base_wave = tone ? sine : tri_wave;

reg signed [15:0] wave = 16'sd0;

generate if (EXPR_EN) begin : morph
    // Octave-up read of the same sine table; still a mathematical table.
    wire signed [15:0] sine2;
    sine_table rom_oct(phase[30:23], sine2);

    // Register the table outputs before arithmetic. Each stage carries its
    // own base wave and expression so changing controls cannot mix samples.
    reg signed [15:0] base_q=0, sine_q=0, sine2_q=0;
    reg [7:0] expr_q=0, expr_delta=0;
    reg signed [15:0] base_delta=0, base_blend=0;
    reg signed [16:0] delta_q=0;
    reg signed [25:0] blend_q=0;
    wire signed [16:0] sum17  = $signed(sine_q) + $signed(sine2_q);
    wire signed [15:0] bright = sum17[16:1];              // (sine + sine2) / 2
    wire signed [16:0] delta  = $signed(bright) - $signed(base_q);
    wire signed [26:0] mixed  = $signed(base_blend) + (blend_q >>> 8);

    always @(posedge clk) begin
        base_q<=base_wave; sine_q<=sine; sine2_q<=sine2; expr_q<=expr;
        base_delta<=base_q; delta_q<=delta; expr_delta<=expr_q;
        base_blend<=base_delta; blend_q<=delta_q*$signed({1'b0,expr_delta});
        if      (mixed >  27'sd32767) wave <= 16'sd32767;
        else if (mixed < -27'sd32768) wave <= -16'sd32768;
        else                          wave <= mixed[15:0];
    end
end else begin : plain
    always @(posedge clk) wave <= base_wave;
end
endgenerate

reg signed [24:0] product = 25'sd0;
always @(posedge clk) begin
    product <= wave * $signed({1'b0, level});
end

// Product is bounded to signed24 by signed16 * unsigned8 (0..255).
assign audio = $signed(product[23:8]);
// Envelope nonzero is a digital proxy; acoustic audibility must be measured.
assign audible = (level != 0);

endmodule

