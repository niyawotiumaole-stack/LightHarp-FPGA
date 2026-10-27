`timescale 1ns/1ps
// SH1106 128x64, 4-wire SPI mode0; column offset2. Independent of audio tick.
module oled_sh1106 #(
 parameter POWER_CYCLES=1000000,RESET_CYCLES=500000,
 parameter FRAME_CYCLES=5000000,SPI_DIV=25
)(input wire clk,input wire[63:0] status,
 output reg cs=1,output reg sck=0,output reg mosi=0,output reg dc=0,output reg res=1);
reg[63:0] snap=0;
reg[7:0] tx=0,shift=0;reg txdc=0,launch=0,busy=0,ending=0;
reg[15:0] spi_count=0;reg[2:0] bitidx=0;
always @(posedge clk)begin
 if(!busy)begin
  sck<=0;cs<=1;
  if(launch)begin busy<=1;ending<=0;cs<=0;dc<=txdc;shift<=tx;mosi<=tx[7];bitidx<=7;spi_count<=0;end
 end else if(spi_count==SPI_DIV-1)begin
  spi_count<=0;
  if(ending)begin cs<=1;busy<=0;ending<=0;end
  else if(!sck)sck<=1;
  else begin sck<=0;if(bitidx==0)ending<=1;else begin bitidx<=bitidx-1'b1;shift<={shift[6:0],1'b0};mosi<=shift[6];end end
 end else spi_count<=spi_count+1'b1;
end
reg[4:0] state=0,after_byte=0;
reg[31:0] timer=0;
reg[4:0] initidx=0;
reg[2:0] page=0,subcol=0;
reg[6:0] col=0;
reg[4:0] charidx=0;
reg[1:0] addridx=0,prep=0;
reg displayed=0;
reg[7:0] ch_q=32,pixel_q=0;
reg[39:0] glyph_q=0;
function[7:0] initbyte;input[4:0] i;begin case(i)
0:initbyte='hAE;1:initbyte='hD5;2:initbyte='h80;3:initbyte='hA8;4:initbyte='h3F;
5:initbyte='hD3;6:initbyte=0;7:initbyte='h40;8:initbyte='hAD;9:initbyte='h8B;
10:initbyte='hA1;11:initbyte='hC8;12:initbyte='hDA;13:initbyte='h12;14:initbyte='h81;
15:initbyte='h40;16:initbyte='hD9;17:initbyte='h22;18:initbyte='hDB;19:initbyte='h35;
20:initbyte='hA4;21:initbyte='hA6;default:initbyte='hAE;endcase end endfunction
function [39:0] glyph; input [7:0] ch; begin case(ch)
8'd65:glyph=40'h7e0909097e;
8'd66:glyph=40'h364949497f;
8'd67:glyph=40'h414141413e;
8'd68:glyph=40'h3e4141417f;
8'd69:glyph=40'h414949497f;
8'd70:glyph=40'h010909097f;
8'd71:glyph=40'h794949413e;
8'd72:glyph=40'h7f0808087f;
8'd73:glyph=40'h41417f4141;
8'd74:glyph=40'h013f414030;
8'd75:glyph=40'h412214087f;
8'd76:glyph=40'h404040407f;
8'd77:glyph=40'h7f020c027f;
8'd78:glyph=40'h7f3008067f;
8'd79:glyph=40'h3e4141413e;
8'd80:glyph=40'h060909097f;
8'd81:glyph=40'h5e2151413e;
8'd82:glyph=40'h462919097f;
8'd83:glyph=40'h3149494946;
8'd84:glyph=40'h01017f0101;
8'd85:glyph=40'h3f4040403f;
8'd86:glyph=40'h1f2040201f;
8'd87:glyph=40'h3f4038403f;
8'd88:glyph=40'h6314081463;
8'd89:glyph=40'h0304780403;
8'd90:glyph=40'h4345495161;
8'd48:glyph=40'h3e4549513e;
8'd49:glyph=40'h00407f4200;
8'd50:glyph=40'h4649516142;
8'd51:glyph=40'h3649494941;
8'd52:glyph=40'h107f121418;
8'd53:glyph=40'h314949494f;
8'd54:glyph=40'h304949493e;
8'd55:glyph=40'h0305097101;
8'd56:glyph=40'h3649494936;
8'd57:glyph=40'h3e49494906;
8'd45:glyph=40'h0808080808;
8'd43:glyph=40'h08083e0808;
8'd58:glyph=40'h0000360000;
default:glyph=0;endcase end endfunction
function [7:0] character; input [2:0] row; input [4:0] x; reg[167:0] line; reg[4:0] offset; begin
case(row)
0:line="LIGHT HARP 8V        ";
1:line="MODE VOLUME          ";
2:line="VOL 00  SOUND ON     ";
3:line="WAVE TRI PITCH +00   ";
4:line="A0 D0 S0 R0          ";
5:line="HAND ---CM NO ECHO   ";
6:line="TONE 000 ACTIVE 00   ";
7:line="IR 00000000          ";
default:line=0;endcase
if(row==1)case(snap[2:0])
0:line="MODE VOLUME          ";
1:line="MODE PITCH           ";
2:line="MODE WAVE            ";
3:line="MODE ATTACK          ";
4:line="MODE DECAY           ";
5:line="MODE SUSTAIN         ";
6:line="MODE RELEASE         ";
default:line="MODE UNKNOWN         ";endcase
character=(x<21)?(line >> ((20-x)*8)):8'd32;offset=(snap[12:8]<12)?12-snap[12:8]:snap[12:8]-12;
case(row)
2:begin if(x==4)character=48+snap[7:3]/10; if(x==5)character=48+snap[7:3]%10; if(snap[14])begin if(x==15)character="F";if(x==16)character="F";end end
3:begin if(snap[13])case(x)5:character="S";6:character="I";7:character="N";endcase if(x==15)character=(snap[12:8]<12)?"-":"+";if(x==16)character=48+offset/10;if(x==17)character=48+offset%10;end
4:case(x)1:character=48+snap[17:15];4:character=48+snap[20:18];7:character=48+snap[23:21];10:character=48+snap[26:24];endcase
5:if(snap[57])begin case(x)5:character=48+snap[48:41]/100;6:character=48+(snap[48:41]/10)%10;7:character=48+snap[48:41]%10;11:character="O";12:character="K";13,14,15,16,17:character=" ";endcase end
6:case(x)5:character=48+snap[56:49]/100;6:character=48+(snap[56:49]/10)%10;7:character=48+snap[56:49]%10;16:character=48+snap[32:27]/10;17:character=48+snap[32:27]%10;endcase
7:if(x>=3 && x<11)character=snap[33+x-3]?"1":"0";
endcase end endfunction

always @(posedge clk)begin
 ch_q<=character(page,charidx);
 glyph_q<=glyph(ch_q);
 pixel_q<=(col>=126 || subcol==5)?8'd0:(glyph_q>>(subcol*8));
 launch<=0;
 case(state)
 0:if(timer==POWER_CYCLES-1)begin timer<=0;res<=0;state<=1;end else timer<=timer+1;
 1:if(timer==RESET_CYCLES-1)begin timer<=0;res<=1;state<=2;end else timer<=timer+1;
 2:if(timer==RESET_CYCLES-1)begin timer<=0;state<=3;end else timer<=timer+1;
 3:begin tx<=initbyte(initidx);txdc<=0;launch<=1;after_byte<=4;state<=15;end
 4:if(initidx==21)state<=5;else begin initidx<=initidx+1'b1;state<=3;end
 5:begin snap<=status;page<=0;col<=0;charidx<=0;subcol<=0;addridx<=0;state<=6;end
 6:begin
  case(addridx)0:tx<=8'hB0+page;1:tx<=8'h02;2:tx<=8'h10;endcase
  txdc<=0;launch<=1;after_byte<=7;state<=15;
 end
 7:if(addridx==2)begin prep<=0;state<=8;end else begin addridx<=addridx+1'b1;state<=6;end
 8:if(prep==3)begin tx<=pixel_q;txdc<=1;launch<=1;after_byte<=9;state<=15;end else prep<=prep+1'b1;
 9:begin
  prep<=0;
  if(col==127)begin
   col<=0;charidx<=0;subcol<=0;addridx<=0;
   if(page==7)begin if(!displayed)state<=10;else begin timer<=0;state<=11;end end
   else begin page<=page+1'b1;state<=6;end
  end else begin col<=col+1'b1;if(subcol==5)begin subcol<=0;charidx<=charidx+1'b1;end else subcol<=subcol+1'b1;state<=8;end
 end
 10:begin tx<=8'hAF;txdc<=0;launch<=1;after_byte<=11;state<=15;displayed<=1;timer<=0;end
 11:if(timer==FRAME_CYCLES-1)begin timer<=0;state<=5;end else timer<=timer+1;
 15:if(busy)state<=16;
 16:if(!busy)state<=after_byte;
 default:state<=0;
 endcase
end
endmodule
