set project_dir [file dirname [file normalize [info script]]]
cd $project_dir
open_project [file join $project_dir harp8oled.gprj]
set_option -top_module harp8oled
set_option -use_cpu_as_gpio 1
run all

