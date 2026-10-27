`timescale 1ns/1ps
module tb_oled;
reg clk=0;always #10 clk=~clk;
reg [63:0] status=0;
wire cs,sck,mosi,dc,res;
oled_sh1106 #(.POWER_CYCLES(20),.RESET_CYCLES(10),.FRAME_CYCLES(100),.SPI_DIV(2)) dut(clk,status,cs,sck,mosi,dc,res);
integer bits=0,n=0,pages=0,cols=0,frames=0,initidx=0,cmdidx=0;reg[7:0] rx=0;reg armed=0,on=0;
reg[7:0] init[0:22];
reg[167:0] lines[0:15];reg[39:0] expected_glyph;reg[7:0] expected_byte;integer framefile;
initial begin
status[7:3]=8;status[12:8]=12;status[20:18]=2;status[23:21]=3;status[26:24]=3;
status[32:27]=2;status[40:33]=8'h55;status[48:41]=17;status[56:49]=121;status[57]=1;
lines[0]="LIGHT HARP 8V        ";lines[1]="MODE VOLUME          ";
lines[2]="VOL 08  SOUND ON     ";lines[3]="WAVE TRI PITCH +00   ";
lines[4]="A0 D2 S3 R3          ";lines[5]="HAND 017CM OK        ";
lines[6]="TONE 121 ACTIVE 02   ";lines[7]="IR 10101010          ";
lines[8]=lines[0];lines[9]="MODE RELEASE         ";
lines[10]="VOL 31  SOUND OFF    ";lines[11]="WAVE SIN PITCH -12   ";
lines[12]=lines[4];lines[13]="HAND ---CM NO ECHO   ";
lines[14]=lines[6];lines[15]=lines[7];
framefile=$fopen("oled_frames.hex","w");
init[0]='hAE;init[1]='hD5;init[2]='h80;init[3]='hA8;init[4]='h3F;init[5]='hD3;init[6]=0;init[7]='h40;init[8]='hAD;init[9]='h8B;init[10]='hA1;init[11]='hC8;init[12]='hDA;init[13]='h12;init[14]='h81;init[15]='h40;init[16]='hD9;init[17]='h22;init[18]='hDB;init[19]='h35;init[20]='hA4;init[21]='hA6;init[22]=0;
end
always @(negedge cs)begin bits=0;rx=0;if(!res)$fatal(1,"SPI during reset");end
always @(posedge sck)if(!cs)begin
 rx={rx[6:0],mosi};bits=bits+1;
 if(bits==8)begin
 n=n+1;
 if(initidx<22)begin if(dc!==0||rx!==init[initidx])$fatal(1,"init mismatch %0d %h",initidx,rx);initidx=initidx+1;end
 else if(!dc)begin
 if(rx=='hAF)begin if(frames<1)$fatal(1,"display on before RAM filled");on=1;end
 else begin
 case(cmdidx)
 0:if(rx!==('hB0+pages))$fatal(1,"page cmd %h %0d",rx,pages);
 1:if(rx!=='h02)$fatal(1,"offset low");
 2:if(rx!=='h10)$fatal(1,"offset high");
 endcase
 cmdidx=cmdidx+1;
 end
 end else begin
 if(cmdidx!=3)$fatal(1,"data before address");
 if((^rx)===1'bx)$fatal(1,"unknown pixel");
 expected_glyph=dut.glyph(lines[frames*8+pages]>>((20-cols/6)*8));
 expected_byte=(cols>=126 || cols%6==5)?0:(expected_glyph>>((cols%6)*8));
 if(rx!==expected_byte)$fatal(1,"render mismatch frame %0d page %0d col %0d got %h expected %h",frames,pages,cols,rx,expected_byte);
 $fdisplay(framefile,"%02x",rx);
 if(frames==0 && pages==1 && cols==0)begin
 status[2:0]=6;status[7:3]=31;status[12:8]=0;status[13]=1;status[14]=1;status[57]=0;
 end
 if(pages==0 && cols==0 && rx!=='h7F)$fatal(1,"L glyph first column %h",rx);
 if(cols>=126 && rx!==0)$fatal(1,"right margin dirty");
 cols=cols+1;
 if(cols==128)begin cols=0;pages=pages+1;cmdidx=0;end
 if(pages==8)begin pages=0;frames=frames+1;end
 end
 end
end
always @(posedge cs)if(n>0 && bits!=8)$fatal(1,"wrong byte clocks");
initial begin
 wait(frames==2);if(!on)$fatal(1,"never display on");
 $fclose(framefile);
 $display("PASS oled: reset init SPI framing page offset 1024 bytes repeated glyph margins");$finish;
end
initial begin #5000000;$fatal(1,"timeout");end
endmodule
