`timescale 1ns/1ps
// Sample-frame scheduler: scan 8 strings, at most 8*(N+3) clocks/frame.
// New press gets idle voice; if full, first released voice fades and retriggers.
// Held voices are never stolen. Simultaneous events reserve distinct slots.
module allocator #(parameter N=32)(input clk,tick,input [7:0] blocked,
 input [N-1:0] busy,output reg [N-1:0] gates=0,starts=0,
 output reg [N*3-1:0] owners=0,output reg [31:0] dropped=0);
reg [7:0] previous=0,rise=0,fall=0;
reg [3:0] str=0;reg [5:0] idx=0;
reg [5:0] free_slot=63,release_slot=63;
reg [1:0] state=0;
integer v;
always @(posedge clk) begin
 if(tick) begin
  starts<=0;rise<=blocked&~previous;fall<=~blocked&previous;previous<=blocked;
  str<=0;state<=1;
 end else case(state)
 1:begin
  // A release only affects voices owned by this held event. Older tails have gate=0.
  if(fall[str]) for(v=0;v<N;v=v+1) if(owners[v*3+:3]==str[2:0]) gates[v]<=0;
  if(rise[str]) begin idx<=0;free_slot<=63;release_slot<=63;state<=2;end
  else if(str==7) state<=0;else str<=str+1'b1;
 end
 2:begin
  if(!gates[idx] && !starts[idx]) begin
   if(!busy[idx] && free_slot==63)free_slot<=idx;
   if(release_slot==63)release_slot<=idx;
  end
  if(idx==N-1)state<=3;else idx<=idx+1'b1;
 end
 3:begin
  if(free_slot!=63)begin gates[free_slot]<=1;starts[free_slot]<=1;owners[free_slot*3+:3]<=str[2:0];end
  else if(release_slot!=63)begin gates[release_slot]<=1;starts[release_slot]<=1;owners[release_slot*3+:3]<=str[2:0];end
  else dropped<=dropped+1'b1;
  if(str==7)state<=0;else begin str<=str+1'b1;state<=1;end
 end
 default:state<=0;
 endcase
end
endmodule
