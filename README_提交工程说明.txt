光影弦琴：提交工程说明（2026-10-27）

当前提交版本：八声部＋八路红外输入＋EC11＋超声波表情控制＋OLED。
设备：Tang Mega 60K NEO，GW5AT-60B，50 MHz 时钟。
项目入口：03_projects/harp8oled/harp8oled.gprj
编译入口：03_projects/harp8oled/build.tcl
固件：06_bitstreams/harp8oled.fs，User Code 0x0000B9E8。
请保留整个目录结构；Gowin 工程使用相对路径引用源码与约束。
建议解压到纯英文路径，例如 D:/LightHarp8_OLED，再用 Gowin V1.9.12.03 编译。
通过 gw_sh.exe 执行上述 build.tcl；脚本包含 use_cpu_as_gpio，避免 CPU 复用引脚布局错误。
仿真入口：04_sim/run_oled.ps1；可通过 -VivadoBin 指定自己的 Vivado bin 路径。

当前顶层参数为 N=8、TEST_MODE=0、ECHO_ENABLE=0、EXPR_ENABLE=1。
使用独立相位振荡器与 ADSR 包络，支持正弦/三角波；不是 Karplus-Strong 物理建模版本。
部分 RTL 文件含扩展能力，但当前配置未启用回声，不能把源文件存在视为效果已完成验收。
源码、约束、工程、仿真、已有构建报告和固件完整保留；本次打包没有改动 RTL、没有重新编译或烧录。

状态说明：目录内 00_先读我_接线与测试.txt 是 2026-10-26 初版说明，其中“OLED 尚未完成实物点亮”已过时。
之后用户已反馈 OLED 点亮、八路独立红外、旋钮参数、超声波音色变化正常。
本次材料整理没有重复硬件测试。采样率实测、多频频谱及吞吐量评分验证仍待补。
不要把八路输入数量直接等同于已完成评分验证；设计采样率推导值不等于仪器实测值。
本包仅包含当前演奏版本，不混入历史 16/32 声部实验或电脑音频演示程序。
保留的构建和测试日志可能包含开发机本地路径；它们仅用于工程追溯。
