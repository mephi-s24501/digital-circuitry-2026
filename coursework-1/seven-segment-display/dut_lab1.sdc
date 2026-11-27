# ---------------------------------------------------------------
# TimeQuest constraints for dut_lab1
# ---------------------------------------------------------------

# 50 MHz oscillator on the board -> 20 ns period
create_clock -name clk_i -period 20.000 [get_ports {clk_i}]

derive_clock_uncertainty

# data_i comes from board switches/keys, settled long before the edge
set_input_delay -clock clk_i -max 5.000 [get_ports {data_i[*]}]
set_input_delay -clock clk_i -min 0.000 [get_ports {data_i[*]}]

# seg_o / digit_o go straight to the display driver transistors
set_output_delay -clock clk_i -max 5.000 [get_ports {seg_o[*]}]
set_output_delay -clock clk_i -max 5.000 [get_ports {digit_o[*]}]

# update_li is an asynchronous button, synchronized by two flip-flops
# inside dut_segment_memory. Its path is not analyzed.
set_false_path -from [get_ports {update_li}]

# nRst_li is an asynchronous active-low reset
set_false_path -from [get_ports {nRst_li}]

# ---------------------------------------------------------------
# Multi-cycle for data_i
# ---------------------------------------------------------------
# set_input_delay above declares data_i as a synchronous input with
# 5 ns of arrival time, i.e. the external source runs at 50 MHz.
# That is not true: data_i is wired by hand to 3V3/GND on J13 and
# changes only when a wire is moved, many microseconds apart.
#
# The single-cycle analysis is therefore pessimistic by construction:
# it asks a hand-wired static bus to meet a 50 MHz setup time.
# The measured path data_i[14] -> segs_reg_r[*] is 18.177 ns plus
# 3.069 ns of skew, against a 20 ns period, which gives -0.143 ns
# setup slack and a negative total negative slack of -1.048 ns.
#
# The real path is: press update_li, the synchronizer fires,
# wait_sz_c counts 4 clock cycles, then the segment memory latches.
# That is 6 clock periods = 120 ns from the pin to the register,
# so a 2-cycle setup budget is honest, not a cover-up.
#
# Rule: -setup N means the capture edge may be N periods after the
# launch edge; the matching hold check must stay on the launch edge,
# hence -hold N-1.
set_multicycle_path -setup 2 -from [get_ports {data_i[*]}]
set_multicycle_path -hold  1 -from [get_ports {data_i[*]}]
