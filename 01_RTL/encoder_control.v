`timescale 1ns/1ps
// 50 MHz. Passive EC11 module powered at 3.3V, inputs pulled up.
// REVERSE can be set to 1 if the actual knob's clockwise sequence is opposite.
module encoder_control #(parameter REVERSE = 1'b0, parameter TEST_MODE=0) (
    input wire clk,
    input wire s1,
    input wire s2,
    input wire key_n,
    output reg [4:0] volume = 5'd8,
    output reg muted = 1'b0,
    output reg [2:0] control_mode = 3'd0,
    output reg [4:0] pitch_index = 5'd12,
    output reg tone = 1'b0,
    output reg [2:0] attack_idx=0, decay_idx=2, sustain_idx=3, release_idx=3,
    output reg [4:0] test_voice=0
);
    reg [1:0] ab_meta=2'b11, ab_sync=2'b11, ab_stable=2'b11, ab_prev=2'b11;
    reg [1:0] ab_candidate=2'b11;
    reg [12:0] ab_count=13'd0;
    reg key_meta=1'b1, key_sync=1'b1, key_stable=1'b1;
    reg [18:0] key_count=19'd0;
    reg [25:0] hold_count=26'd0;
    reg long_fired=1'b0;
    reg signed [3:0] quarter_steps=4'sd0;
    wire [3:0] transition={ab_prev,ab_stable};
    // Gray-code legal forward and reverse quarter-step transitions.
    wire forward_step=(transition==4'b0001)||(transition==4'b0111)||
                      (transition==4'b1110)||(transition==4'b1000);
    wire backward_step=(transition==4'b0010)||(transition==4'b1011)||
                       (transition==4'b1101)||(transition==4'b0100);
    wire increase=REVERSE ? backward_step : forward_step;
    wire decrease=REVERSE ? forward_step : backward_step;

    always @(posedge clk) begin
        ab_meta <= {s1,s2};
        ab_sync <= ab_meta;
        key_meta <= key_n;
        key_sync <= key_meta;
        // Accept an AB state after 100us stability. Reject illegal 2-bit jumps.
        if (ab_sync!=ab_candidate) begin
            ab_candidate<=ab_sync;
            ab_count<=13'd0;
        end else if (ab_sync==ab_stable) ab_count<=13'd0;
        else if (ab_count==13'd4999) begin
            ab_stable<=ab_sync;
            ab_count<=13'd0;
        end else ab_count<=ab_count+13'd1;

        if (key_sync==key_stable) key_count<=19'd0;
        else if (key_count==19'd499999) begin
            key_stable<=key_sync;
            key_count<=19'd0;
            if (key_sync && !long_fired && hold_count<26'd39999999) muted<=~muted;
            if (!key_sync) begin hold_count<=26'd0; long_fired<=1'b0; end
        end else key_count<=key_count+19'd1;

        // Long press fires once at 0.8s; release does not also toggle mute.
        if (!key_stable && !long_fired) begin
            if (hold_count==26'd39999999) begin
                hold_count<=26'd0;
                long_fired<=1'b1;
                control_mode <= (control_mode==3'd6) ? 3'd0 : control_mode+3'd1;
            end else hold_count<=hold_count+26'd1;
        end

        if (ab_stable!=ab_prev) begin
            ab_prev<=ab_stable;
            if (increase) begin
                if (quarter_steps==4'sd3) begin
                    quarter_steps<=4'sd0;
                    if (TEST_MODE && control_mode==0) begin
                        test_voice<=test_voice+1'b1;
                    end else if (control_mode==2'd1) begin
                        if (pitch_index<5'd24) pitch_index<=pitch_index+5'd1;
                    end else if (control_mode==2'd2) tone<=1'b1;
                    else case(control_mode)
                    0: if (volume<5'd16) volume<=volume+5'd1;
                    3: if (attack_idx<3'd4) attack_idx<=attack_idx+3'd1;
                    4: if (decay_idx<3'd4) decay_idx<=decay_idx+3'd1;
                    5: if (sustain_idx<3'd4) sustain_idx<=sustain_idx+3'd1;
                    6: if (release_idx<3'd4) release_idx<=release_idx+3'd1;
                    default: ;
                    endcase
                end else quarter_steps<=quarter_steps+4'sd1;
            end else if (decrease) begin
                if (quarter_steps == -4'sd3) begin
                    quarter_steps<=4'sd0;
                    if (TEST_MODE && control_mode==0) begin
                        test_voice<=test_voice-1'b1;
                    end else if (control_mode==2'd1) begin
                        if (pitch_index>5'd0) pitch_index<=pitch_index-5'd1;
                    end else if (control_mode==2'd2) tone<=1'b0;
                    else case(control_mode)
                    0: if (volume>5'd0) volume<=volume-5'd1;
                    3: if (attack_idx>3'd0) attack_idx<=attack_idx-3'd1;
                    4: if (decay_idx>3'd0) decay_idx<=decay_idx-3'd1;
                    5: if (sustain_idx>3'd0) sustain_idx<=sustain_idx-3'd1;
                    6: if (release_idx>3'd0) release_idx<=release_idx-3'd1;
                    default: ;
                    endcase
                end else quarter_steps<=quarter_steps-4'sd1;
            end else quarter_steps<=4'sd0;
        end
    end
endmodule
