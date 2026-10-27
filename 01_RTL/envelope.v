`timescale 1ns/1ps
// Independent sample-rate ADSR. Start while active performs a fast fade
// before attack, never abruptly resets a nonzero envelope. Up to 64 samples.
module envelope(input clk,tick,gate,start,input [2:0] a,d,s,r,
 output [7:0] level,output busy);
localparam IDLE=0,A=1,D=2,S=3,R=4,KILL=5;
reg [2:0] state=IDLE;
reg [15:0] amp=0,target=0;
reg [9:0] delta=0;
reg [7:0] div=0,count=0;
reg [6:0] steps=0;
reg old_gate=0;
function [7:0] period; input [2:0] x;begin
 case(x) 0:period=0;1:period=3;2:period=15;3:period=63;default:period=255;endcase
end endfunction
function [15:0] sustain; input [2:0] x;begin
 case(x) 0:sustain=0;1:sustain=16384;2:sustain=32768;3:sustain=49152;default:sustain=65280;endcase
end endfunction
wire [15:0] st=sustain(s);
wire [15:0] dd=16'd65280-st;
assign level=amp[15:8]; assign busy=(state!=IDLE);
always @(posedge clk) if(tick) begin
 old_gate<=gate;
 if(start) begin
  count<=0;steps<=0;
  if(amp!=0) state<=KILL;
  else if(gate) begin state<=A;target<=65280;delta<=510;div<=period(a);end
  else state<=IDLE;
 end else if(state==KILL) begin
  if(amp>1024) amp<=amp-16'd1024;
  else begin amp<=0;count<=0;steps<=0;
   if(gate) begin state<=A;target<=65280;delta<=510;div<=period(a);end
   else state<=IDLE;
  end
 end else if(!gate && old_gate) begin
  state<=R;target<=0;delta<={1'b0,amp[15:7]};div<=period(r);count<=0;steps<=0;
 end else case(state)
 IDLE:amp<=0;
 S:begin
  if(amp<st) amp<=(st-amp<=256)?st:amp+16'd256;
  else if(amp>st) amp<=(amp-st<=256)?st:amp-16'd256;
 end
 A,D,R:begin
  if(count==div) begin
   count<=0;
   if(steps==127) begin
    amp<=target;steps<=0;
    if(state==A) begin state<=D;target<=st;delta<={1'b0,dd[15:7]};div<=period(d);end
    else if(state==D) state<=S; else state<=IDLE;
   end else begin steps<=steps+1'b1;if(state==A)amp<=amp+delta;else amp<=amp-delta;end
  end else count<=count+1'b1;
 end
 default:begin amp<=0;state<=IDLE;end
 endcase
end
endmodule
