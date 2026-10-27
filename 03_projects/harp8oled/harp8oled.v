module harp8oled(input wire clk,input wire[7:0] sensor_n,
 input wire enc_s1,enc_s2,enc_key_n,test_key_n,echo,
 output wire trig,DAC_BCK,DAC_LRCK,DAC_DATA,
 output wire OLED_CS,OLED_CLK,OLED_DIN,OLED_DC,OLED_RES);
wire[63:0] ui_status;
harp_core #(.N(8),.TEST_MODE(0),.ECHO_ENABLE(0),.EXPR_ENABLE(1)) core(
 .clk(clk),.sensor_n(sensor_n),.enc_s1(enc_s1),.enc_s2(enc_s2),.enc_key_n(enc_key_n),
 .test_key_n(test_key_n),.echo(echo),.trig(trig),.DAC_BCK(DAC_BCK),.DAC_LRCK(DAC_LRCK),.DAC_DATA(DAC_DATA),
 .led(),.active_count(),.drop_count(),.ui_status(ui_status));
oled_sh1106 display(.clk(clk),.status(ui_status),.cs(OLED_CS),.sck(OLED_CLK),.mosi(OLED_DIN),.dc(OLED_DC),.res(OLED_RES));
endmodule
