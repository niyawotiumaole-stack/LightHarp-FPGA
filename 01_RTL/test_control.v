`timescale 1ns/1ps
// KEY0: short press cycles 1/4/8/16/32 voices. Long press (0.8s)
// cycles all / mute selected voice / mute even voices / detune selected voice.
module test_control #(parameter DEBOUNCE=500000,HOLD=40000000)(input clk,key_n,output reg [2:0] count_idx=4,
 output reg [1:0] operation=0,output reg fx_enable=0);
reg m=1,s=1,stable=1,fired=0;
reg [18:0] debounce=0;reg [25:0] hold=0;
always @(posedge clk)begin
 m<=key_n;s<=m;
 if(s==stable)debounce<=0;
 else if(debounce==DEBOUNCE-1)begin
  stable<=s;debounce<=0;
  if(!s)begin hold<=0;fired<=0;end
  else if(!fired)begin count_idx<=(count_idx==3'd4)?3'd0:count_idx+3'd1;fx_enable<=~fx_enable;end
 end else debounce<=debounce+1'b1;
 if(!stable && !fired)begin
  if(hold==HOLD-1)begin operation<=operation+1'b1;fired<=1;end
  else hold<=hold+1'b1;
 end
end
endmodule
