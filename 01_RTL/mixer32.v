`timescale 1ns/1ps
// Five registered balanced signed stages. Zero-pad unused voice slots.
module mixer32(input clk,input [511:0] audio,output signed [20:0] sum);
reg signed [16:0] s1[0:15];reg signed [17:0] s2[0:7];
reg signed [18:0] s3[0:3];reg signed [19:0] s4[0:1];reg signed [20:0] s5=0;
integer i;
initial begin
 for(i=0;i<16;i=i+1)s1[i]=0;for(i=0;i<8;i=i+1)s2[i]=0;
 for(i=0;i<4;i=i+1)s3[i]=0;for(i=0;i<2;i=i+1)s4[i]=0;
end
always @(posedge clk) begin
 for(i=0;i<16;i=i+1)s1[i]<=$signed({audio[i*32+15],audio[i*32+:16]})+$signed({audio[i*32+31],audio[i*32+16+:16]});
 for(i=0;i<8;i=i+1)s2[i]<=$signed({s1[2*i][16],s1[2*i]})+$signed({s1[2*i+1][16],s1[2*i+1]});
 for(i=0;i<4;i=i+1)s3[i]<=$signed({s2[2*i][17],s2[2*i]})+$signed({s2[2*i+1][17],s2[2*i+1]});
 for(i=0;i<2;i=i+1)s4[i]<=$signed({s3[2*i][18],s3[2*i]})+$signed({s3[2*i+1][18],s3[2*i+1]});
 s5<=$signed({s4[0][19],s4[0]})+$signed({s4[1][19],s4[1]});
end
assign sum=s5;
endmodule
