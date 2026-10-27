`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// harp_core.v  --  top-level core with an optional second performance axis
//
// EXPR_ENABLE = 0 : the core is the verified original (no ultrasonic logic,
//                   expr tied to 0, trig tied to 0).  Old tops keep working.
// EXPR_ENABLE = 1 : hc_sr04 + expression_map drive `expr`, which morphs the
//                   timbre of every voice without touching pitch or envelope.
// -----------------------------------------------------------------------------
module harp_core_base #(
    parameter N           = 32,
    parameter TEST_MODE   = 0,
    parameter ECHO_ENABLE = 0,
    parameter EXPR_ENABLE = 0,
    parameter [31:0] TEST_MASK = 32'hffffffff
)(
    input  wire        clk,
    input  wire [7:0]  sensor_n,
    input  wire        enc_s1,
    input  wire        enc_s2,
    input  wire        enc_key_n,
    input  wire        test_key_n,
    input  wire        echo,          // HC-SR04 ECHO (3.3 V), unused when EXPR_ENABLE=0
    output wire        trig,          // HC-SR04 TRIG
    output wire        DAC_BCK,
    output wire        DAC_LRCK,
    output wire        DAC_DATA,
    output wire        led,
    output wire [5:0]  active_count,
    output wire [31:0] drop_count
);

wire tick;
wire [7:0] blocked;
ir_filter filters(clk, sensor_n, blocked);

wire [4:0] volume, pitch;
wire muted, tone;
wire [2:0] mode, a, d, s, r;
wire [4:0] selected;
encoder_control #(.TEST_MODE(TEST_MODE)) knob(
    clk, enc_s1, enc_s2, enc_key_n,
    volume, muted, mode, pitch, tone, a, d, s, r, selected);

wire [255:0] notes;
note_bank bank(pitch, notes);

wire [N-1:0] pool_gate, pool_start, busy, audible;
wire [N*3-1:0] owner;
allocator #(N) alloc(clk, tick, blocked, busy, pool_gate, pool_start, owner, drop_count);

wire fx_enabled;
wire [2:0] count_idx;
wire [1:0] operation;
test_control tc(clk, test_key_n, count_idx, operation, fx_enabled);

wire [5:0] test_count = (count_idx == 0) ? 1  :
                        (count_idx == 1) ? 4  :
                        (count_idx == 2) ? 8  :
                        (count_idx == 3) ? 16 : 32;

reg [N-1:0] test_previous = 0;
wire [N-1:0] gates, starts;
wire [511:0] samples;

reg [8:0] gain = 9'd0;
reg active_tone = 1'b0;
wire [8:0] target_gain = muted ? 9'd0 : {volume, 4'b0000};

always @(posedge clk) if (tick) begin
    test_previous <= gates;
    if (!TEST_MODE && tone != active_tone) begin
        if (gain != 0) gain <= gain - 1'b1;
        else           active_tone <= tone;
    end else if (gain < target_gain) gain <= gain + 1'b1;
    else if (gain > target_gain)     gain <= gain - 1'b1;
end

// ---------------------------------------------------------------- second axis
wire [7:0] expr;

generate if (EXPR_ENABLE) begin : dim2
    wire [7:0] dist_cm;
    wire       dist_valid;
    hc_sr04 #(.CLK_HZ(50_000_000)) sonar(
        .clk(clk), .echo(echo), .trig(trig),
        .dist_cm(dist_cm), .valid(dist_valid));
    expression_map #(.D_MIN(7), .D_MAX(28), .CLK_HZ(50_000_000)) emap(
        .clk(clk), .dist_cm(dist_cm), .valid(dist_valid), .expr(expr));
end else begin : no_dim2
    assign expr = 8'd0;
    assign trig = 1'b0;
end
endgenerate

// ---------------------------------------------------------------- voices
genvar v;
generate
    for (v = 0; v < N; v = v + 1) begin : voices
        wire tg = (v < test_count) && TEST_MASK[v] &&
                  !(operation == 1 && v == selected) &&
                  !(operation == 2 && v % 2 == 0);

        assign gates[v]  = TEST_MODE ? tg : pool_gate[v];
        assign starts[v] = TEST_MODE ? (tg && !test_previous[v]) : pool_start[v];

        wire [31:0] ti  = ((200 + 17*v) << 18) + ((operation == 3 && v == selected) ? (5 << 18) : 0);
        wire [31:0] inc = TEST_MODE ? ti : notes[owner[v*3 +: 3]*32 +: 32];

        voice #(.EXPR_EN(EXPR_ENABLE)) synth(
            .clk(clk), .tick(tick),
            .gate(gates[v]), .start(starts[v]), .increment(inc),
            .tone(TEST_MODE ? 1'b1 : active_tone),
            .expr(expr),
            .a(TEST_MODE ? 3'd0 : a),
            .d(TEST_MODE ? 3'd0 : d),
            .s(TEST_MODE ? 3'd4 : s),
            .r(TEST_MODE ? 3'd0 : r),
            .audio(samples[v*16 +: 16]),
            .busy(busy[v]), .audible(audible[v]));
    end
    for (v = N; v < 32; v = v + 1) begin : padding
        assign samples[v*16 +: 16] = 16'd0;
    end
endgenerate

reg [5:0] active = 6'd0;
integer j;
reg [5:0] ct;
always @* begin
    ct = 6'd0;
    for (j = 0; j < N; j = j + 1) ct = ct + audible[j];
end
always @(posedge clk) if (tick) active <= ct;
assign active_count = active;

wire signed [20:0] sum;
mixer32 mix(clk, samples, sum);

// Fixed headroom: 8 voices /16, 16 /32, 32 /64; echo worst-case still <fullscale.
localparam SHIFT = (N <= 8) ? 4 : (N <= 16) ? 5 : 6;
wire signed [30:0] product = sum * $signed({1'b0, gain});
wire signed [30:0] scaled  = product >>> (SHIFT + 8);

reg signed [15:0] dry = 16'sd0;
reg clipped = 1'b0;
always @(posedge clk) if (tick) begin
    clipped <= (scaled > 32767 || scaled < -32768);
    if      (scaled >  32767) dry <= 16'sd32767;
    else if (scaled < -32768) dry <= -16'sd32768;
    else                      dry <= scaled[15:0];
end

wire signed [15:0] pcm;
wire echo_clip;
generate if (ECHO_ENABLE) begin : effect
    echo delay(clk, tick, fx_enabled, dry, pcm, echo_clip);
end else begin : bypass
    assign pcm = dry;
    assign echo_clip = 1'b0;
end
endgenerate

i2s_tx tx(clk, pcm, tick, DAC_BCK, DAC_LRCK, DAC_DATA);

reg [22:0] led_count = 23'd0;
reg [4:0]  slot = 5'd0;
wire [3:0] pulses = TEST_MODE ? {1'b0, count_idx} + 1'b1 : {1'b0, mode} + 1'b1;

always @(posedge clk) begin
    if (led_count == 4999999) begin
        led_count <= 23'd0;
        if (slot >= pulses*2 + 10) slot <= 5'd0;
        else                       slot <= slot + 1'b1;
    end else begin
        led_count <= led_count + 1'b1;
    end
end
assign led = ~((slot < pulses*2) && !slot[0]);

endmodule

