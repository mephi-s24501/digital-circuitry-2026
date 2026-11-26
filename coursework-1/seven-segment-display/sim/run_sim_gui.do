# GUI version: opens Questa, runs the simulation, leaves it open.
#   cd /home/dmitry/Projects/CircuitDesign/Lab1SevenSeg
#   vsim -gui -do "do sim/run_sim_gui.do"

onerror { quit -f }

if {![file isdirectory work]} { vlib work }
vmap work work

vcom src/dut_seven_seg.vhdl
vcom src/dut_segment_memory.vhdl
vcom src/dut_display_mux.vhdl
vcom src/dut_bin_to_bcd.vhdl
vcom src/dut_lab1.vhdl
vcom src/low_tester.vhd
vcom src/tb_lab1.vhdl

vsim work.tb_lab1

add wave -r /tb_lab1/*

add wave -radix unsigned /tb_lab1/uut/u_mux/digit_sel_count
add wave /tb_lab1/uut/u_mem/update_sync2_r
add wave /tb_lab1/uut/u_mem/wait_count_r
add wave /tb_lab1/uut/u_mem/segs_reg_r
add wave -radix hex /tb_lab1/uut/u_mem/segs_reg_r

run -all
