`timescale 1ns/1ps
// Single 335.54ms feed-forward echo at Fs=48828.125; dry + 1/4 delay.
// Synchronous single read/write ring; invalid startup RAM never reaches output.
module echo #(parameter DEPTH=16384)(input clk,tick,enable,input signed [15:0] dry,
 output reg signed [15:0] wet=0,output reg clipped=0);
reg signed [15:0] mem[0:DEPTH-1];
reg [13:0] ptr=0;reg filled=0;
reg signed [15:0] delayed=0;
wire signed [17:0] total=$signed({{2{dry[15]}},dry})+
 (enable&&filled?($signed({{2{delayed[15]}},delayed})>>>2):18'sd0);
always @(posedge clk)begin
 // Write-through inference is supported by GW5AT BSRAM. wet uses old delayed.
 if(tick)delayed<=dry;else delayed<=mem[ptr];
 if(tick)begin
  mem[ptr]<=dry;
  if(ptr==DEPTH-1)begin ptr<=0;filled<=1;end else ptr<=ptr+1'b1;
  clipped<=(total>32767 || total< -32768);
  if(total>32767)wet<=32767;else if(total< -32768)wet<=-32768;else wet<=total[15:0];
 end
end
endmodule
