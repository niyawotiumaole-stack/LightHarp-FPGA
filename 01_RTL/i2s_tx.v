`timescale 1ns/1ps
// Philips I2S: falling-edge drive, one-bit LRCK-to-MSB delay.
// 50MHz /16 BCK, /1024 LRCK. Left and right share one latched sample.
module i2s_tx(input clk,input signed [15:0] pcm,output tick,
 output reg bck=0,lrck=0,data=0);
reg [2:0] half_count=0;reg [5:0] slot=0;reg [15:0] word=0;
assign tick=(half_count==7)&&bck&&(slot==0);
always @(posedge clk)begin
 if(half_count==7)begin
  half_count<=0;bck<=~bck;
  if(bck)begin
   lrck<=slot[5];if(slot==0)word<=pcm;
   if(slot[4:0]>=1 && slot[4:0]<=16)data<=word[16-slot[4:0]];else data<=0;
   slot<=slot+1'b1;
  end
 end else half_count<=half_count+1'b1;
end
endmodule
