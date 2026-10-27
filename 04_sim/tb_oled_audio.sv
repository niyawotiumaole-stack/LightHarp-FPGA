`timescale 1ns/1ps
module tb_oled_audio;
reg clk=0;always #10 clk=~clk;
reg[7:0] sensors=255;reg echo=0;
wire t,b,l,d,cs,sc,mo,dc,re,bt,bb,bl,bd;
harp8oled dut(clk,sensors,1'b1,1'b1,1'b1,1'b1,echo,t,b,l,d,cs,sc,mo,dc,re);
harp_core_base #(.N(8),.EXPR_ENABLE(1)) baseline(.clk(clk),.sensor_n(sensors),.enc_s1(1'b1),.enc_s2(1'b1),.enc_key_n(1'b1),.test_key_n(1'b1),.echo(echo),.trig(bt),.DAC_BCK(bb),.DAC_LRCK(bl),.DAC_DATA(bd));
defparam dut.core.dim2.sonar.PERIOD_US=2000;
defparam baseline.dim2.sonar.PERIOD_US=2000;
defparam dut.display.POWER_CYCLES=10;
defparam dut.display.RESET_CYCLES=5;
defparam dut.display.FRAME_CYCLES=100;
integer clocks=0,display_edges=0;reg expressed=0;
always @(posedge sc)display_edges=display_edges+1;
always @(negedge clk)begin
 clocks=clocks+1;
 if(clocks>10 && {t,b,l,d}!=={bt,bb,bl,bd})$fatal(1,"OLED changed audio or sonar timing");
 if(clocks>10 && (^{t,b,l,d,cs,sc,mo,dc,re})===1'bx)$fatal(1,"undefined top output");
 if(dut.core.expr>0)expressed=1;
end
initial begin
 #500000;sensors=0;
 @(posedge t);@(negedge t);#20000;echo=1;#986000;echo=0;
 #10000000;
 if(dut.ui_status[32:27]!==8)$fatal(1,"active count status");
 if(dut.ui_status[40:33]!==255)$fatal(1,"IR status");
 if(!dut.ui_status[57]||dut.ui_status[48:41]!==17)$fatal(1,"distance status");
 if(!expressed)$fatal(1,"no expression");
 sensors=255;#10000000;
 if(display_edges<8192)$fatal(1,"no full display refresh");
 $display("PASS OLED full top: audio I2S/sonar bit-exact to baseline, valid status, simultaneous refresh");$finish;
end
initial begin #40000000;$fatal(1,"timeout");end
endmodule
