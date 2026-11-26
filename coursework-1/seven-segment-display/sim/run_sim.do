# Run from Lab1SevenSeg:  vsim -c -do "do sim/run_sim.do"
# Or from the project folder:  quartus_sh --flow compile dut_lab1

onerror { quit -f }

vlib work
vmap work work

vcom -93 -work work src/dut_seven_seg.vhdl
vcom -93 -work work src/dut_segment_memory.vhdl
vcom -93 -work work src/dut_display_mux.vhdl
vcom -93 -work work src/dut_bin_to_bcd.vhdl
vcom -93 -work work src/dut_lab1.vhdl
vcom -93 -work work src/low_tester.vhd
vcom -93 -work work src/tb_lab1.vhdl

vsim -c work.tb_lab1 -do "run -all; quit -f"
