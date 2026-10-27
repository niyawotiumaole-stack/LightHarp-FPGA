`timescale 1ns/1ps
// Two-flop synchronizer and independent 100us stable-state filters.
module ir_filter #(parameter CYCLES=5000)(input clk,input [7:0] raw,output [7:0] blocked);
reg [7:0] meta=255,sync=255,stable=255;
reg [12:0] count[0:7]; integer i;
initial for(i=0;i<8;i=i+1) count[i]=0;
always @(posedge clk) begin
 meta<=raw; sync<=meta;
 for(i=0;i<8;i=i+1) begin
  if(sync[i]==stable[i]) count[i]<=0;
  else if(count[i]==CYCLES-1) begin stable[i]<=sync[i];count[i]<=0;end
  else count[i]<=count[i]+1'b1;
 end
end
assign blocked=~stable;
endmodule
