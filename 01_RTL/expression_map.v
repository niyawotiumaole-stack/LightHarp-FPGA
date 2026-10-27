`timescale 1ns/1ps
// Rounded IIR reaches both endpoints; stale sonar returns smoothly to neutral.
module expression_map #(
 parameter D_MIN=7,D_MAX=28,IIR_SHIFT=1,SLEW_STEP=2,
 parameter CLK_HZ=50_000_000,STALE_MS=1000
)(input wire clk,input wire [7:0] dist_cm,input wire valid,output reg [7:0] expr=0);
localparam KD=CLK_HZ/1000;
localparam KW=(KD>1)?$clog2(KD):1;
localparam SW=(STALE_MS>1)?$clog2(STALE_MS+1):1;
localparam SCALE=(255*4096)/(D_MAX-D_MIN);
reg [KW-1:0] count=0;
wire ms_tick=(count==KD-1);
always @(posedge clk) if(ms_tick) count<=0;else count<=count+1'b1;
reg [SW-1:0] age=0;
wire [31:0] dpos=(dist_cm<=D_MIN)?0:dist_cm-D_MIN;
wire [31:0] mapped=(dpos*SCALE+2048)>>12;
wire [7:0] target=(dist_cm<=D_MIN)?8'd0:(dist_cm>=D_MAX)?8'd255:mapped[7:0];
reg [7:0] filt=0;
wire [8:0] distance_up={1'b0,target}-{1'b0,filt};
wire [8:0] distance_down={1'b0,filt}-{1'b0,target};
wire [31:0] up_step=(distance_up+((1<<IIR_SHIFT)-1))>>IIR_SHIFT;
wire [31:0] down_step=(distance_down+((1<<IIR_SHIFT)-1))>>IIR_SHIFT;
wire [7:0] slew=SLEW_STEP;
always @(posedge clk) begin
 if(valid) begin
  age<=0;
  if(target>filt) filt<=filt+up_step[7:0];
  else if(target<filt) filt<=filt-down_step[7:0];
 end else if(ms_tick) begin
  if(age<STALE_MS) age<=age+1'b1;
  if(age>=STALE_MS-1) filt<=0;
 end
 if(ms_tick) begin
  if(expr<filt) expr<=((filt-expr)>slew)?expr+slew:filt;
  else if(expr>filt) expr<=((expr-filt)>slew)?expr-slew:filt;
 end
end
endmodule
