`timescale 1ns/1ps
module tb_ir_independent;
reg clk=0; always #10 clk=~clk;
reg[7:0] sensors=255;
wire t,b,l,d,cs,sc,mo,dc,re;
harp8oled dut(clk,sensors,1'b1,1'b1,1'b1,1'b1,1'b0,t,b,l,d,cs,sc,mo,dc,re);
defparam dut.display.POWER_CYCLES=10;
defparam dut.display.RESET_CYCLES=5;
defparam dut.display.FRAME_CYCLES=100;
defparam dut.display.SPI_DIV=2;
integer k,j,v,cnt;reg[7:0] mask;reg[7:0] charvalue;
task check;input[7:0] expected;begin
 #300000;
 if(dut.core.blocked!==expected || dut.ui_status[40:33]!==expected)$fatal(1,"input/status alias got %h expected %h",dut.core.blocked,expected);
 wait(dut.display.state==5); @(negedge clk); @(negedge clk);
 for(j=0;j<8;j=j+1)begin
 charvalue=dut.display.character(7,j+3);
 if(charvalue!==(expected[j]?8'd49:8'd48))$fatal(1,"OLED bit alias %d",j);
 end
end endtask
initial begin
 for(k=0;k<8;k=k+1)begin
 sensors=255;check(0);
 mask=1<<k;sensors=~mask;check(mask);
 cnt=0;for(v=0;v<8;v=v+1)if(dut.core.pool_gate[v])begin cnt=cnt+1;if(dut.core.owner[v*3+:3]!==k[2:0])$fatal(1,"wrong owner");end
 if(cnt!=1)$fatal(1,"duplicate gated voice %d",cnt);
 $display("PASS input %0d independent filter/status/OLED/voice owner",k+1);
 end
 sensors=8'hee;check(8'h11);
 $display("PASS simultaneous 1+5 yields 10001000 only when both inputs low");
 $finish;
end
initial begin #30000000;$fatal(1,"timeout");end
endmodule
