`timescale 1ns/1ps
// PERIOD_US: minimum trigger interval. TIMEOUT_US: total response deadline.
module hc_sr04 #(parameter CLK_HZ=50_000_000, PERIOD_US=60_000, TIMEOUT_US=60_000)
(input wire clk,echo,output reg trig=0,output reg [7:0] dist_cm=0,output reg valid=0);
localparam US_DIV=CLK_HZ/1_000_000;
localparam UW=(US_DIV>1)?$clog2(US_DIV):1;
localparam PW=(PERIOD_US>1)?$clog2(PERIOD_US+1):1;
localparam TW=(TIMEOUT_US>1)?$clog2(TIMEOUT_US+1):1;
reg [UW-1:0] divider=0;
wire us_tick=(divider==US_DIV-1);
always @(posedge clk) if(us_tick) divider<=0; else divider<=divider+1'b1;
reg meta=0,sync=0,previous=0;
always @(posedge clk) begin meta<=echo;sync<=meta;previous<=sync;end
localparam IDLE=0,TRIGGER=1,WAIT_RISE=2,MEASURE=3;
reg [1:0] state=IDLE;
reg [PW-1:0] period=0;
reg [TW-1:0] elapsed=0,width_us=0;
reg [3:0] trig_count=0;
wire [63:0] cm_product=width_us*64'd1130+64'd32768;
always @(posedge clk) begin
 valid<=0;
 if(us_tick && period<PERIOD_US) period<=period+1'b1;
 case(state)
 IDLE:begin
  trig<=0;
  // Discard a high echo that was already present before a new trigger.
  if(us_tick && period>=PERIOD_US-1 && !sync) begin
   trig<=1;trig_count<=0;period<=0;state<=TRIGGER;
  end
 end
 TRIGGER:if(us_tick) begin
  if(trig_count==9) begin trig<=0;elapsed<=0;state<=WAIT_RISE;end
  else trig_count<=trig_count+1'b1;
 end
 WAIT_RISE,MEASURE:begin
  if(us_tick && elapsed>=TIMEOUT_US-1) state<=IDLE;
  else begin
   if(us_tick) elapsed<=elapsed+1'b1;
   if(state==WAIT_RISE) begin
    if(sync && !previous) begin width_us<=0;state<=MEASURE;end
   end else if(!sync) begin
    if(width_us!=0) begin
     dist_cm<=(cm_product[63:16]>255)?8'd255:cm_product[23:16];
     valid<=1;
    end
    state<=IDLE;
   end else if(us_tick) width_us<=width_us+1'b1;
  end
 end
 default:begin state<=IDLE;trig<=0;end
 endcase
end
endmodule
