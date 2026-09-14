# setup_project.tcl — create Vivado project for cnn_3ch_64x64
# Usage: vivado -mode batch -source setup_project.tcl

set script_dir [file normalize [file dirname [info script]]]
set proj_name  "cnn_3ch_64x64"
set proj_dir   [file join $script_dir "vivado_proj"]
set rtl_dir    [file join $script_dir "rtl"]
set tb_dir     [file join $script_dir "tb"]

set part "xc7a35tcpg236-1"

create_project $proj_name $proj_dir -part $part -force
set_property target_language    Verilog        [current_project]
set_property simulator_language Mixed          [current_project]
set_property default_lib        xil_defaultlib [current_project]

set rtl_files [list \
    [file join $rtl_dir "sram.v"]             \
    [file join $rtl_dir "mac_unit.v"]         \
    [file join $rtl_dir "filter_bank.v"]      \
    [file join $rtl_dir "line_buffer.v"]      \
    [file join $rtl_dir "CNN_controller.v"]   \
    [file join $rtl_dir "apb_slave.v"]        \
    [file join $rtl_dir "CNN_top.v"]          \
]
add_files -norecurse $rtl_files
set_property file_type {Verilog} [get_files $rtl_files]
set_property top CNN_top [current_fileset]
update_compile_order -fileset sources_1

set tb_file [file join $tb_dir "tb_CNN.sv"]
add_files -fileset sim_1 -norecurse $tb_file
set_property file_type {SystemVerilog} [get_files $tb_file]
set_property top     tb_CNN       [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property -name {xsim.simulate.runtime}         -value {0}               -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {true}            -objects [get_filesets sim_1]
set_property -name {xsim.elaborate.xelab.more_options} -value {--debug typical} -objects [get_filesets sim_1]

update_compile_order -fileset sim_1

puts "Project created: [file join $proj_dir ${proj_name}.xpr]"
puts "Open GUI : vivado [file join $proj_dir ${proj_name}.xpr]"
puts "Run sim  : launch_simulation; run all"
